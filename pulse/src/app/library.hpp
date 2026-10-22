// Pulse — the media library (06): an index of folders the user chose.
//
// Files are never moved, renamed or modified. The index lives in one JSON
// file; durations, resolutions and tags come from the engine's MediaProbe
// (wired in main.cpp through probeRequested/applyProbe).
#pragma once

#include <QAbstractListModel>
#include <QDateTime>
#include <QHash>
#include <QTimer>
#include <QUrl>
#include <QVariantList>
#include <QVector>

namespace pulse {

class Library : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(QVariantList folders READ folders NOTIFY foldersChanged)
    Q_PROPERTY(bool scanning READ isScanning NOTIFY scanningChanged)
    Q_PROPERTY(int totalCount READ totalCount NOTIFY contentChanged)
    Q_PROPERTY(QVariantMap counts READ counts NOTIFY contentChanged)
    Q_PROPERTY(int revision READ revision NOTIFY contentChanged)
    Q_PROPERTY(int count READ count NOTIFY viewChanged)
    Q_PROPERTY(QString category READ category WRITE setCategory NOTIFY viewChanged)
    Q_PROPERTY(QString search READ search WRITE setSearch NOTIFY viewChanged)
    Q_PROPERTY(QString sort READ sort WRITE setSort NOTIFY viewChanged)

public:
    enum Role {
        UrlRole = Qt::UserRole + 1, TitleRole, SubtitleRole, CategoryRole, FolderRole, DurationRole,
        QualityRole, IsAudioRole, YearRole, AddedRole, AvailableRole, DetailRole
    };

    /// `storePath` defaults to <AppData>/library.json.
    explicit Library(const QString &storePath = {}, QObject *parent = nullptr);
    ~Library() override;

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    QVariantList folders() const;
    bool isScanning() const { return m_scanning; }
    int totalCount() const { return int(m_items.size()); }
    QVariantMap counts() const;
    int revision() const { return m_revision; }
    int count() const { return int(m_view.size()); }
    QString category() const { return m_category; }
    void setCategory(const QString &category);
    QString search() const { return m_search; }
    void setSearch(const QString &search);
    QString sort() const { return m_sort; }
    void setSort(const QString &sort);

    Q_INVOKABLE void addFolder(const QUrl &folder);
    Q_INVOKABLE void removeFolder(const QString &path);
    Q_INVOKABLE void rescan();
    /// Newest files first, across every category.
    Q_INVOKABLE QVariantList recentlyAdded(int limit) const;
    /// The row for `url` as a map (empty when it is not in the library).
    Q_INVOKABLE QVariantMap item(const QUrl &url) const;
    /// URLs of the current view, in order (Play all).
    Q_INVOKABLE QList<QUrl> viewUrls() const;
    /// Standard Videos and Music folders that exist and are not added yet.
    Q_INVOKABLE QVariantList suggestedFolders() const;

    /// Category for a file, from its name, folder and probed facts.
    static QString classify(const QString &path, bool audio, qint64 durationMs, int season, const QString &showName);

public slots:
    void applyProbe(const QUrl &url, const QVariantMap &info);

signals:
    void foldersChanged();
    void scanningChanged();
    void contentChanged();
    void viewChanged();
    void probeRequested(const QUrl &url);

private:
    struct Item
    {
        QString path;
        QString folder;
        qint64 size = 0;
        qint64 mtime = 0;
        QDateTime added;
        bool probed = false;
        qint64 durationMs = 0;
        int width = 0, height = 0;
        QString videoCodec, audioCodec;
        QString metaTitle, artist, album, showName;
        int season = 0, episode = 0, year = 0;
        bool available = true;
        // derived
        QString title, category;
    };
    struct Found
    {
        QString path;
        qint64 size;
        qint64 mtime;
    };

    void derive(Item &item) const;
    QVariantMap toMap(const Item &item) const;
    QString subtitleFor(const Item &item) const;
    void rebuildView();
    void scanFolders(const QStringList &folders);
    void mergeScan(const QStringList &folders, const QVector<Found> &found);
    void pumpProbes();
    void load();
    void scheduleSave();
    void save() const;
    void touch();

    QString m_store;
    QStringList m_folders;
    QVector<Item> m_items;
    QHash<QString, int> m_index; // path -> m_items row
    QVector<int> m_view;         // rows of m_items in display order
    QString m_category = QStringLiteral("all");
    QString m_search;
    QString m_sort = QStringLiteral("added");
    bool m_scanning = false;
    int m_scansRunning = 0;
    int m_revision = 0;
    QStringList m_probeQueue;
    int m_probesInFlight = 0;
    QTimer m_saveTimer;
};

} // namespace pulse
