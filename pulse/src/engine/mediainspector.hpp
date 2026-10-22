// Pulse engine adapter — everything the core can tell about one file, for
// Media Details (07) and the expanded Now Playing view (12): tags, every
// video, audio and subtitle track, and chapters.
#pragma once

#include <QObject>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>
#include <memory>

namespace pulse {

class MediaInspector : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QUrl url READ url WRITE setUrl NOTIFY urlChanged)
    Q_PROPERTY(bool loading READ isLoading NOTIFY detailsChanged)
    Q_PROPERTY(QVariantMap details READ details NOTIFY detailsChanged)
    Q_PROPERTY(QVariantList chapters READ chapters NOTIFY detailsChanged)

public:
    explicit MediaInspector(QObject *parent = nullptr);
    ~MediaInspector() override;

    QUrl url() const;
    /// Starts inspecting `url` (local files only); results are cached.
    void setUrl(const QUrl &url);
    bool isLoading() const;
    /// Keys: fileName, filePath, fileSize, modified, container, durationMs,
    /// title, artist, album, albumArtist, genre, date, description, director,
    /// actors, publisher, rating, copyright, language, showName, season,
    /// episode, trackNumber, and lists video / audio / subtitles of
    /// {codec, codecName, language, description, bitrate, …}.
    QVariantMap details() const;
    /// [{name, time, duration}] in ms.
    QVariantList chapters() const;

    struct Private;

signals:
    void urlChanged();
    void detailsChanged();

private:
    std::shared_ptr<Private> d;
};

} // namespace pulse
