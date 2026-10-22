#include "thumbnailer.hpp"
#include "engine.hpp"

#include <QCryptographicHash>
#include <QDir>
#include <QFileInfo>
#include <QImage>
#include <QMutex>
#include <QQuickTextureFactory>
#include <QStandardPaths>
#include <QUrl>
#include <QUrlQuery>
#include <memory>

#include <vlc/vlc.h>

namespace pulse {

namespace {

QString cacheDir()
{
    static const QString dir = [] {
        const QString d = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/thumbs");
        QDir().mkpath(d);
        return d;
    }();
    return dir;
}

// Shared between the response (GUI side) and the core callback, which may
// outlive a cancelled response.
struct Request
{
    QMutex lock;
    QQuickImageResponse *response = nullptr; // cleared by ~Response under `lock`
    QString cacheFile;
    QSize size;
    libvlc_parser_task *task = nullptr;
    QImage art; // artwork requests: first embedded picture
};

QImage pictureToImage(const libvlc_picture_t *pic)
{
    size_t size = 0;
    const unsigned char *buf = libvlc_picture_get_buffer(pic, &size);
    QImage image;
    if (libvlc_picture_type(pic) == libvlc_picture_Argb)
        image = QImage(buf, int(libvlc_picture_get_width(pic)), int(libvlc_picture_get_height(pic)),
                       int(libvlc_picture_get_stride(pic)), QImage::Format_ARGB32).copy();
    else
        image.loadFromData(buf, int(size));
    return image;
}

void deliver(const std::shared_ptr<Request> &req, QImage image);

class Response : public QQuickImageResponse
{
public:
    QImage image;
    std::shared_ptr<Request> request;
    libvlc_parser_t *parser = nullptr;

    ~Response() override
    {
        if (request) {
            QMutexLocker lock(&request->lock);
            request->response = nullptr;
        }
    }

    QQuickTextureFactory *textureFactory() const override
    {
        return QQuickTextureFactory::textureFactoryForImage(image);
    }

    // A cancelled request is left to finish: libVLC may report the
    // cancellation synchronously from inside libvlc_parser_cancel_request(),
    // and the result is cached for the next view anyway. The response no
    // longer receives it (Request::response is a QPointer).

    void finish(const QImage &img)
    {
        image = img;
        emit finished();
    }
};

void onEnded(void *opaque, libvlc_parser_task *task, libvlc_picture_t *picture)
{
    // Takes back the reference handed to the core in requestImageResponse().
    auto *holder = static_cast<std::shared_ptr<Request> *>(opaque);
    std::shared_ptr<Request> req = *holder;
    delete holder;

    QImage image = picture ? pictureToImage(picture) : QImage();
    libvlc_parser_task_release(task);
    deliver(req, image);
}

void deliver(const std::shared_ptr<Request> &req, QImage image)
{
    if (!image.isNull()) {
        if (req->size.isValid() && (image.width() > req->size.width() * 2 || image.height() > req->size.height() * 2))
            image = image.scaled(req->size * 2, Qt::KeepAspectRatioByExpanding, Qt::SmoothTransformation);
        image.save(req->cacheFile, "JPG", 88);
    }
    // Posting under the lock keeps the response alive until the event is
    // queued; Qt drops the event if the response is deleted before it runs.
    QMutexLocker lock(&req->lock);
    req->task = nullptr;
    if (auto *response = static_cast<Response *>(req->response))
        QMetaObject::invokeMethod(response, [response, image]() { response->finish(image); }, Qt::QueuedConnection);
}


void onArtAttachments(void *opaque, libvlc_parser_task *, libvlc_picture_list_t *list)
{
    auto req = *static_cast<std::shared_ptr<Request> *>(opaque);
    if (req->art.isNull() && libvlc_picture_list_count(list) > 0)
        req->art = pictureToImage(libvlc_picture_list_at(list, 0));
}

void onArtParsed(void *opaque, libvlc_parser_task *task, libvlc_parser_status_t)
{
    auto *holder = static_cast<std::shared_ptr<Request> *>(opaque);
    std::shared_ptr<Request> req = *holder;
    delete holder;
    QImage image = req->art;
    if (image.isNull()) {
        // Cover files next to the media, found by the core's local art finder.
        if (libvlc_media_t *media = libvlc_parser_task_get_media(task)) {
            if (char *art = libvlc_media_get_meta(media, libvlc_meta_ArtworkURL)) {
                const QUrl u(QString::fromUtf8(art));
                if (u.isLocalFile())
                    image.load(u.toLocalFile());
                libvlc_free(art);
            }
        }
    }
    libvlc_parser_task_release(task);
    deliver(req, image);
}

const libvlc_parser_cbs kArtCallbacks = [] {
    libvlc_parser_cbs cbs{};
    cbs.version = 0;
    cbs.on_parsed = onArtParsed;
    cbs.on_attachments_added = onArtAttachments;
    return cbs;
}();

const libvlc_thumbnailer_cbs kThumbCallbacks = [] {
    libvlc_thumbnailer_cbs cbs{};
    cbs.version = 0;
    cbs.on_ended = onEnded;
    return cbs;
}();

} // namespace

struct ThumbnailProvider::Private
{
    libvlc_parser_t *parser = nullptr;
};

ThumbnailProvider::ThumbnailProvider()
    : d(new Private)
{
    auto *vlc = Engine::instance() ? static_cast<libvlc_instance_t *>(Engine::instance()->nativeHandle()) : nullptr;
    if (vlc) {
        libvlc_parser_cfg cfg{};
        cfg.version = 0;
        cfg.max_parser_threads = 1;
        cfg.max_thumbnailer_threads = 2;
        cfg.timeout = libvlc_time_t(15) * 1000 * 1000;
        d->parser = libvlc_parser_new(vlc, &cfg);
    }
}

ThumbnailProvider::~ThumbnailProvider()
{
    if (d->parser)
        libvlc_parser_destroy(d->parser);
    delete d;
}

QQuickImageResponse *ThumbnailProvider::requestImageResponse(const QString &id, const QSize &requestedSize)
{
    auto *response = new Response;
    response->parser = d->parser;

    const int q = int(id.indexOf(QLatin1Char('?')));
    const QUrl url(QUrl::fromPercentEncoding((q < 0 ? id : id.left(q)).toUtf8()));
    const QUrlQuery query(q < 0 ? QString() : id.mid(q + 1));
    const bool artwork = query.hasQueryItem(QStringLiteral("art"));
    const bool byTime = query.hasQueryItem(QStringLiteral("t"));
    const qint64 timeMs = query.queryItemValue(QStringLiteral("t")).toLongLong();
    const bool precise = query.hasQueryItem(QStringLiteral("precise")); // editor preview: the exact frame
    const double pos = query.hasQueryItem(QStringLiteral("pos")) ? query.queryItemValue(QStringLiteral("pos")).toDouble() : 0.3;
    const int width = requestedSize.width() > 0 ? requestedSize.width() : 480;
    const int height = requestedSize.height() > 0 ? requestedSize.height() : width * 9 / 16;

    // Only local files: streams are never touched in the background.
    if (!d->parser || !url.isLocalFile() || !QFileInfo::exists(url.toLocalFile())) {
        QMetaObject::invokeMethod(response, [response] { response->finish({}); }, Qt::QueuedConnection);
        return response;
    }

    const QFileInfo fi(url.toLocalFile());
    const QByteArray key = (url.toString() + QString::number(fi.size()) + QString::number(fi.lastModified().toSecsSinceEpoch())
                            + (artwork ? QStringLiteral("art") : byTime ? QStringLiteral("t%1%2").arg(timeMs).arg(precise ? "x" : "") : QStringLiteral("p%1").arg(pos))
                            + QStringLiteral("@%1x%2").arg(width).arg(height)).toUtf8();
    const QString cacheFile = cacheDir() + QLatin1Char('/')
        + QString::fromLatin1(QCryptographicHash::hash(key, QCryptographicHash::Sha1).toHex()) + QStringLiteral(".jpg");

    QImage cached(cacheFile);
    if (!cached.isNull()) {
        QMetaObject::invokeMethod(response, [response, cached] { response->finish(cached); }, Qt::QueuedConnection);
        return response;
    }

    libvlc_media_t *media = libvlc_media_new_path(QDir::toNativeSeparators(url.toLocalFile()).toUtf8().constData());
    if (!media) {
        QMetaObject::invokeMethod(response, [response] { response->finish({}); }, Qt::QueuedConnection);
        return response;
    }

    auto req = std::make_shared<Request>();
    req->response = response;
    req->cacheFile = cacheFile;
    req->size = QSize(width, height);
    response->request = req;

    if (artwork) {
        libvlc_parser_request_t pr{};
        pr.version = 0;
        pr.media = media;
        pr.parse_flags = libvlc_media_parse_flag_t(libvlc_media_parse | libvlc_media_fetch_local);
        auto *holder = new std::shared_ptr<Request>(req);
        libvlc_parser_task *task = libvlc_parser_task_new_parse(d->parser, &pr, &kArtCallbacks, holder);
        libvlc_media_release(media);
        {
            QMutexLocker lock(&req->lock);
            req->task = task;
        }
        if (!task || libvlc_parser_submit(d->parser, task) != 0) {
            {
                QMutexLocker lock(&req->lock);
                req->task = nullptr;
            }
            if (task)
                libvlc_parser_task_release(task);
            delete holder;
            QMetaObject::invokeMethod(response, [response] { response->finish({}); }, Qt::QueuedConnection);
        }
        return response;
    }

    libvlc_thumbnailer_request_t r{};
    r.version = 0;
    r.media = media;
    r.width = unsigned(width);
    r.height = unsigned(height);
    r.crop = true;
    r.type = libvlc_picture_Png;
    r.seek.type = byTime ? libvlc_thumbnailer_seek_time : libvlc_thumbnailer_seek_pos;
    if (byTime)
        r.seek.value.time = libvlc_time_t(timeMs) * 1000;
    else
        r.seek.value.pos = pos;
    r.seek.speed = precise ? libvlc_media_thumbnail_seek_precise : libvlc_media_thumbnail_seek_fast;
    r.hw_dec = false;

    auto *holder = new std::shared_ptr<Request>(req);
    libvlc_parser_task *task = libvlc_parser_task_new_thumbnail(d->parser, &r, &kThumbCallbacks, holder);
    libvlc_media_release(media);
    {
        QMutexLocker lock(&req->lock);
        req->task = task;
    }
    if (!task || libvlc_parser_submit(d->parser, task) != 0) {
        {
            QMutexLocker lock(&req->lock);
            req->task = nullptr;
        }
        if (task)
            libvlc_parser_task_release(task);
        delete holder;
        QMetaObject::invokeMethod(response, [response] { response->finish({}); }, Qt::QueuedConnection);
    }
    return response;
}

} // namespace pulse
