// Pulse — saved playlists (08). Items point to files and addresses; nothing
// is ever copied. Stored in one JSON file; M3U/M3U8 import and export.
#pragma once

#include <QAbstractListModel>
#include <QDateTime>
#include <QSet>
#include <QTimer>
#include <QUrl>
#include <QVariantList>
#include <QVector>

namespace pulse {

class Playlists : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY viewChanged)
    Q_PROPERTY(int totalCount READ totalCount NOTIFY contentChanged)
    Q_PROPERTY(QVariantMap counts READ counts NOTIFY contentChanged)
    Q_PROPERTY(int revision READ revision NOTIFY contentChanged)
    Q_PROPERTY(QString filter READ filter WRITE setFilter NOTIFY viewChanged)
    Q_PROPERTY(QString search READ search WRITE setSearch NOTIFY viewChanged)

public:
    enum Role {
        IdRole = Qt::UserRole + 1, NameRole, DescriptionRole, ItemCountRole, DurationRole, KindRole, CoverRole,
        CreatedRole, ModifiedRole
    };

    /// `storePath` defaults to <AppData>/playlists.json.
    explicit Playlists(const QString &storePath = {}, QObject *parent = nullptr);
    ~Playlists() override;

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const { return int(m_view.size()); }
    int totalCount() const { return int(m_lists.size()); }
    QVariantMap counts() const;
    int revision() const { return m_revision; }
    QString filter() const { return m_filter; }
    void setFilter(const QString &filter);
    QString search() const { return m_search; }
    void setSearch(const QString &search);

    /// Returns the new playlist's id.
    Q_INVOKABLE QString create(const QString &name, const QList<QUrl> &urls = {});
    Q_INVOKABLE void rename(const QString &id, const QString &name);
    Q_INVOKABLE void setDescription(const QString &id, const QString &description);
    Q_INVOKABLE void remove(const QString &id);
    Q_INVOKABLE void addUrls(const QString &id, const QList<QUrl> &urls);
    Q_INVOKABLE void removeItem(const QString &id, int index);
    Q_INVOKABLE void moveItem(const QString &id, int from, int to);
    Q_INVOKABLE void clear(const QString &id);

    /// {id, name, description, itemCount, durationMs, kind, cover, created, modified}
    Q_INVOKABLE QVariantMap get(const QString &id) const;
    /// [{url, title, durationMs, isAudio, available}]
    Q_INVOKABLE QVariantList items(const QString &id) const;
    Q_INVOKABLE QList<QUrl> urls(const QString &id) const;
    /// Every playlist, newest first: [{id, name, itemCount}] (pickers).
    Q_INVOKABLE QVariantList all() const;
    /// Id of the playlist at `row` of the current view, or "".
    Q_INVOKABLE QString idAt(int row) const;
    /// Row of `id` in the current view, or -1.
    Q_INVOKABLE int rowOf(const QString &id) const;

    Q_INVOKABLE bool exportM3u(const QString &id, const QUrl &file) const;
    /// Returns the new playlist's id, or "" when nothing playable was found.
    Q_INVOKABLE QString importM3u(const QUrl &file);

public slots:
    /// Asks for durations the store does not know yet (call once wired).
    void refreshDurations();
    void applyProbe(const QUrl &url, const QVariantMap &info);

signals:
    void contentChanged();
    void viewChanged();
    void probeRequested(const QUrl &url);

private:
    struct Entry
    {
        QUrl url;
        QString title;
        qint64 durationMs = 0;
    };
    struct List
    {
        QString id;
        QString name;
        QString description;
        QDateTime created;
        QDateTime modified;
        QVector<Entry> entries;
    };

    int find(const QString &id) const;
    QString kindOf(const List &list) const;
    qint64 durationOf(const List &list) const;
    QUrl coverOf(const List &list) const;
    Entry makeEntry(const QUrl &url, const QString &title = {}, qint64 durationMs = 0);
    void changed(List &list);
    void rebuildView();
    void load();
    void save() const;

    QString m_store;
    QVector<List> m_lists;
    QVector<int> m_view;
    QString m_filter = QStringLiteral("all");
    QString m_search;
    int m_revision = 0;
    QSet<QString> m_probing;
    QTimer m_saveTimer;
};

} // namespace pulse
