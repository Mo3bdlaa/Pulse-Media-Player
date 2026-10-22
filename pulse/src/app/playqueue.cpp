#include "playqueue.hpp"
#include "mediainput.hpp"

#include <QRandomGenerator>

namespace pulse {

PlayQueue::PlayQueue(QObject *parent)
    : QAbstractListModel(parent)
{
}

int PlayQueue::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : int(m_items.size());
}

QVariant PlayQueue::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_items.size())
        return {};
    const Item &item = m_items[index.row()];
    switch (role) {
    case UrlRole: return item.url;
    case Qt::DisplayRole:
    case TitleRole: return item.title;
    case IsCurrentRole: return index.row() == m_current;
    case IsAudioRole: return item.audio;
    case MissingRole: return item.url.isLocalFile() && !MediaInput::exists(item.url);
    }
    return {};
}

QHash<int, QByteArray> PlayQueue::roleNames() const
{
    return {
        { UrlRole, "url" },
        { TitleRole, "title" },
        { IsCurrentRole, "isCurrent" },
        { IsAudioRole, "isAudio" },
        { MissingRole, "missing" },
    };
}

int PlayQueue::count() const { return int(m_items.size()); }
int PlayQueue::currentIndex() const { return m_current; }
QUrl PlayQueue::currentUrl() const { return m_current >= 0 ? m_items[m_current].url : QUrl(); }
bool PlayQueue::hasNext() const { return nextIndex() >= 0; }
bool PlayQueue::hasPrevious() const { return m_current > 0 || (m_repeat == RepeatAll && m_items.size() > 1); }
bool PlayQueue::shuffle() const { return m_shuffle; }
PlayQueue::Repeat PlayQueue::repeat() const { return m_repeat; }

void PlayQueue::setShuffle(bool on)
{
    if (m_shuffle == on)
        return;
    m_shuffle = on;
    emit modeChanged();
    emit currentChanged();
}

void PlayQueue::setRepeat(Repeat mode)
{
    if (m_repeat == mode)
        return;
    m_repeat = mode;
    emit modeChanged();
    emit currentChanged();
}

void PlayQueue::cycleRepeat()
{
    setRepeat(Repeat((int(m_repeat) + 1) % 3));
}

void PlayQueue::setItems(const QList<QUrl> &urls, int start)
{
    beginResetModel();
    m_items.clear();
    for (const QUrl &url : urls)
        m_items.push_back({ url, MediaInput::displayName(url), MediaInput::isAudio(url) });
    m_current = -1;
    endResetModel();
    emit countChanged();
    setCurrent(m_items.isEmpty() ? -1 : qBound(0, start, int(m_items.size()) - 1));
}

void PlayQueue::append(const QList<QUrl> &urls)
{
    if (urls.isEmpty())
        return;
    const int first = int(m_items.size());
    beginInsertRows({}, first, first + int(urls.size()) - 1);
    for (const QUrl &url : urls)
        m_items.push_back({ url, MediaInput::displayName(url), MediaInput::isAudio(url) });
    endInsertRows();
    emit countChanged();
    if (m_current < 0)
        setCurrent(first);
    else
        emit currentChanged();
}

void PlayQueue::playIndex(int index)
{
    if (index >= 0 && index < m_items.size())
        setCurrent(index);
}

void PlayQueue::remove(int index)
{
    if (index < 0 || index >= m_items.size())
        return;
    beginRemoveRows({}, index, index);
    m_items.removeAt(index);
    endRemoveRows();
    emit countChanged();
    if (index < m_current) {
        --m_current;
        emit currentChanged();
    } else if (index == m_current) {
        // Keep playing the old item until the user picks another one.
        m_current = -1;
        emit currentChanged();
    }
}

void PlayQueue::move(int from, int to)
{
    if (from == to || from < 0 || to < 0 || from >= m_items.size() || to >= m_items.size())
        return;
    beginMoveRows({}, from, from, {}, to > from ? to + 1 : to);
    m_items.move(from, to);
    endMoveRows();
    if (m_current == from)
        m_current = to;
    else if (from < m_current && to >= m_current)
        --m_current;
    else if (from > m_current && to <= m_current)
        ++m_current;
    emit currentChanged();
}

void PlayQueue::clear()
{
    beginResetModel();
    m_items.clear();
    m_current = -1;
    endResetModel();
    emit countChanged();
    emit currentChanged();
}

int PlayQueue::nextIndex() const
{
    const int n = int(m_items.size());
    if (n == 0)
        return -1;
    if (m_shuffle && n > 1) {
        int i = m_current;
        while (i == m_current)
            i = int(QRandomGenerator::global()->bounded(n));
        return i;
    }
    if (m_current + 1 < n)
        return m_current + 1;
    return m_repeat == RepeatAll ? 0 : -1;
}

bool PlayQueue::next()
{
    const int i = nextIndex();
    if (i < 0)
        return false;
    setCurrent(i);
    return true;
}

bool PlayQueue::previous()
{
    if (m_current > 0) {
        setCurrent(m_current - 1);
        return true;
    }
    if (m_repeat == RepeatAll && !m_items.isEmpty()) {
        setCurrent(int(m_items.size()) - 1);
        return true;
    }
    return false;
}

bool PlayQueue::advance()
{
    if (m_repeat == RepeatOne && m_current >= 0) {
        emit playRequested(m_items[m_current].url);
        return true;
    }
    return next();
}

QList<QUrl> PlayQueue::urls() const
{
    QList<QUrl> out;
    for (const Item &item : m_items)
        out << item.url;
    return out;
}

void PlayQueue::setCurrent(int index)
{
    const int old = m_current;
    m_current = index;
    if (old >= 0 && old < m_items.size())
        emit dataChanged(this->index(old), this->index(old), { IsCurrentRole });
    if (index >= 0)
        emit dataChanged(this->index(index), this->index(index), { IsCurrentRole });
    emit currentChanged();
    if (index >= 0)
        emit playRequested(m_items[index].url);
}

} // namespace pulse
