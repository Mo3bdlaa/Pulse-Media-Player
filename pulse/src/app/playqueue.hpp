// Pulse — the playback queue (UI-owned; the engine plays one item at a time).
#pragma once

#include <QAbstractListModel>
#include <QUrl>
#include <QVector>

namespace pulse {

class PlayQueue : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(int currentIndex READ currentIndex NOTIFY currentChanged)
    Q_PROPERTY(QUrl currentUrl READ currentUrl NOTIFY currentChanged)
    Q_PROPERTY(bool hasNext READ hasNext NOTIFY currentChanged)
    Q_PROPERTY(bool hasPrevious READ hasPrevious NOTIFY currentChanged)
    Q_PROPERTY(bool shuffle READ shuffle WRITE setShuffle NOTIFY modeChanged)
    Q_PROPERTY(Repeat repeat READ repeat WRITE setRepeat NOTIFY modeChanged)

public:
    enum Repeat { RepeatOff, RepeatAll, RepeatOne };
    Q_ENUM(Repeat)

    enum Role { UrlRole = Qt::UserRole + 1, TitleRole, IsCurrentRole, IsAudioRole, MissingRole };

    explicit PlayQueue(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const;
    int currentIndex() const;
    QUrl currentUrl() const;
    bool hasNext() const;
    bool hasPrevious() const;
    bool shuffle() const;
    void setShuffle(bool on);
    Repeat repeat() const;
    void setRepeat(Repeat mode);

public slots:
    /// Replaces the queue and makes `start` current.
    void setItems(const QList<QUrl> &urls, int start = 0);
    void append(const QList<QUrl> &urls);
    void playIndex(int index);
    void remove(int index);
    void move(int from, int to);
    /// Removes entries only; never touches files.
    void clear();
    bool next();
    bool previous();
    /// Called when the current item finished; honours repeat and shuffle.
    bool advance();
    void cycleRepeat();
    QList<QUrl> urls() const;

signals:
    void countChanged();
    void currentChanged();
    void modeChanged();
    /// The item at `url` should start playing now.
    void playRequested(const QUrl &url);

private:
    struct Item
    {
        QUrl url;
        QString title;
        bool audio = false;
    };
    int nextIndex() const;
    void setCurrent(int index);

    QVector<Item> m_items;
    int m_current = -1;
    bool m_shuffle = false;
    Repeat m_repeat = RepeatOff;
};

} // namespace pulse
