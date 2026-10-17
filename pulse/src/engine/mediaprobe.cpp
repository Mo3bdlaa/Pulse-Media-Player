#include "mediaprobe.hpp"
#include "engine.hpp"

#include <QDir>
#include <QMutex>

#include <vlc/vlc.h>

namespace pulse {

namespace {

QString takeString(char *s)
{
    if (!s)
        return {};
    QString out = QString::fromUtf8(s);
    libvlc_free(s);
    return out;
}

QString fourccText(uint32_t fourcc)
{
    QString s;
    for (int i = 0; i < 4; ++i) {
        const char c = char((fourcc >> (8 * i)) & 0xff);
        if (c > ' ')
            s += QLatin1Char(c);
    }
    return s;
}

QString codecName(libvlc_track_type_t type, uint32_t fourcc)
{
    const char *desc = libvlc_media_get_codec_description(type, fourcc);
    return desc ? QString::fromUtf8(desc) : QString();
}

} // namespace

struct MediaProbe::Private
{
    QMutex lock;
    MediaProbe *owner = nullptr; // cleared by ~MediaProbe under `lock`
    libvlc_parser_t *parser = nullptr;
};

namespace {

struct Task
{
    std::shared_ptr<MediaProbe::Private> d;
    QUrl url;
};

void onParsed(void *opaque, libvlc_parser_task *task, libvlc_parser_status_t status)
{
    std::unique_ptr<Task> t(static_cast<Task *>(opaque));
    QVariantMap info;
    libvlc_media_t *media = libvlc_parser_task_get_media(task);
    if (media && status == libvlc_parser_status_done) {
        const libvlc_time_t duration = libvlc_media_get_duration(media);
        info.insert(QStringLiteral("durationMs"), duration > 0 ? qint64(duration / 1000) : qint64(0));

        if (libvlc_media_tracklist_t *video = libvlc_media_get_tracklist(media, libvlc_track_video)) {
            if (libvlc_media_tracklist_count(video) > 0 && libvlc_media_tracklist_at(video, 0)->u.video) {
                const libvlc_media_track_t *tr = libvlc_media_tracklist_at(video, 0);
                info.insert(QStringLiteral("hasVideo"), true);
                info.insert(QStringLiteral("width"), int(tr->u.video->i_width));
                info.insert(QStringLiteral("height"), int(tr->u.video->i_height));
                info.insert(QStringLiteral("videoCodec"), codecName(libvlc_track_video, tr->i_codec));
                info.insert(QStringLiteral("videoFourcc"), fourccText(tr->i_codec));
            }
            libvlc_media_tracklist_delete(video);
        }
        if (libvlc_media_tracklist_t *audio = libvlc_media_get_tracklist(media, libvlc_track_audio)) {
            if (libvlc_media_tracklist_count(audio) > 0) {
                const uint32_t codec = libvlc_media_tracklist_at(audio, 0)->i_codec;
                info.insert(QStringLiteral("audioCodec"), codecName(libvlc_track_audio, codec));
                info.insert(QStringLiteral("audioFourcc"), fourccText(codec));
            }
            libvlc_media_tracklist_delete(audio);
        }
        info.insert(QStringLiteral("title"), takeString(libvlc_media_get_meta(media, libvlc_meta_Title)));
        info.insert(QStringLiteral("artist"), takeString(libvlc_media_get_meta(media, libvlc_meta_Artist)));
        info.insert(QStringLiteral("album"), takeString(libvlc_media_get_meta(media, libvlc_meta_Album)));
        info.insert(QStringLiteral("date"), takeString(libvlc_media_get_meta(media, libvlc_meta_Date)));
        info.insert(QStringLiteral("showName"), takeString(libvlc_media_get_meta(media, libvlc_meta_ShowName)));
        info.insert(QStringLiteral("season"), takeString(libvlc_media_get_meta(media, libvlc_meta_Season)).toInt());
        info.insert(QStringLiteral("episode"), takeString(libvlc_media_get_meta(media, libvlc_meta_Episode)).toInt());
    }
    libvlc_parser_task_release(task);

    QMutexLocker lock(&t->d->lock);
    if (MediaProbe *owner = t->d->owner) {
        const QUrl url = t->url;
        QMetaObject::invokeMethod(owner, [owner, url, info]() { emit owner->probed(url, info); }, Qt::QueuedConnection);
    }
}

const libvlc_parser_cbs kCallbacks = [] {
    libvlc_parser_cbs cbs{};
    cbs.version = 0;
    cbs.on_parsed = onParsed;
    return cbs;
}();

} // namespace

MediaProbe::MediaProbe(QObject *parent)
    : QObject(parent)
    , d(std::make_shared<Private>())
{
    d->owner = this;
    auto *vlc = Engine::instance() ? static_cast<libvlc_instance_t *>(Engine::instance()->nativeHandle()) : nullptr;
    if (vlc) {
        libvlc_parser_cfg cfg{};
        cfg.version = 0;
        cfg.max_parser_threads = 2;
        cfg.max_thumbnailer_threads = 1;
        cfg.timeout = libvlc_time_t(10) * 1000 * 1000;
        d->parser = libvlc_parser_new(vlc, &cfg);
    }
}

MediaProbe::~MediaProbe()
{
    {
        QMutexLocker lock(&d->lock);
        d->owner = nullptr;
    }
    if (d->parser)
        libvlc_parser_destroy(d->parser);
}

void MediaProbe::probe(const QUrl &url)
{
    auto fail = [this, url] {
        QMetaObject::invokeMethod(this, [this, url] { emit probed(url, {}); }, Qt::QueuedConnection);
    };
    if (!d->parser || !url.isLocalFile())
        return fail();
    libvlc_media_t *media = libvlc_media_new_path(QDir::toNativeSeparators(url.toLocalFile()).toUtf8().constData());
    if (!media)
        return fail();

    libvlc_parser_request_t req{};
    req.version = 0;
    req.media = media;
    req.parse_flags = libvlc_media_parse_flag_t(libvlc_media_parse | libvlc_media_fetch_local);
    auto *task = new Task{ d, url };
    libvlc_parser_task *t = libvlc_parser_task_new_parse(d->parser, &req, &kCallbacks, task);
    libvlc_media_release(media);
    if (!t || libvlc_parser_submit(d->parser, t) != 0) {
        if (t)
            libvlc_parser_task_release(t);
        delete task;
        fail();
    }
}

} // namespace pulse
