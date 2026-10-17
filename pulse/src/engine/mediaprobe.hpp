// Pulse engine adapter — reads duration, resolution, codecs and tags of local
// files in the background, for the Library and Playlists.
#pragma once

#include <QObject>
#include <QUrl>
#include <QVariantMap>
#include <memory>

namespace pulse {

class MediaProbe : public QObject
{
    Q_OBJECT

public:
    explicit MediaProbe(QObject *parent = nullptr);
    ~MediaProbe() override;

    /// Queues `url` for parsing; `probed` follows on this object's thread.
    /// Keys: durationMs, width, height, videoCodec, audioCodec, videoFourcc,
    /// audioFourcc ("mp4a", "mpga", …), hasVideo,
    /// title, artist, album, date, showName, season, episode.
    void probe(const QUrl &url);

    struct Private;

signals:
    void probed(const QUrl &url, const QVariantMap &info);

private:
    std::shared_ptr<Private> d;
};

} // namespace pulse
