#include "transcoder.hpp"
#include "engine.hpp"

#include <QDir>
#include <QFile>
#include <QPointer>

#include <vlc/vlc.h>

namespace pulse {

namespace {

QString quoted(QString path)
{
    path.replace(QLatin1Char('\\'), QStringLiteral("\\\\")).replace(QLatin1Char('"'), QStringLiteral("\\\""));
    return QLatin1Char('"') + path + QLatin1Char('"');
}

// "#transcode{…}:std{…}" for the core's stream output.
QString chainFor(const QString &output, const TranscodeProfile &p)
{
    QStringList t;
    if (p.videoCodec == QLatin1String("h264") || p.videoCodec == QLatin1String("hevc")) {
        t << QStringLiteral("vcodec=%1").arg(p.videoCodec);
        if (p.videoKbps > 0)
            t << QStringLiteral("vb=%1").arg(p.videoKbps);
        if (p.maxHeight > 0)
            t << QStringLiteral("height=%1").arg(p.maxHeight);
    }
    if (p.audioCodec != QLatin1String("copy")) {
        t << QStringLiteral("acodec=%1").arg(p.audioCodec == QLatin1String("mp3") ? QStringLiteral("mpga") : QStringLiteral("mp4a"))
          << QStringLiteral("ab=%1").arg(p.audioKbps) << QStringLiteral("channels=2") << QStringLiteral("samplerate=48000");
    }
    const QString mux = p.container == QLatin1String("mkv") ? QStringLiteral("avformat")
                      : p.container == QLatin1String("mp3") ? QStringLiteral("raw")
                                                            : QStringLiteral("mp4");
    const QString out = QStringLiteral("std{access=file,mux=%1,dst=%2}").arg(mux, quoted(QDir::toNativeSeparators(output)));
    return t.isEmpty() ? QStringLiteral("#") + out : QStringLiteral("#transcode{%1}:%2").arg(t.join(QLatin1Char(',')), out);
}

} // namespace

struct Transcoder::Private
{
    Transcoder *q = nullptr;
    libvlc_media_player_t *mp = nullptr;
    QString output;
    qint64 lengthMs = 0;
    bool running = false;
    bool cancelled = false;

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
            else if (reason == libvlc_stopping_reason_eos)
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
        p->post([p, pos]() { emit p->q->progress(pos, p->lengthMs); });
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
}

bool Transcoder::isRunning() const { return d->running; }

bool Transcoder::start(const QUrl &input, const QString &output, const TranscodeProfile &profile)
{
    auto *vlc = Engine::instance() ? static_cast<libvlc_instance_t *>(Engine::instance()->nativeHandle()) : nullptr;
    if (!vlc || d->running || !input.isLocalFile())
        return false;

    libvlc_media_t *media = libvlc_media_new_path(QDir::toNativeSeparators(input.toLocalFile()).toUtf8().constData());
    if (!media)
        return false;
    const QString chain = chainFor(output, profile);
    libvlc_media_add_option(media, (QStringLiteral(":sout=") + chain).toUtf8().constData());
    libvlc_media_add_option(media, ":no-sout-all");
    libvlc_media_add_option(media, ":sout-keep");
    libvlc_media_add_option(media, profile.hardwareDecoding ? ":avcodec-hw=any" : ":avcodec-hw=none");
    if (profile.videoCodec == QLatin1String("none"))
        libvlc_media_add_option(media, ":no-sout-video");
    if (profile.container == QLatin1String("mkv"))
        libvlc_media_add_option(media, ":sout-avformat-mux=matroska");

    d->mp = libvlc_media_player_new(vlc, Private::callbacks(), d.get());
    if (!d->mp) {
        libvlc_media_release(media);
        return false;
    }
    libvlc_media_player_set_media(d->mp, media);
    libvlc_media_release(media);
    d->output = output;
    d->lengthMs = 0;
    d->cancelled = false;
    d->running = true;
    if (libvlc_media_player_play(d->mp) != 0) {
        d->finish(false, tr("This file could not be converted."));
        return false;
    }
    return true;
}

void Transcoder::cancel()
{
    if (!d->running)
        return;
    d->cancelled = true;
    libvlc_media_player_stop_async(d->mp);
}

} // namespace pulse
