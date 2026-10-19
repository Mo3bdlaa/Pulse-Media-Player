// Pulse engine adapter — frame thumbnails for QML.
//
//   image://thumb/<percent-encoded media URL>?pos=0.3     (position 0..1)
//   image://thumb/<percent-encoded media URL>?t=125000    (time in ms)
//   image://thumb/<percent-encoded media URL>?t=125000&precise=1  (exact frame, slower)
//
// Frames come from the core's thumbnailer and are cached on disk, so lists
// show real pictures from the user's files instead of placeholders.
#pragma once

#include <QQuickAsyncImageProvider>

namespace pulse {

class ThumbnailProvider : public QQuickAsyncImageProvider
{
public:
    ThumbnailProvider();
    ~ThumbnailProvider() override;

    QQuickImageResponse *requestImageResponse(const QString &id, const QSize &requestedSize) override;

    struct Private;

private:
    Private *d;
};

} // namespace pulse
