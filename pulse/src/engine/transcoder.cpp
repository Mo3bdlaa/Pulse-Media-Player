#include "transcoder.hpp"
#include "engine.hpp"

#include <QDir>
#include <QFile>
#include <QPointer>
#include <algorithm>

#include <vlc/vlc.h>

namespace pulse {

namespace {

QString quoted(QString path)
{
    path.replace(QLatin1Char('\\'), QStringLiteral("\\\\")).replace(QLatin1Char('"'), QStringLiteral("\\\""));
    return QLatin1Char('"') + path + QLatin1Char('"');
}

int even(int v) { return v & ~1; }

// One pass of the core's stream output: a single video filter at most.
struct Stage
{
    QUrl input;
    QString output;
    TranscodeProfile profile; // codecs, sizes and trim for this pass
    QString filter;           // "" | "crop" | "transform"
    double base = 0, span = 1; // share of the overall progress
};

// "#transcode{…}:std{…}" for the core's stream output.
QString chainFor(const Stage &s, int outWidth, int outHeight)
{
    const TranscodeProfile &p = s.profile;
    QStringList t;
    if (p.videoCodec == QLatin1String("h264") || p.videoCodec == QLatin1String("hevc")) {
        t << QStringLiteral("vcodec=%1").arg(p.videoCodec);
        if (p.videoKbps > 0)
            t << QStringLiteral("vb=%1").arg(p.videoKbps);
        if (outWidth > 0 && outHeight > 0)
            t << QStringLiteral("width=%1").arg(outWidth) << QStringLiteral("height=%1").arg(outHeight);
        else if (p.maxHeight > 0)
            t << QStringLiteral("height=%1").arg(p.maxHeight);
        if (s.filter == QLatin1String("crop")) {
            const QRect c = p.crop;
            t << QStringLiteral("vfilter=croppadd{croptop=%1,cropbottom=%2,cropleft=%3,cropright=%4}")
                     .arg(c.top()).arg(std::max(0, p.sourceHeight - c.top() - c.height()))
                     .arg(c.left()).arg(std::max(0, p.sourceWidth - c.left() - c.width()));
        } else if (s.filter == QLatin1String("transform")) {
            // soverlay makes the transcoder turn the pixels, not just the orientation flag.
            t << QStringLiteral("soverlay") << QStringLiteral("vfilter=transform{type=%1}").arg(p.transform);
        }
    }
    if (!p.noAudio && p.audioCodec != QLatin1String("copy")) {
        t << QStringLiteral("acodec=%1").arg(p.audioCodec == QLatin1String("mp3") ? QStringLiteral("mpga") : QStringLiteral("mp4a"))
          << QStringLiteral("ab=%1").arg(p.audioKbps) << QStringLiteral("channels=2") << QStringLiteral("samplerate=48000");
    }
    const QString mux = p.container == QLatin1String("mkv") ? QStringLiteral("avformat")
                      : p.container == QLatin1String("mp3") ? QStringLiteral("raw")
                                                            : QStringLiteral("mp4");
    const QString out = QStringLiteral("std{access=file,mux=%1,dst=%2}").arg(mux, quoted(QDir::toNativeSeparators(s.output)));
    return t.isEmpty() ? QStringLiteral("#") + out : QStringLiteral("#transcode{%1}:%2").arg(t.join(QLatin1Char(',')), out);
}

} // namespace

struct Transcoder::Private
{
    Transcoder *q = nullptr;
    libvlc_media_player_t *mp = nullptr;
    QString output;
    QStringList temporary; // intermediate files of multi-pass jobs
    QList<Stage> stages;
    int stage = 0;
    qint64 lengthMs = 0;
    bool running = false;
    bool cancelled = false;

    bool startStage();

    template <typename Fn>
    void post(Fn &&fn)
    {
        QPointer<Transcoder> guard(q);
        QMetaObject::invokeMethod(q, [guard, fn = std::forward<Fn>(fn)]() {
            if (guard)
                fn();
        }, Qt::QueuedConnection);
    }

    void finish(bool ok, const QString &error)
    {
        if (!running)
            return;
        running = false;
        if (mp) {
            libvlc_media_player_stop_async(mp);
            libvlc_media_player_release(mp);
            mp = nullptr;
        }
        for (const QString &f : std::as_const(temporary))
            QFile::remove(f);
        temporary.clear();
        if (!ok)
            QFile::remove(output);
        emit q->finished(ok, error);
    }

    static Private *self(void *opaque) { return static_cast<Private *>(opaque); }

    static void onStopping(void *opaque, libvlc_media_t *, libvlc_stopping_reason_t reason)
    {
        Private *p = self(opaque);
        p->post([p, reason]() {
            if (p->cancelled)
                p->finish(false, Transcoder::tr("Cancelled"));
            else if (reason == libvlc_stopping_reason_eos && p->stage + 1 < p->stages.size()) {
                // Next pass reads what this one wrote.
                libvlc_media_player_release(p->mp);
                p->mp = nullptr;
                ++p->stage;
                if (!p->startStage())
                    p->finish(false, Transcoder::tr("This file could not be converted."));
            } else if (reason == libvlc_stopping_reason_eos)
                p->finish(true, {});
            else
                p->finish(false, Transcoder::tr("This file could not be converted."));
        });
    }

    static void onState(void *opaque, libvlc_state_t s)
    {
        if (s != libvlc_Error)
            return;
        Private *p = self(opaque);
        p->post([p]() { p->finish(false, Transcoder::tr("This file could not be converted.")); });
    }

    static void onPosition(void *opaque, libvlc_time_t, double pos)
    {
        Private *p = self(opaque);
        p->post([p, pos]() {
            if (p->stages.isEmpty())
                return;
            const Stage &s = p->stages[p->stage];
            // Trimmed passes report position over the whole file.
            double frac = pos;
            if (p->lengthMs > 0 && (s.profile.startMs > 0 || s.profile.endMs > 0)) {
                const double end = s.profile.endMs > 0 ? double(s.profile.endMs) : double(p->lengthMs);
                frac = (pos * p->lengthMs - s.profile.startMs) / std::max(1.0, end - s.profile.startMs);
            }
            frac = std::clamp(frac, 0.0, 1.0);
            emit p->q->progress(s.base + s.span * frac, p->lengthMs);
        });
    }

    static void onLength(void *opaque, libvlc_time_t length)
    {
        Private *p = self(opaque);
        p->post([p, length]() { p->lengthMs = length / 1000; });
    }

    static const libvlc_media_player_cbs *callbacks()
    {
        static const libvlc_media_player_cbs cbs = [] {
            libvlc_media_player_cbs c{};
            c.version = 0;
            c.on_media_stopping = onStopping;
            c.on_state_changed = onState;
            c.on_position_changed = onPosition;
            c.on_length_changed = onLength;
            return c;
        }();
        return &cbs;
    }
};

Transcoder::Transcoder(QObject *parent)
    : QObject(parent)
    , d(std::make_unique<Private>())
{
    d->q = this;
}

Transcoder::~Transcoder()
{
    if (d->mp) {
        libvlc_media_player_stop_async(d->mp);
        libvlc_media_player_release(d->mp);
        QFile::remove(d->output);
    }
    for (const QString &f : std::as_const(d->temporary))
        QFile::remove(f);
}

bool Transcoder::isRunning() const { return d->running; }

bool Transcoder::start(const QUrl &input, const QString &output, const TranscodeProfile &profile)
{
    if (!Engine::instance() || d->running || !input.isLocalFile())
        return false;
    const bool video = profile.videoCodec == QLatin1String("h264") || profile.videoCodec == QLatin1String("hevc");
    QRect crop = profile.crop;
    if (!crop.isNull()) {
        crop = QRect(even(crop.x()), even(crop.y()), even(crop.width()), even(crop.height()))
                   .intersected(QRect(0, 0, profile.sourceWidth, profile.sourceHeight));
        if (crop.width() < 16 || crop.height() < 16)
            return false;
    }
    const bool needCrop = video && !crop.isNull() && crop != QRect(0, 0, profile.sourceWidth, profile.sourceHeight);
    const bool needTransform = video && !profile.transform.isEmpty();
    if ((needCrop || needTransform) && (profile.sourceWidth <= 0 || profile.sourceHeight <= 0))
        return false;

    d->stages.clear();
    d->temporary.clear();
    if (needCrop && needTransform) {
        // Pass 1: trim and crop into a high-quality intermediate.
        Stage first;
        first.input = input;
        first.output = output + QLatin1String(Transcoder::intermediateSuffix());
        first.profile = profile;
        first.profile.crop = crop;
        first.profile.container = QStringLiteral("mkv");
        first.profile.videoCodec = QStringLiteral("h264");
        first.profile.videoKbps = std::max(12000, profile.videoKbps * 3);
        first.profile.audioCodec = QStringLiteral("copy");
        first.profile.maxHeight = 0;
        first.filter = QStringLiteral("crop");
        first.span = 0.5;
        // Pass 2: rotate or flip, then the requested format.
        Stage second;
        second.input = QUrl::fromLocalFile(first.output);
        second.output = output;
        second.profile = profile;
        second.profile.startMs = second.profile.endMs = 0;
        second.profile.crop = QRect();
        second.profile.sourceWidth = crop.width();
        second.profile.sourceHeight = crop.height();
        second.filter = QStringLiteral("transform");
        second.base = 0.5;
        second.span = 0.5;
        d->stages << first << second;
        d->temporary << first.output;
    } else {
        Stage only;
        only.input = input;
        only.output = output;
        only.profile = profile;
        only.profile.crop = crop;
        only.filter = needCrop ? QStringLiteral("crop") : needTransform ? QStringLiteral("transform") : QString();
        d->stages << only;
    }
    d->output = output;
    d->stage = 0;
    d->cancelled = false;
    d->running = true;
    if (!d->startStage()) {
        d->running = false;
        for (const QString &f : std::as_const(d->temporary))
            QFile::remove(f);
        return false;
    }
    return true;
}

bool Transcoder::Private::startStage()
{
    auto *vlc = static_cast<libvlc_instance_t *>(Engine::instance()->nativeHandle());
    const Stage &s = stages[stage];
    const TranscodeProfile &p = s.profile;

    // Explicit output size whenever the picture changes shape (rotation swaps it).
    int w = 0, h = 0;
    if (!s.filter.isEmpty()) {
        w = s.filter == QLatin1String("crop") ? p.crop.width() : p.sourceWidth;
        h = s.filter == QLatin1String("crop") ? p.crop.height() : p.sourceHeight;
        if (s.filter == QLatin1String("transform") && (p.transform == QLatin1String("90") || p.transform == QLatin1String("270")))
            std::swap(w, h);
        if (p.maxHeight > 0 && p.maxHeight < h) {
            w = even(int(double(w) * p.maxHeight / h + 0.5));
            h = even(p.maxHeight);
        }
        w = even(w);
        h = even(h);
    }

    libvlc_media_t *media = libvlc_media_new_path(QDir::toNativeSeparators(s.input.toLocalFile()).toUtf8().constData());
    if (!media)
        return false;
    libvlc_media_add_option(media, (QStringLiteral(":sout=") + chainFor(s, w, h)).toUtf8().constData());
    libvlc_media_add_option(media, ":no-sout-all");
    libvlc_media_add_option(media, ":sout-keep");
    libvlc_media_add_option(media, p.hardwareDecoding ? ":avcodec-hw=any" : ":avcodec-hw=none");
    if (p.videoCodec == QLatin1String("none"))
        libvlc_media_add_option(media, ":no-sout-video");
    if (p.noAudio)
        libvlc_media_add_option(media, ":no-sout-audio");
    if (p.container == QLatin1String("mkv"))
        libvlc_media_add_option(media, ":sout-avformat-mux=matroska");
    if (p.startMs > 0)
        libvlc_media_add_option(media, QStringLiteral(":start-time=%1").arg(p.startMs / 1000.0, 0, 'f', 3).toUtf8().constData());
    if (p.endMs > 0)
        libvlc_media_add_option(media, QStringLiteral(":stop-time=%1").arg(p.endMs / 1000.0, 0, 'f', 3).toUtf8().constData());

    mp = libvlc_media_player_new(vlc, callbacks(), this);
    if (!mp) {
        libvlc_media_release(media);
        return false;
    }
    libvlc_media_player_set_media(mp, media);
    libvlc_media_release(media);
    lengthMs = 0;
    return libvlc_media_player_play(mp) == 0;
}

void Transcoder::cancel()
{
    if (!d->running)
        return;
    d->cancelled = true;
    libvlc_media_player_stop_async(d->mp);
}

} // namespace pulse
