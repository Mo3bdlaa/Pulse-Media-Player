// Pulse — turning user input (paths, URLs, drops, folders) into playable URLs.
#pragma once

#include <QDateTime>
#include <QObject>
#include <QStringList>
#include <QUrl>
#include <QVariantList>

namespace pulse {

class MediaInput : public QObject
{
    Q_OBJECT

public:
    explicit MediaInput(QObject *parent = nullptr);

    /// Command-line arguments or text: local paths become file URLs.
    Q_INVOKABLE static QUrl fromUserInput(const QString &text);
    /// Expands folders (non-recursively sorted, recursive scan) into media files.
    Q_INVOKABLE static QList<QUrl> expand(const QList<QUrl> &urls);
    Q_INVOKABLE static QList<QUrl> expandFolder(const QUrl &folder);
    Q_INVOKABLE static bool isSubtitle(const QUrl &url);
    Q_INVOKABLE static bool isAudio(const QUrl &url);
    Q_INVOKABLE static bool isMedia(const QUrl &url);
    Q_INVOKABLE static bool exists(const QUrl &url);
    Q_INVOKABLE static QString displayName(const QUrl &url);
    /// "MP4 · 1.8 GB" for local files, "RTSP · stream" for addresses.
    Q_INVOKABLE static QString describe(const QUrl &url);
    Q_INVOKABLE static QString formatTime(qint64 ms);
    Q_INVOKABLE static QString formatSize(qint64 bytes);
    Q_INVOKABLE static QString scheme(const QUrl &url);
    Q_INVOKABLE static QString picturesFolder();
    /// "2 hours ago", "Yesterday", "3 days ago", or a short date.
    Q_INVOKABLE static QString relativeTime(const QDateTime &when);
    /// Deletes cached frame thumbnails; they are regenerated on demand.
    Q_INVOKABLE static void clearThumbnailCache();

    static QStringList mediaArguments(const QStringList &args);
};

} // namespace pulse
