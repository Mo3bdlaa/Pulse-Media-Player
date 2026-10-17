#include "mediainspector.hpp"
#include "engine.hpp"

#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QHash>
#include <QMutex>
#include <QPointer>
#include <QTimer>

#include <vlc/vlc.h>

namespace pulse {

namespace {

constexpr qint64 toMs(libvlc_time_t t) { return t / 1000; }

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

QString containerName(const QString &suffix)
{
    static const QHash<QString, QString> names = {
        { QStringLiteral("mkv"), QStringLiteral("Matroska (MKV)") },
        { QStringLiteral("mka"), QStringLiteral("Matroska Audio (MKA)") },
        { QStringLiteral("webm"), QStringLiteral("WebM") },
        { QStringLiteral("mp4"), QStringLiteral("MPEG-4 (MP4)") },
        { QStringLiteral("m4v"), QStringLiteral("MPEG-4 (M4V)") },
        { QStringLiteral("m4a"), QStringLiteral("MPEG-4 Audio (M4A)") },
        { QStringLiteral("mov"), QStringLiteral("QuickTime (MOV)") },
        { QStringLiteral("avi"), QStringLiteral("AVI") },
        { QStringLiteral("ts"), QStringLiteral("MPEG Transport Stream") },
        { QStringLiteral("m2ts"), QStringLiteral("Blu-ray Transport Stream") },
        { QStringLiteral("mpg"), QStringLiteral("MPEG Program Stream") },
        { QStringLiteral("wmv"), QStringLiteral("Windows Media (WMV)") },
        { QStringLiteral("flv"), QStringLiteral("Flash Video (FLV)") },
        { QStringLiteral("ogg"), QStringLiteral("Ogg") },
        { QStringLiteral("ogv"), QStringLiteral("Ogg Video") },
        { QStringLiteral("mp3"), QStringLiteral("MPEG Audio (MP3)") },
        { QStringLiteral("flac"), QStringLiteral("FLAC") },
        { QStringLiteral("wav"), QStringLiteral("WAVE") },
        { QStringLiteral("opus"), QStringLiteral("Opus") },
    };
    return names.value(suffix.toLower(), suffix.toUpper());
}

QVariantList readTracks(libvlc_media_t *media, libvlc_track_type_t type)
{
    QVariantList list;
    libvlc_media_tracklist_t *tracks = libvlc_media_get_tracklist(media, type);
    if (!tracks)
        return list;
    for (size_t i = 0; i < libvlc_media_tracklist_count(tracks); ++i) {
        const libvlc_media_track_t *t = libvlc_media_tracklist_at(tracks, i);
        QVariantMap m;
        const char *codecName = libvlc_media_get_codec_description(t->i_type, t->i_codec);
        m[QStringLiteral("codec")] = fourccText(t->i_codec);
        m[QStringLiteral("codecName")] = QString::fromUtf8(codecName ? codecName : "");
        m[QStringLiteral("language")] = QString::fromUtf8(t->psz_language);
        m[QStringLiteral("description")] = QString::fromUtf8(t->psz_description);
        m[QStringLiteral("name")] = QString::fromUtf8(t->psz_name);
        m[QStringLiteral("bitrate")] = t->i_bitrate;
        m[QStringLiteral("profile")] = t->i_profile;
        m[QStringLiteral("level")] = t->i_level;
        if (type == libvlc_track_video && t->u.video) {
            m[QStringLiteral("width")] = t->u.video->i_width;
            m[QStringLiteral("height")] = t->u.video->i_height;
            if (t->u.video->i_frame_rate_den)
                m[QStringLiteral("frameRate")] = double(t->u.video->i_frame_rate_num) / t->u.video->i_frame_rate_den;
            const double sar = t->u.video->i_sar_den ? double(t->u.video->i_sar_num) / t->u.video->i_sar_den : 1.0;
            if (t->u.video->i_height)
                m[QStringLiteral("aspect")] = double(t->u.video->i_width) * (sar > 0 ? sar : 1.0) / t->u.video->i_height;
        } else if (type == libvlc_track_audio && t->u.audio) {
            m[QStringLiteral("channels")] = t->u.audio->i_channels;
            m[QStringLiteral("sampleRate")] = t->u.audio->i_rate;
        } else if (type == libvlc_track_text && t->u.subtitle) {
            m[QStringLiteral("encoding")] = QString::fromUtf8(t->u.subtitle->psz_encoding);
        }
        list << m;
    }
    libvlc_media_tracklist_delete(tracks);
    return list;
}

} // namespace

// Held by Private while the chapter reader runs; weak, so it never keeps
// Private alive.
struct ReaderContext
{
    std::weak_ptr<MediaInspector::Private> d;
    int generation;
};

struct MediaInspector::Private
{
    QMutex lock;
    MediaInspector *owner = nullptr; // cleared by ~MediaInspector under `lock`
    libvlc_parser_t *parser = nullptr;

    // GUI thread only.
    QUrl url;
    int generation = 0;
    bool loading = false;
    QVariantMap details;
    QVariantList chapters;
    QHash<QUrl, QPair<QVariantMap, QVariantList>> cache;

    // Chapters: a silent, paused open of the file (the parser does not report them).
    libvlc_media_player_t *reader = nullptr;
    std::unique_ptr<ReaderContext> readerContext;
    unsigned char scratch[16 * 16 * 4];
    QTimer readerTimeout;

    void finish(MediaInspector *q)
    {
        stopReader();
        loading = false;
        cache.insert(url, { details, chapters });
        emit q->detailsChanged();
    }

    void stopReader()
    {
        readerTimeout.stop();
        if (reader) {
            libvlc_media_player_stop_async(reader);
            libvlc_media_player_release(reader);
            reader = nullptr;
        }
    }

    void readChapters()
    {
        chapters.clear();
        libvlc_chapter_description_t **descs = nullptr;
        const int count = reader ? libvlc_media_player_get_full_chapter_descriptions(reader, -1, &descs) : 0;
        for (int i = 0; i < count; ++i) {
            QString name = QString::fromUtf8(descs[i]->psz_name);
            if (name.isEmpty())
                name = MediaInspector::tr("Chapter %1").arg(i + 1);
            chapters << QVariantMap{ { QStringLiteral("name"), name },
                                     { QStringLiteral("time"), toMs(descs[i]->i_time_offset) },
                                     { QStringLiteral("duration"), toMs(descs[i]->i_duration) } };
        }
        if (count > 0)
            libvlc_chapter_descriptions_release(descs, unsigned(count));
    }
};

namespace {

struct ParseTask
{
    std::shared_ptr<MediaInspector::Private> d;
    int generation;
};


// Core thread -> GUI thread, dropped if the inspector is gone or moved on.
template <typename Fn>
void post(const std::shared_ptr<MediaInspector::Private> &d, int generation, Fn &&fn)
{
    QMutexLocker lock(&d->lock);
    if (MediaInspector *owner = d->owner) {
        QPointer<MediaInspector> guard(owner);
        QMetaObject::invokeMethod(owner, [guard, d, generation, fn = std::forward<Fn>(fn)]() {
            if (guard && d->generation == generation)
                fn(guard.data());
        }, Qt::QueuedConnection);
    }
}

} // namespace

static void readerTitleSelection(void *opaque, const libvlc_title_description_t *, unsigned)
{
    auto *ctx = static_cast<ReaderContext *>(opaque);
    auto d = ctx->d.lock();
    if (!d)
        return;
    post(d, ctx->generation, [d](MediaInspector *q) {
        d->readChapters();
        if (!d->chapters.isEmpty())
            d->finish(q);
    });
}

static void readerStopping(void *opaque, libvlc_media_t *, libvlc_stopping_reason_t)
{
    auto *ctx = static_cast<ReaderContext *>(opaque);
    auto d = ctx->d.lock();
    if (!d)
        return;
    post(d, ctx->generation, [d](MediaInspector *q) {
        if (d->loading)
            d->finish(q);
    });
}

// The reader decodes one frame into a scratch buffer: with a real video
// output the input pauses on that frame (:start-paused) instead of racing to
// the end, so the chapter list is still there when the GUI thread reads it.
static void *readerLock(void *opaque, void **planes)
{
    planes[0] = static_cast<MediaInspector::Private *>(opaque)->scratch;
    return nullptr;
}
static void readerUnlock(void *, void *, void *const *) {}
static void readerDisplay(void *, void *) {}

static const libvlc_media_player_cbs *readerCallbacks()
{
    static const libvlc_media_player_cbs cbs = [] {
        libvlc_media_player_cbs c{};
        c.version = 0;
        c.on_title_selection_changed = readerTitleSelection;
        c.on_media_stopping = readerStopping;
        return c;
    }();
    return &cbs;
}

static void onParsed(void *opaque, libvlc_parser_task *task, libvlc_parser_status_t status)
{
    std::unique_ptr<ParseTask> t(static_cast<ParseTask *>(opaque));
    QVariantMap info;
    libvlc_media_t *media = libvlc_parser_task_get_media(task);
    if (media && status == libvlc_parser_status_done) {
        const libvlc_time_t duration = libvlc_media_get_duration(media);
        info[QStringLiteral("durationMs")] = duration > 0 ? toMs(duration) : qint64(0);
        static const std::pair<const char *, libvlc_meta_t> metas[] = {
            { "title", libvlc_meta_Title }, { "artist", libvlc_meta_Artist }, { "album", libvlc_meta_Album },
            { "albumArtist", libvlc_meta_AlbumArtist }, { "genre", libvlc_meta_Genre }, { "date", libvlc_meta_Date },
            { "description", libvlc_meta_Description }, { "director", libvlc_meta_Director },
            { "actors", libvlc_meta_Actors }, { "publisher", libvlc_meta_Publisher }, { "rating", libvlc_meta_Rating },
            { "copyright", libvlc_meta_Copyright }, { "language", libvlc_meta_Language },
            { "showName", libvlc_meta_ShowName }, { "season", libvlc_meta_Season },
            { "episode", libvlc_meta_Episode }, { "trackNumber", libvlc_meta_TrackNumber },
        };
        for (const auto &[key, meta] : metas) {
            const QString v = takeString(libvlc_media_get_meta(media, meta));
            if (!v.isEmpty())
                info[QLatin1String(key)] = v;
        }
        info[QStringLiteral("video")] = readTracks(media, libvlc_track_video);
        info[QStringLiteral("audio")] = readTracks(media, libvlc_track_audio);
        info[QStringLiteral("subtitles")] = readTracks(media, libvlc_track_text);
    }
    libvlc_parser_task_release(task);

    auto d = t->d;
    post(d, t->generation, [d, info](MediaInspector *q) {
        const QFileInfo fi(d->url.toLocalFile());
        QVariantMap all = info;
        all[QStringLiteral("fileName")] = fi.fileName();
        all[QStringLiteral("filePath")] = QDir::toNativeSeparators(fi.absoluteFilePath());
        all[QStringLiteral("fileSize")] = fi.size();
        all[QStringLiteral("modified")] = fi.lastModified();
        all[QStringLiteral("container")] = containerName(fi.suffix());
        // The core reports the file name as the title when there is no tag.
        if (all.value(QStringLiteral("title")).toString() == fi.fileName())
            all.remove(QStringLiteral("title"));
        d->details = all;
        emit q->detailsChanged();

        // Chapters need a real open; skip files without video (albums, songs).
        auto *vlc = Engine::instance() ? static_cast<libvlc_instance_t *>(Engine::instance()->nativeHandle()) : nullptr;
        if (!vlc || all.value(QStringLiteral("video")).toList().isEmpty())
            return d->finish(q);
        libvlc_media_t *m = libvlc_media_new_path(QDir::toNativeSeparators(d->url.toLocalFile()).toUtf8().constData());
        if (!m)
            return d->finish(q);
        for (const char *opt : { ":no-audio", ":no-spu", ":start-paused" })
            libvlc_media_add_option(m, opt);
        d->readerContext = std::make_unique<ReaderContext>(ReaderContext{ d, d->generation });
        d->reader = libvlc_media_player_new(vlc, readerCallbacks(), d->readerContext.get());
        if (!d->reader) {
            libvlc_media_release(m);
            return d->finish(q);
        }
        libvlc_video_set_callbacks(d->reader, readerLock, readerUnlock, readerDisplay, d.get());
        libvlc_video_set_format(d->reader, "RV32", 16, 16, 16 * 4);
        libvlc_media_player_set_media(d->reader, m);
        libvlc_media_release(m);
        libvlc_media_player_play(d->reader);
        d->readerTimeout.start(2000);
    });
}

static const libvlc_parser_cbs kParseCallbacks = [] {
    libvlc_parser_cbs cbs{};
    cbs.version = 0;
    cbs.on_parsed = onParsed;
    return cbs;
}();

MediaInspector::MediaInspector(QObject *parent)
    : QObject(parent)
    , d(std::make_shared<Private>())
{
    d->owner = this;
    d->readerTimeout.setSingleShot(true);
    connect(&d->readerTimeout, &QTimer::timeout, this, [this] {
        d->readChapters();
        d->finish(this);
    });
    auto *vlc = Engine::instance() ? static_cast<libvlc_instance_t *>(Engine::instance()->nativeHandle()) : nullptr;
    if (vlc) {
        libvlc_parser_cfg cfg{};
        cfg.version = 0;
        cfg.max_parser_threads = 1;
        cfg.max_thumbnailer_threads = 1;
        cfg.timeout = libvlc_time_t(10) * 1000 * 1000;
        d->parser = libvlc_parser_new(vlc, &cfg);
    }
}

MediaInspector::~MediaInspector()
{
    {
        QMutexLocker lock(&d->lock);
        d->owner = nullptr;
    }
    d->stopReader();
    if (d->parser)
        libvlc_parser_destroy(d->parser);
}

QUrl MediaInspector::url() const { return d->url; }
bool MediaInspector::isLoading() const { return d->loading; }
QVariantMap MediaInspector::details() const { return d->details; }
QVariantList MediaInspector::chapters() const { return d->chapters; }

void MediaInspector::setUrl(const QUrl &url)
{
    if (d->url == url)
        return;
    d->stopReader();
    ++d->generation;
    d->url = url;
    d->details.clear();
    d->chapters.clear();
    d->loading = false;
    emit urlChanged();

    if (const auto hit = d->cache.constFind(url); hit != d->cache.constEnd()) {
        d->details = hit->first;
        d->chapters = hit->second;
    } else if (d->parser && url.isLocalFile() && QFileInfo::exists(url.toLocalFile())) {
        libvlc_media_t *media = libvlc_media_new_path(QDir::toNativeSeparators(url.toLocalFile()).toUtf8().constData());
        if (media) {
            libvlc_parser_request_t req{};
            req.version = 0;
            req.media = media;
            req.parse_flags = libvlc_media_parse_flag_t(libvlc_media_parse | libvlc_media_fetch_local);
            auto *task = new ParseTask{ d, d->generation };
            libvlc_parser_task *t = libvlc_parser_task_new_parse(d->parser, &req, &kParseCallbacks, task);
            libvlc_media_release(media);
            if (t && libvlc_parser_submit(d->parser, t) == 0) {
                d->loading = true;
            } else {
                if (t)
                    libvlc_parser_task_release(t);
                delete task;
            }
        }
    }
    emit detailsChanged();
}

} // namespace pulse
