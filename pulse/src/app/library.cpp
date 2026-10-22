#include "library.hpp"
#include "mediainfo.hpp"
#include "mediainput.hpp"

#include <QCollator>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPointer>
#include <QSaveFile>
#include <QStandardPaths>
#include <QThread>
#include <QSet>
#include <algorithm>
#include <numeric>

namespace pulse {

namespace {

constexpr int kStoreVersion = 1;
constexpr int kMaxProbes = 3;
constexpr qint64 kFeatureLengthMs = 40 * 60 * 1000;

bool pathHas(const QString &path, std::initializer_list<const char *> words)
{
    const QString lower = QDir::fromNativeSeparators(path).toLower();
    for (const char *w : words)
        if (lower.contains(QLatin1String(w)))
            return true;
    return false;
}

QString clock(qint64 ms)
{
    const qint64 s = ms / 1000;
    return QStringLiteral("%1:%2").arg(s / 60).arg(s % 60, 2, 10, QLatin1Char('0'));
}

} // namespace

Library::Library(const QString &storePath, QObject *parent)
    : QAbstractListModel(parent)
    , m_store(storePath)
{
    if (m_store.isEmpty()) {
        const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
        QDir().mkpath(dir);
        m_store = dir + QStringLiteral("/library.json");
    }
    m_saveTimer.setSingleShot(true);
    m_saveTimer.setInterval(800);
    connect(&m_saveTimer, &QTimer::timeout, this, [this] { save(); });
    load();
    rebuildView();
}

Library::~Library()
{
    if (m_saveTimer.isActive())
        save();
}

// ----------------------------------------------------------------- model

int Library::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : int(m_view.size());
}

QVariant Library::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_view.size())
        return {};
    const Item &it = m_items[m_view[index.row()]];
    switch (role) {
    case UrlRole: return QUrl::fromLocalFile(it.path);
    case Qt::DisplayRole:
    case TitleRole: return it.title;
    case SubtitleRole: return subtitleFor(it);
    case CategoryRole: return it.category;
    case FolderRole: return it.folder;
    case DurationRole: return it.durationMs;
    case QualityRole: return qualityLabel(it.width, it.height);
    case IsAudioRole: return it.category == QLatin1String("music");
    case YearRole: return it.year;
    case AddedRole: return it.added;
    case AvailableRole: return it.available;
    case DetailRole: return MediaInput::describe(QUrl::fromLocalFile(it.path));
    }
    return {};
}

QHash<int, QByteArray> Library::roleNames() const
{
    return {
        { UrlRole, "url" }, { TitleRole, "title" }, { SubtitleRole, "subtitle" }, { CategoryRole, "category" },
        { FolderRole, "folder" }, { DurationRole, "durationMs" }, { QualityRole, "quality" }, { IsAudioRole, "isAudio" },
        { YearRole, "year" }, { AddedRole, "added" }, { AvailableRole, "available" }, { DetailRole, "detail" },
    };
}

QVariantList Library::folders() const
{
    QVariantList out;
    for (const QString &f : m_folders) {
        int n = 0;
        for (const Item &it : m_items)
            if (it.folder == f)
                ++n;
        out << QVariantMap{
            { QStringLiteral("path"), f },
            { QStringLiteral("name"), QFileInfo(f).fileName().isEmpty() ? f : QFileInfo(f).fileName() },
            { QStringLiteral("display"), QDir::toNativeSeparators(f) },
            { QStringLiteral("count"), n },
            { QStringLiteral("online"), QFileInfo(f).isDir() },
        };
    }
    return out;
}

QVariantMap Library::counts() const
{
    QVariantMap out{ { QStringLiteral("all"), int(m_items.size()) }, { QStringLiteral("movies"), 0 },
                     { QStringLiteral("tv"), 0 }, { QStringLiteral("music"), 0 }, { QStringLiteral("other"), 0 } };
    for (const Item &it : m_items)
        out[it.category] = out.value(it.category).toInt() + 1;
    return out;
}

void Library::setCategory(const QString &category)
{
    if (m_category == category)
        return;
    m_category = category;
    rebuildView();
}

void Library::setSearch(const QString &search)
{
    if (m_search == search)
        return;
    m_search = search;
    rebuildView();
}

void Library::setSort(const QString &sort)
{
    if (m_sort == sort)
        return;
    m_sort = sort;
    rebuildView();
}

void Library::rebuildView()
{
    beginResetModel();
    m_view.clear();
    const QString needle = m_search.trimmed();
    for (int i = 0; i < m_items.size(); ++i) {
        const Item &it = m_items[i];
        if (m_category != QLatin1String("all") && it.category != m_category)
            continue;
        if (!needle.isEmpty() && !it.title.contains(needle, Qt::CaseInsensitive)
            && !it.artist.contains(needle, Qt::CaseInsensitive) && !it.album.contains(needle, Qt::CaseInsensitive)
            && !QFileInfo(it.path).fileName().contains(needle, Qt::CaseInsensitive))
            continue;
        m_view << i;
    }
    QCollator collator;
    collator.setNumericMode(true);
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    std::stable_sort(m_view.begin(), m_view.end(), [&](int a, int b) {
        const Item &x = m_items[a], &y = m_items[b];
        if (m_sort == QLatin1String("title"))
            return collator.compare(x.title, y.title) < 0;
        if (m_sort == QLatin1String("year"))
            return x.year > y.year;
        return x.added > y.added;
    });
    endResetModel();
    emit viewChanged();
}

void Library::touch()
{
    ++m_revision;
    rebuildView();
    emit contentChanged();
    emit foldersChanged();
    scheduleSave();
}

// ----------------------------------------------------------------- derived facts

QString Library::classify(const QString &path, bool audio, qint64 durationMs, int season, const QString &showName)
{
    if (audio)
        return QStringLiteral("music");
    if (season > 0 || !showName.isEmpty() || pathHas(path, { "/tv/", "tv shows", "/series/", "/shows/" }))
        return QStringLiteral("tv");
    if (pathHas(path, { "movie", "film" }) || durationMs >= kFeatureLengthMs)
        return QStringLiteral("movies");
    return QStringLiteral("other");
}

void Library::derive(Item &it) const
{
    const ParsedName name = parseFileName(it.path);
    const bool audio = MediaInput::isAudio(QUrl::fromLocalFile(it.path));
    it.year = name.year;
    if (it.season == 0 && name.season > 0) {
        it.season = name.season;
        it.episode = name.episode;
    }
    // Tags win for music; file names win for video (rips often carry junk titles).
    it.title = audio && !it.metaTitle.isEmpty() ? it.metaTitle : !it.showName.isEmpty() ? it.showName : name.title;
    it.category = classify(it.path, audio, it.durationMs, it.season, it.showName);
}

QString Library::subtitleFor(const Item &it) const
{
    QStringList parts;
    if (it.category == QLatin1String("music")) {
        if (!it.artist.isEmpty())
            parts << it.artist;
        if (it.durationMs > 0)
            parts << clock(it.durationMs);
    } else if (it.category == QLatin1String("tv")) {
        if (it.season > 0)
            parts << QStringLiteral("S%1E%2").arg(it.season).arg(it.episode);
        if (it.durationMs > 0)
            parts << shortDuration(it.durationMs);
    } else {
        if (it.year > 0)
            parts << QString::number(it.year);
        if (it.durationMs > 0)
            parts << shortDuration(it.durationMs);
    }
    if (parts.isEmpty())
        parts << QFileInfo(it.path).suffix().toUpper();
    return parts.join(QStringLiteral(" · "));
}

QVariantMap Library::toMap(const Item &it) const
{
    return {
        { QStringLiteral("url"), QUrl::fromLocalFile(it.path) },
        { QStringLiteral("title"), it.title },
        { QStringLiteral("subtitle"), subtitleFor(it) },
        { QStringLiteral("category"), it.category },
        { QStringLiteral("durationMs"), it.durationMs },
        { QStringLiteral("quality"), qualityLabel(it.width, it.height) },
        { QStringLiteral("isAudio"), it.category == QLatin1String("music") },
        { QStringLiteral("year"), it.year },
        { QStringLiteral("width"), it.width },
        { QStringLiteral("height"), it.height },
        { QStringLiteral("videoCodec"), it.videoCodec },
        { QStringLiteral("audioCodec"), it.audioCodec },
        { QStringLiteral("size"), it.size },
        { QStringLiteral("available"), it.available },
    };
}

QVariantList Library::recentlyAdded(int limit) const
{
    QVector<int> rows(m_items.size());
    std::iota(rows.begin(), rows.end(), 0);
    std::stable_sort(rows.begin(), rows.end(), [&](int a, int b) { return m_items[a].added > m_items[b].added; });
    QVariantList out;
    for (int r : rows) {
        if (out.size() >= limit)
            break;
        if (m_items[r].available)
            out << toMap(m_items[r]);
    }
    return out;
}

QVariantMap Library::item(const QUrl &url) const
{
    if (!url.isLocalFile())
        return {};
    const auto it = m_index.constFind(url.toLocalFile());
    return it == m_index.constEnd() ? QVariantMap() : toMap(m_items[*it]);
}

QList<QUrl> Library::viewUrls() const
{
    QList<QUrl> out;
    for (int r : m_view)
        if (m_items[r].available)
            out << QUrl::fromLocalFile(m_items[r].path);
    return out;
}

QVariantList Library::suggestedFolders() const
{
    QVariantList out;
    for (auto loc : { QStandardPaths::MoviesLocation, QStandardPaths::MusicLocation }) {
        const QString dir = QStandardPaths::writableLocation(loc);
        if (dir.isEmpty() || !QFileInfo(dir).isDir() || m_folders.contains(dir) || dir == QDir::homePath())
            continue;
        out << QVariantMap{ { QStringLiteral("url"), QUrl::fromLocalFile(dir) },
                            { QStringLiteral("name"), QFileInfo(dir).fileName() },
                            { QStringLiteral("display"), QDir::toNativeSeparators(dir) } };
    }
    return out;
}

// ----------------------------------------------------------------- folders and scanning

void Library::addFolder(const QUrl &folder)
{
    if (!folder.isLocalFile())
        return;
    const QString path = QDir::cleanPath(folder.toLocalFile());
    if (!QFileInfo(path).isDir() || m_folders.contains(path))
        return;
    // A folder inside one already indexed adds nothing new.
    for (const QString &f : std::as_const(m_folders))
        if (path.startsWith(f + QLatin1Char('/')))
            return;
    m_folders << path;
    emit foldersChanged();
    scheduleSave();
    scanFolders({ path });
}

void Library::removeFolder(const QString &path)
{
    if (!m_folders.removeOne(path))
        return;
    QVector<Item> kept;
    for (Item &it : m_items)
        if (it.folder != path)
            kept << std::move(it);
    m_items = std::move(kept);
    m_index.clear();
    for (int i = 0; i < m_items.size(); ++i)
        m_index.insert(m_items[i].path, i);
    touch();
}

void Library::rescan()
{
    scanFolders(m_folders);
}

void Library::scanFolders(const QStringList &folders)
{
    if (folders.isEmpty())
        return;
    ++m_scansRunning;
    if (!m_scanning) {
        m_scanning = true;
        emit scanningChanged();
    }
    auto *results = new QVector<Found>;
    QThread *thread = QThread::create([folders, results] {
        for (const QString &folder : folders) {
            QDirIterator it(folder, QDir::Files | QDir::Readable, QDirIterator::Subdirectories | QDirIterator::FollowSymlinks);
            while (it.hasNext()) {
                it.next();
                const QFileInfo fi = it.fileInfo();
                if (MediaInput::isMedia(QUrl::fromLocalFile(fi.filePath())) && !fi.fileName().startsWith(QLatin1Char('.')))
                    results->push_back({ fi.filePath(), fi.size(), fi.lastModified().toSecsSinceEpoch() });
            }
        }
    });
    QPointer<Library> self(this);
    connect(thread, &QThread::finished, this, [self, thread, folders, results] {
        if (self)
            self->mergeScan(folders, *results);
        delete results;
        thread->deleteLater();
    });
    thread->start(QThread::LowPriority);
}

void Library::mergeScan(const QStringList &folders, const QVector<Found> &found)
{
    QSet<QString> seen;
    for (const Found &f : found) {
        seen.insert(f.path);
        QString folder;
        for (const QString &root : std::as_const(m_folders))
            if (f.path.startsWith(root + QLatin1Char('/')))
                folder = root;
        if (folder.isEmpty())
            continue; // folder removed while scanning
        auto existing = m_index.find(f.path);
        if (existing == m_index.end()) {
            Item it;
            it.path = f.path;
            it.folder = folder;
            it.size = f.size;
            it.mtime = f.mtime;
            it.added = QDateTime::fromSecsSinceEpoch(f.mtime);
            derive(it);
            m_index.insert(it.path, int(m_items.size()));
            m_items << it;
            m_probeQueue << it.path;
        } else {
            Item &it = m_items[*existing];
            it.available = true;
            if (it.size != f.size || it.mtime != f.mtime) {
                it.size = f.size;
                it.mtime = f.mtime;
                it.probed = false;
                m_probeQueue << it.path;
            }
        }
    }
    // Files gone from a reachable folder leave the index; an unreachable
    // folder (unplugged drive) keeps its items, marked unavailable.
    QVector<Item> kept;
    for (Item &it : m_items) {
        bool scanned = false;
        for (const QString &root : folders)
            if (it.folder == root)
                scanned = true;
        if (scanned && !seen.contains(it.path)) {
            if (QFileInfo(it.folder).isDir())
                continue;
            it.available = false;
        }
        kept << std::move(it);
    }
    m_items = std::move(kept);
    m_index.clear();
    for (int i = 0; i < m_items.size(); ++i) {
        m_index.insert(m_items[i].path, i);
        if (!m_items[i].probed && m_items[i].available && !m_probeQueue.contains(m_items[i].path))
            m_probeQueue << m_items[i].path;
    }

    if (--m_scansRunning == 0) {
        m_scanning = false;
        emit scanningChanged();
    }
    touch();
    pumpProbes();
}

void Library::pumpProbes()
{
    while (m_probesInFlight < kMaxProbes && !m_probeQueue.isEmpty()) {
        ++m_probesInFlight;
        emit probeRequested(QUrl::fromLocalFile(m_probeQueue.takeFirst()));
    }
}

void Library::applyProbe(const QUrl &url, const QVariantMap &info)
{
    const auto found = url.isLocalFile() ? m_index.constFind(url.toLocalFile()) : m_index.constEnd();
    if (found == m_index.constEnd())
        return; // someone else's probe
    m_probesInFlight = std::max(0, m_probesInFlight - 1);
    Item &it = m_items[*found];
    it.probed = true;
    if (!info.isEmpty()) {
        it.durationMs = info.value(QStringLiteral("durationMs")).toLongLong();
        it.width = info.value(QStringLiteral("width")).toInt();
        it.height = info.value(QStringLiteral("height")).toInt();
        it.videoCodec = info.value(QStringLiteral("videoCodec")).toString();
        it.audioCodec = info.value(QStringLiteral("audioCodec")).toString();
        it.artist = info.value(QStringLiteral("artist")).toString();
        it.album = info.value(QStringLiteral("album")).toString();
        it.showName = info.value(QStringLiteral("showName")).toString();
        const QString title = info.value(QStringLiteral("title")).toString();
        // The core reports the file name as the title when there is no tag.
        it.metaTitle = title == QFileInfo(it.path).fileName() ? QString() : title;
        if (info.value(QStringLiteral("season")).toInt() > 0) {
            it.season = info.value(QStringLiteral("season")).toInt();
            it.episode = info.value(QStringLiteral("episode")).toInt();
        }
    }
    derive(it);
    // Probes arrive in bursts; refresh the view once the burst settles.
    if (m_probesInFlight == 0 || m_probeQueue.isEmpty())
        touch();
    else
        scheduleSave();
    pumpProbes();
}

// ----------------------------------------------------------------- persistence

void Library::load()
{
    QFile f(m_store);
    if (!f.open(QIODevice::ReadOnly))
        return;
    const QJsonObject root = QJsonDocument::fromJson(f.readAll()).object();
    if (root.value(QStringLiteral("version")).toInt() != kStoreVersion)
        return;
    for (const QJsonValue &v : root.value(QStringLiteral("folders")).toArray())
        m_folders << v.toString();
    for (const QJsonValue &v : root.value(QStringLiteral("items")).toArray()) {
        const QJsonObject o = v.toObject();
        Item it;
        it.path = o.value(QStringLiteral("path")).toString();
        it.folder = o.value(QStringLiteral("folder")).toString();
        if (it.path.isEmpty() || !m_folders.contains(it.folder))
            continue;
        it.size = qint64(o.value(QStringLiteral("size")).toDouble());
        it.mtime = qint64(o.value(QStringLiteral("mtime")).toDouble());
        it.added = QDateTime::fromSecsSinceEpoch(qint64(o.value(QStringLiteral("added")).toDouble()));
        it.probed = o.value(QStringLiteral("probed")).toBool();
        it.durationMs = qint64(o.value(QStringLiteral("durationMs")).toDouble());
        it.width = o.value(QStringLiteral("width")).toInt();
        it.height = o.value(QStringLiteral("height")).toInt();
        it.videoCodec = o.value(QStringLiteral("videoCodec")).toString();
        it.audioCodec = o.value(QStringLiteral("audioCodec")).toString();
        it.metaTitle = o.value(QStringLiteral("metaTitle")).toString();
        it.artist = o.value(QStringLiteral("artist")).toString();
        it.album = o.value(QStringLiteral("album")).toString();
        it.showName = o.value(QStringLiteral("showName")).toString();
        it.season = o.value(QStringLiteral("season")).toInt();
        it.episode = o.value(QStringLiteral("episode")).toInt();
        it.available = QFileInfo::exists(it.path);
        derive(it);
        m_index.insert(it.path, int(m_items.size()));
        m_items << it;
    }
}

void Library::scheduleSave()
{
    m_saveTimer.start();
}

void Library::save() const
{
    QJsonArray folders, items;
    for (const QString &f : m_folders)
        folders << f;
    for (const Item &it : m_items) {
        items << QJsonObject{
            { QStringLiteral("path"), it.path }, { QStringLiteral("folder"), it.folder },
            { QStringLiteral("size"), double(it.size) }, { QStringLiteral("mtime"), double(it.mtime) },
            { QStringLiteral("added"), double(it.added.toSecsSinceEpoch()) }, { QStringLiteral("probed"), it.probed },
            { QStringLiteral("durationMs"), double(it.durationMs) }, { QStringLiteral("width"), it.width },
            { QStringLiteral("height"), it.height }, { QStringLiteral("videoCodec"), it.videoCodec },
            { QStringLiteral("audioCodec"), it.audioCodec }, { QStringLiteral("metaTitle"), it.metaTitle },
            { QStringLiteral("artist"), it.artist }, { QStringLiteral("album"), it.album },
            { QStringLiteral("showName"), it.showName }, { QStringLiteral("season"), it.season },
            { QStringLiteral("episode"), it.episode },
        };
    }
    QSaveFile f(m_store);
    if (!f.open(QIODevice::WriteOnly))
        return;
    f.write(QJsonDocument(QJsonObject{ { QStringLiteral("version"), kStoreVersion },
                                       { QStringLiteral("folders"), folders },
                                       { QStringLiteral("items"), items } }).toJson(QJsonDocument::Compact));
    f.commit();
}

} // namespace pulse
