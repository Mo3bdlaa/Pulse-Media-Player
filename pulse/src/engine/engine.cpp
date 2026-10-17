#include "engine.hpp"

#include <QByteArray>
#include <QVariantMap>
#include <vector>

#include <vlc/vlc.h>

namespace pulse {

namespace {
Engine *s_instance = nullptr;
}

struct Engine::Private
{
    libvlc_instance_t *vlc = nullptr;
};

Engine::Engine(const Options &options, QObject *parent)
    : QObject(parent)
    , d(std::make_unique<Private>())
{
    Q_ASSERT(!s_instance);
    s_instance = this;

    // Pulse draws its own titles, OSD and controls.
    QList<QByteArray> args = {
        "--no-video-title-show",
        "--no-osd",
        "--no-snapshot-preview",
        "--no-stats",
    };
    if (!options.hardwareDecoding)
        args << "--avcodec-hw=none";
    for (const QString &arg : options.extraArguments)
        if (!arg.isEmpty())
            args << arg.toUtf8();

    std::vector<const char *> argv;
    argv.reserve(args.size());
    for (const QByteArray &a : args)
        argv.push_back(a.constData());

    d->vlc = libvlc_new(int(argv.size()), argv.data());
    if (!d->vlc) {
        qWarning("pulse: failed to initialise the playback core (libvlc_new)");
        return;
    }

    // Branding goes through the public API, never through core patches.
    const QByteArray name = options.appName.toUtf8();
    const QByteArray http = (options.appName + QLatin1Char('/') + options.appVersion
                             + QStringLiteral(" LibVLC/") + QString::fromUtf8(libvlc_get_version()))
                                .toUtf8();
    libvlc_set_user_agent(d->vlc, name.constData(), http.constData());
    libvlc_set_app_id(d->vlc, options.appId.toUtf8().constData(),
                      options.appVersion.toUtf8().constData(),
                      options.iconName.toUtf8().constData());
}

Engine::~Engine()
{
    if (d->vlc)
        libvlc_release(d->vlc);
    if (s_instance == this)
        s_instance = nullptr;
}

Engine *Engine::instance()
{
    return s_instance;
}

bool Engine::isReady() const
{
    return d->vlc != nullptr;
}

QString Engine::coreVersion() const
{
    return QString::fromUtf8(libvlc_get_version());
}

QString Engine::coreChangeset() const
{
    return QString::fromUtf8(libvlc_get_changeset());
}

QString Engine::coreCompiler() const
{
    return QString::fromUtf8(libvlc_get_compiler());
}

QVariantList Engine::equalizerPresets() const
{
    QVariantList list;
    const unsigned count = libvlc_audio_equalizer_get_preset_count();
    for (unsigned i = 0; i < count; ++i)
        list << QString::fromUtf8(libvlc_audio_equalizer_get_preset_name(i));
    return list;
}

QVariantList Engine::equalizerBands() const
{
    QVariantList list;
    const unsigned count = libvlc_audio_equalizer_get_band_count();
    for (unsigned i = 0; i < count; ++i)
        list << double(libvlc_audio_equalizer_get_band_frequency(i));
    return list;
}

void *Engine::nativeHandle() const
{
    return d->vlc;
}

} // namespace pulse
