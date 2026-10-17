#include "recentmedia.hpp"
#include "mediainput.hpp"

#include <QSettings>

namespace pulse {

namespace {
constexpr int kMaxEntries = 30;
// Files shorter than this, or nearly finished, do not offer to resume.
constexpr qint64 kMinResumeLength = 5 * 60 * 1000;
constexpr qint64 kResumeTail = 30 * 1000;
}

RecentMedia::RecentMedia(QObject *parent)
    : QAbstractListModel(parent)
{
    load();
    auto bump = [this] { ++m_revision; emit revisionChanged(); };
    connect(this, &RecentMedia::countChanged, this, bump);
    connect(this, &QAbstractItemModel::dataChanged, this, bump);
    connect(this, &QAbstractItemModel::rowsMoved, this, bump);
}

QVariantList RecentMedia::continueWatching(int limit) const
{
    QVariantList out;
    for (const Entry &e : m_entries) {
        if (out.size() >= limit)
            break;
        if (!e.url.isLocalFile() || resumePosition(e.url) <= 0 || !MediaInput::exists(e.url))
            continue;
        out << QVariantMap{
            { QStringLiteral("url"), e.url },
            { QStringLiteral("title"), MediaInput::displayName(e.url) },
            { QStringLiteral("position"), e.position },
            { QStringLiteral("length"), e.length },
            { QStringLiteral("progress"), double(e.position) / double(e.length) },
            { QStringLiteral("isAudio"), MediaInput::isAudio(e.url) },
        };
    }
    return out;
}

int RecentMedia::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : int(m_entries.size());
}

QVariant RecentMedia::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_entries.size())
        return {};
    const Entry &e = m_entries[index.row()];
    switch (role) {
    case UrlRole: return e.url;
    case Qt::DisplayRole:
    case TitleRole: return MediaInput::displayName(e.url);
    case DetailRole: return MediaInput::describe(e.url);
    case PositionRole: return e.position;
    case LengthRole: return e.length;
    case ProgressRole: return e.length > 0 ? double(e.position) / double(e.length) : 0.0;
    case IsAudioRole: return MediaInput::isAudio(e.url);
    case IsStreamRole: return !e.url.isLocalFile();
    case WhenRole: return e.when;
    }
    return {};
}

QHash<int, QByteArray> RecentMedia::roleNames() const
{
    return {
        { UrlRole, "url" }, { TitleRole, "title" }, { DetailRole, "detail" },
        { PositionRole, "position" }, { LengthRole, "length" }, { ProgressRole, "progress" },
        { IsAudioRole, "isAudio" }, { IsStreamRole, "isStream" }, { WhenRole, "when" },
    };
}

int RecentMedia::count() const { return int(m_entries.size()); }
bool RecentMedia::isEnabled() const { return m_enabled; }

void RecentMedia::setEnabled(bool enabled)
{
    if (m_enabled == enabled)
        return;
    m_enabled = enabled;
    if (!enabled)
        clear();
    emit enabledChanged();
}

qint64 RecentMedia::resumePosition(const QUrl &url) const
{
    const int i = find(url);
    if (i < 0)
        return 0;
    const Entry &e = m_entries[i];
    if (e.length < kMinResumeLength || e.position < 10000 || e.position > e.length - kResumeTail)
        return 0;
    return e.position;
}

void RecentMedia::touch(const QUrl &url)
{
    if (!m_enabled || url.isEmpty())
        return;
    Entry entry{ url, 0, 0, QDateTime::currentDateTime() };
    const int i = find(url);
    if (i >= 0) {
        entry.position = m_entries[i].position;
        entry.length = m_entries[i].length;
        beginRemoveRows({}, i, i);
        m_entries.removeAt(i);
        endRemoveRows();
    }
    beginInsertRows({}, 0, 0);
    m_entries.prepend(entry);
    endInsertRows();
    if (m_entries.size() > kMaxEntries) {
        beginRemoveRows({}, kMaxEntries, int(m_entries.size()) - 1);
        m_entries.resize(kMaxEntries);
        endRemoveRows();
    }
    save();
    emit countChanged();
}

void RecentMedia::savePosition(const QUrl &url, qint64 positionMs, qint64 lengthMs)
{
    const int i = find(url);
    if (i < 0)
        return;
    m_entries[i].position = positionMs;
    m_entries[i].length = lengthMs;
    emit dataChanged(index(i), index(i), { PositionRole, LengthRole, ProgressRole });
    save();
}

void RecentMedia::remove(int i)
{
    if (i < 0 || i >= m_entries.size())
        return;
    beginRemoveRows({}, i, i);
    m_entries.removeAt(i);
    endRemoveRows();
    save();
    emit countChanged();
}

void RecentMedia::clear()
{
    beginResetModel();
    m_entries.clear();
    endResetModel();
    save();
    emit countChanged();
}

int RecentMedia::find(const QUrl &url) const
{
    for (int i = 0; i < m_entries.size(); ++i)
        if (m_entries[i].url == url)
            return i;
    return -1;
}

void RecentMedia::load()
{
    QSettings s;
    const int n = s.beginReadArray(QStringLiteral("recent"));
    for (int i = 0; i < n; ++i) {
        s.setArrayIndex(i);
        Entry e;
        e.url = s.value(QStringLiteral("url")).toUrl();
        e.position = s.value(QStringLiteral("position")).toLongLong();
        e.length = s.value(QStringLiteral("length")).toLongLong();
        e.when = s.value(QStringLiteral("when")).toDateTime();
        if (!e.url.isEmpty())
            m_entries.push_back(e);
    }
    s.endArray();
}

void RecentMedia::save() const
{
    QSettings s;
    s.remove(QStringLiteral("recent"));
    s.beginWriteArray(QStringLiteral("recent"), int(m_entries.size()));
    for (int i = 0; i < m_entries.size(); ++i) {
        s.setArrayIndex(i);
        s.setValue(QStringLiteral("url"), m_entries[i].url);
        s.setValue(QStringLiteral("position"), m_entries[i].position);
        s.setValue(QStringLiteral("length"), m_entries[i].length);
        s.setValue(QStringLiteral("when"), m_entries[i].when);
    }
    s.endArray();
}

} // namespace pulse
