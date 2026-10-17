// Pulse — recent files and resume positions, stored only on this device.
#pragma once

#include <QAbstractListModel>
#include <QDateTime>
#include <QUrl>
#include <QVector>

namespace pulse {

class RecentMedia : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(bool enabled READ isEnabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(int revision READ revision NOTIFY revisionChanged)

public:
    enum Role { UrlRole = Qt::UserRole + 1, TitleRole, DetailRole, PositionRole, LengthRole, ProgressRole, IsAudioRole, IsStreamRole, WhenRole };

    explicit RecentMedia(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const;
    bool isEnabled() const;
    void setEnabled(bool enabled);

    /// Saved resume point for `url` in ms (0 when none or nearly finished).
    Q_INVOKABLE qint64 resumePosition(const QUrl &url) const;
    /// Started but unfinished local files, most recent first:
    /// [{url, title, position, length, progress, isAudio}]
    Q_INVOKABLE QVariantList continueWatching(int limit) const;
    int revision() const { return m_revision; }

public slots:
    void touch(const QUrl &url);
    void savePosition(const QUrl &url, qint64 positionMs, qint64 lengthMs);
    void remove(int index);
    void clear();

signals:
    void countChanged();
    void enabledChanged();
    void revisionChanged();

private:
    struct Entry
    {
        QUrl url;
        qint64 position = 0;
        qint64 length = 0;
        QDateTime when;
    };
    int find(const QUrl &url) const;
    void load();
    void save() const;

    QVector<Entry> m_entries;
    bool m_enabled = true;
    int m_revision = 0;
};

} // namespace pulse
