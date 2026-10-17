#include "playlists.hpp"
#include "mediainfo.hpp"
#include "mediainput.hpp"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTextStream>
#include <QUuid>

namespace pulse {

namespace {
constexpr int kStoreVersion = 1;
}

Playlists::Playlists(const QString &storePath, QObject *parent)
    : QAbstractListModel(parent)
    , m_store(storePath)
{
    if (m_store.isEmpty()) {
        const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
        QDir().mkpath(dir);
        m_store = dir + QStringLiteral("/playlists.json");
    }
    m_saveTimer.setSingleShot(true);
    m_saveTimer.setInterval(500);
    connect(&m_saveTimer, &QTimer::timeout, this, [this] { save(); });
    load();
    rebuildView();
}

Playlists::~Playlists()
{
    if (m_saveTimer.isActive())
        save();
}

// ----------------------------------------------------------------- model

int Playlists::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : int(m_view.size());
}

QVariant Playlists::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_view.size())
        return {};
    const List &l = m_lists[m_view[index.row()]];
    switch (role) {
    case IdRole: return l.id;
    case Qt::DisplayRole:
    case NameRole: return l.name;
    case DescriptionRole: return l.description;
    case ItemCountRole: return int(l.entries.size());
    case DurationRole: return durationOf(l);
    case KindRole: return kindOf(l);
    case CoverRole: return coverOf(l);
    case CreatedRole: return l.created;
    case ModifiedRole: return l.modified;
    }
    return {};
}

QHash<int, QByteArray> Playlists::roleNames() const
{
    return {
        { IdRole, "playlistId" }, { NameRole, "name" }, { DescriptionRole, "description" },
        { ItemCountRole, "itemCount" }, { DurationRole, "durationMs" }, { KindRole, "kind" },
        { CoverRole, "cover" }, { CreatedRole, "created" }, { ModifiedRole, "modified" },
    };
}

QVariantMap Playlists::counts() const
{
    QVariantMap out{ { QStringLiteral("all"), int(m_lists.size()) }, { QStringLiteral("movies"), 0 },
                     { QStringLiteral("music"), 0 }, { QStringLiteral("custom"), 0 } };
    for (const List &l : m_lists) {
        const QString k = kindOf(l);
        out[k] = out.value(k).toInt() + 1;
    }
    return out;
}

void Playlists::setFilter(const QString &filter)
{
    if (m_filter == filter)
        return;
    m_filter = filter;
    rebuildView();
}

void Playlists::setSearch(const QString &search)
{
    if (m_search == search)
        return;
    m_search = search;
    rebuildView();
}

void Playlists::rebuildView()
{
    beginResetModel();
    m_view.clear();
    for (int i = 0; i < m_lists.size(); ++i) {
        const List &l = m_lists[i];
        if (m_filter != QLatin1String("all") && kindOf(l) != m_filter)
            continue;
        if (!m_search.trimmed().isEmpty() && !l.name.contains(m_search.trimmed(), Qt::CaseInsensitive))
            continue;
        m_view << i;
    }
    endResetModel();
    emit viewChanged();
}

QVariantList Playlists::all() const
{
    QVariantList out;
    for (const List &l : m_lists)
        out << QVariantMap{ { QStringLiteral("id"), l.id }, { QStringLiteral("name"), l.name },
                            { QStringLiteral("itemCount"), int(l.entries.size()) } };
    return out;
}

QString Playlists::idAt(int row) const
{
    return row >= 0 && row < m_view.size() ? m_lists[m_view[row]].id : QString();
}

int Playlists::rowOf(const QString &id) const
{
    for (int r = 0; r < m_view.size(); ++r)
        if (m_lists[m_view[r]].id == id)
            return r;
    return -1;
}

// ----------------------------------------------------------------- derived

int Playlists::find(const QString &id) const
{
    for (int i = 0; i < m_lists.size(); ++i)
        if (m_lists[i].id == id)
            return i;
    return -1;
}

QString Playlists::kindOf(const List &l) const
{
    if (l.entries.isEmpty())
        return QStringLiteral("custom");
    int audio = 0;
    for (const Entry &e : l.entries)
        if (MediaInput::isAudio(e.url))
            ++audio;
    if (audio == l.entries.size())
        return QStringLiteral("music");
    if (audio == 0)
        return QStringLiteral("movies");
    return QStringLiteral("custom");
}

qint64 Playlists::durationOf(const List &l) const
{
    qint64 total = 0;
    for (const Entry &e : l.entries)
        total += e.durationMs;
    return total;
}

QUrl Playlists::coverOf(const List &l) const
{
    for (const Entry &e : l.entries)
        if (e.url.isLocalFile() && QFileInfo::exists(e.url.toLocalFile()))
            return e.url;
    return {};
}

QVariantMap Playlists::get(const QString &id) const
{
    const int i = find(id);
    if (i < 0)
        return {};
    const List &l = m_lists[i];
    return {
        { QStringLiteral("id"), l.id }, { QStringLiteral("name"), l.name },
        { QStringLiteral("description"), l.description }, { QStringLiteral("itemCount"), int(l.entries.size()) },
        { QStringLiteral("durationMs"), durationOf(l) }, { QStringLiteral("kind"), kindOf(l) },
        { QStringLiteral("cover"), coverOf(l) }, { QStringLiteral("created"), l.created },
        { QStringLiteral("modified"), l.modified },
    };
}

QVariantList Playlists::items(const QString &id) const
{
    QVariantList out;
    const int i = find(id);
    if (i < 0)
        return out;
    for (const Entry &e : m_lists[i].entries) {
        out << QVariantMap{
            { QStringLiteral("url"), e.url }, { QStringLiteral("title"), e.title },
            { QStringLiteral("durationMs"), e.durationMs }, { QStringLiteral("isAudio"), MediaInput::isAudio(e.url) },
            { QStringLiteral("available"), MediaInput::exists(e.url) },
        };
    }
    return out;
}

QList<QUrl> Playlists::urls(const QString &id) const
{
    QList<QUrl> out;
    const int i = find(id);
    if (i >= 0)
        for (const Entry &e : m_lists[i].entries)
            if (MediaInput::exists(e.url))
                out << e.url;
    return out;
}

// ----------------------------------------------------------------- editing

Playlists::Entry Playlists::makeEntry(const QUrl &url, const QString &title, qint64 durationMs)
{
    Entry e;
    e.url = url;
    if (!title.isEmpty())
        e.title = title;
    else if (url.isLocalFile()) {
        const ParsedName n = parseFileName(url.toLocalFile());
        e.title = n.season > 0 ? QStringLiteral("%1 S%2E%3").arg(n.title).arg(n.season).arg(n.episode)
                : n.year > 0   ? QStringLiteral("%1 (%2)").arg(n.title).arg(n.year)
                               : n.title;
    } else {
        e.title = MediaInput::displayName(url);
    }
    e.durationMs = durationMs;
    if (durationMs <= 0 && url.isLocalFile() && !m_probing.contains(url.toString())) {
        m_probing.insert(url.toString());
        emit probeRequested(url);
    }
    return e;
}

void Playlists::changed(List &l)
{
    l.modified = QDateTime::currentDateTime();
    ++m_revision;
    rebuildView();
    emit contentChanged();
    m_saveTimer.start();
}

QString Playlists::create(const QString &name, const QList<QUrl> &urls)
{
    List l;
    l.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    l.name = name.trimmed().isEmpty() ? tr("Untitled Playlist") : name.trimmed();
    l.created = QDateTime::currentDateTime();
    for (const QUrl &u : MediaInput::expand(urls))
        l.entries << makeEntry(u);
    m_lists.prepend(l);
    changed(m_lists.first());
    return l.id;
}

void Playlists::rename(const QString &id, const QString &name)
{
    const int i = find(id);
    if (i < 0 || name.trimmed().isEmpty() || m_lists[i].name == name.trimmed())
        return;
    m_lists[i].name = name.trimmed();
    changed(m_lists[i]);
}

void Playlists::setDescription(const QString &id, const QString &description)
{
    const int i = find(id);
    if (i < 0 || m_lists[i].description == description.trimmed())
        return;
    m_lists[i].description = description.trimmed();
    changed(m_lists[i]);
}

void Playlists::remove(const QString &id)
{
    const int i = find(id);
    if (i < 0)
        return;
    m_lists.removeAt(i);
    ++m_revision;
    rebuildView();
    emit contentChanged();
    m_saveTimer.start();
}

void Playlists::addUrls(const QString &id, const QList<QUrl> &urls)
{
    const int i = find(id);
    if (i < 0)
        return;
    const QList<QUrl> media = MediaInput::expand(urls);
    if (media.isEmpty())
        return;
    for (const QUrl &u : media)
        m_lists[i].entries << makeEntry(u);
    changed(m_lists[i]);
}

void Playlists::removeItem(const QString &id, int index)
{
    const int i = find(id);
    if (i < 0 || index < 0 || index >= m_lists[i].entries.size())
        return;
    m_lists[i].entries.removeAt(index);
    changed(m_lists[i]);
}

void Playlists::moveItem(const QString &id, int from, int to)
{
    const int i = find(id);
    if (i < 0)
        return;
    auto &e = m_lists[i].entries;
    if (from < 0 || from >= e.size() || to < 0 || to >= e.size() || from == to)
        return;
    e.move(from, to);
    changed(m_lists[i]);
}

void Playlists::clear(const QString &id)
{
    const int i = find(id);
    if (i < 0 || m_lists[i].entries.isEmpty())
        return;
    m_lists[i].entries.clear();
    changed(m_lists[i]);
}

void Playlists::refreshDurations()
{
    for (const List &l : std::as_const(m_lists))
        for (const Entry &e : l.entries)
            if (e.durationMs <= 0 && e.url.isLocalFile() && QFileInfo::exists(e.url.toLocalFile())
                && !m_probing.contains(e.url.toString())) {
                m_probing.insert(e.url.toString());
                emit probeRequested(e.url);
            }
}

void Playlists::applyProbe(const QUrl &url, const QVariantMap &info)
{
    if (!m_probing.remove(url.toString()))
        return;
    const qint64 ms = info.value(QStringLiteral("durationMs")).toLongLong();
    const QString title = info.value(QStringLiteral("title")).toString();
    const bool tagged = MediaInput::isAudio(url) && !title.isEmpty() && title != QFileInfo(url.toLocalFile()).fileName();
    bool any = false;
    for (List &l : m_lists)
        for (Entry &e : l.entries)
            if (e.url == url) {
                if (ms > 0)
                    e.durationMs = ms;
                if (tagged)
                    e.title = title;
                any = true;
            }
    if (any) {
        ++m_revision;
        rebuildView();
        emit contentChanged();
        m_saveTimer.start();
    }
}

// ----------------------------------------------------------------- M3U

bool Playlists::exportM3u(const QString &id, const QUrl &file) const
{
    const int i = find(id);
    if (i < 0 || !file.isLocalFile())
        return false;
    QSaveFile f(file.toLocalFile());
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text))
        return false;
    QTextStream out(&f);
    out << "#EXTM3U\n#PLAYLIST:" << m_lists[i].name << '\n';
    for (const Entry &e : m_lists[i].entries) {
        out << "#EXTINF:" << (e.durationMs > 0 ? e.durationMs / 1000 : -1) << ',' << e.title << '\n';
        out << (e.url.isLocalFile() ? QDir::toNativeSeparators(e.url.toLocalFile()) : e.url.toString()) << '\n';
    }
    out.flush();
    return f.commit();
}

QString Playlists::importM3u(const QUrl &file)
{
    if (!file.isLocalFile())
        return {};
    QFile f(file.toLocalFile());
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    const QDir base = QFileInfo(f.fileName()).absoluteDir();
    QString name = QFileInfo(f.fileName()).completeBaseName();
    QString title;
    qint64 duration = 0;
    QVector<Entry> entries;
    QTextStream in(&f);
    while (!in.atEnd()) {
        const QString line = in.readLine().trimmed();
        if (line.isEmpty())
            continue;
        if (line.startsWith(QLatin1String("#PLAYLIST:"))) {
            name = line.mid(10).trimmed();
        } else if (line.startsWith(QLatin1String("#EXTINF:"))) {
            const int comma = int(line.indexOf(QLatin1Char(',')));
            duration = line.mid(8, comma < 0 ? -1 : comma - 8).toLongLong() * 1000;
            title = comma < 0 ? QString() : line.mid(comma + 1).trimmed();
        } else if (!line.startsWith(QLatin1Char('#'))) {
            const QUrl u = line.contains(QLatin1String("://")) ? QUrl(line)
                                                                : QUrl::fromLocalFile(QDir::cleanPath(base.absoluteFilePath(line)));
            entries << makeEntry(u, title, duration > 0 ? duration : 0);
            title.clear();
            duration = 0;
        }
    }
    if (entries.isEmpty())
        return {};
    List l;
    l.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    l.name = name;
    l.created = QDateTime::currentDateTime();
    l.entries = entries;
    m_lists.prepend(l);
    changed(m_lists.first());
    return l.id;
}

// ----------------------------------------------------------------- persistence

void Playlists::load()
{
    QFile f(m_store);
    if (!f.open(QIODevice::ReadOnly))
        return;
    const QJsonObject root = QJsonDocument::fromJson(f.readAll()).object();
    if (root.value(QStringLiteral("version")).toInt() != kStoreVersion)
        return;
    for (const QJsonValue &v : root.value(QStringLiteral("playlists")).toArray()) {
        const QJsonObject o = v.toObject();
        List l;
        l.id = o.value(QStringLiteral("id")).toString();
        l.name = o.value(QStringLiteral("name")).toString();
        l.description = o.value(QStringLiteral("description")).toString();
        l.created = QDateTime::fromString(o.value(QStringLiteral("created")).toString(), Qt::ISODate);
        l.modified = QDateTime::fromString(o.value(QStringLiteral("modified")).toString(), Qt::ISODate);
        for (const QJsonValue &ev : o.value(QStringLiteral("items")).toArray()) {
            const QJsonObject eo = ev.toObject();
            l.entries << Entry{ QUrl(eo.value(QStringLiteral("url")).toString()), eo.value(QStringLiteral("title")).toString(),
                                qint64(eo.value(QStringLiteral("durationMs")).toDouble()) };
        }
        if (!l.id.isEmpty())
            m_lists << l;
    }
}

void Playlists::save() const
{
    QJsonArray lists;
    for (const List &l : m_lists) {
        QJsonArray items;
        for (const Entry &e : l.entries)
            items << QJsonObject{ { QStringLiteral("url"), e.url.toString() }, { QStringLiteral("title"), e.title },
                                  { QStringLiteral("durationMs"), double(e.durationMs) } };
        lists << QJsonObject{
            { QStringLiteral("id"), l.id }, { QStringLiteral("name"), l.name },
            { QStringLiteral("description"), l.description },
            { QStringLiteral("created"), l.created.toString(Qt::ISODate) },
            { QStringLiteral("modified"), l.modified.toString(Qt::ISODate) }, { QStringLiteral("items"), items },
        };
    }
    QSaveFile f(m_store);
    if (!f.open(QIODevice::WriteOnly))
        return;
    f.write(QJsonDocument(QJsonObject{ { QStringLiteral("version"), kStoreVersion }, { QStringLiteral("playlists"), lists } })
                .toJson(QJsonDocument::Compact));
    f.commit();
}

} // namespace pulse
