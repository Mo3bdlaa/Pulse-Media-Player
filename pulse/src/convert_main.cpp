// Pulse — conversion helper process.
//
// The app runs each conversion in this separate process so that a fault in
// the core's encoders can only fail that job, never the player. Protocol on
// stdout, one line per event:
//   progress <0..1> <length ms>
//   done ok
//   done fail <message>

#include "engine/engine.hpp"
#include "engine/transcoder.hpp"

#include <QCommandLineParser>
#include <QCoreApplication>
#include <QFile>
#include <QTextStream>
#include <QUrl>

#include <atomic>
#include <csignal>
#include <cstdio>
#include <string>
#include <thread>

#if defined(_WIN32)
#include <io.h>
#define PULSE_READ _read
#else
#include <unistd.h>
#define PULSE_READ ::read
#endif

namespace {
std::string g_partial;              // output path while it is incomplete
std::atomic<bool> g_complete{ false };

void onTerminate(int)
{
    // Leave no half-written file behind when the app cancels the job.
    if (!g_complete && !g_partial.empty()) {
        std::remove(g_partial.c_str());
        std::remove((g_partial + pulse::Transcoder::intermediateSuffix()).c_str()); // two-pass edits
    }
    std::_Exit(2);
}
} // namespace

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    QCoreApplication::setApplicationName(QStringLiteral("Pulse"));
    QCoreApplication::setOrganizationName(QStringLiteral("Pulse"));

    QCommandLineParser cli;
    cli.addOptions({
        { QStringLiteral("input"), QStringLiteral("Source file URL."), QStringLiteral("url") },
        { QStringLiteral("output"), QStringLiteral("Destination path."), QStringLiteral("path") },
        { QStringLiteral("container"), QStringLiteral("mp4, mkv or mp3."), QStringLiteral("name"), QStringLiteral("mp4") },
        { QStringLiteral("video"), QStringLiteral("h264, hevc, copy or none."), QStringLiteral("codec"), QStringLiteral("h264") },
        { QStringLiteral("audio"), QStringLiteral("aac, mp3 or copy."), QStringLiteral("codec"), QStringLiteral("aac") },
        { QStringLiteral("height"), QStringLiteral("Frame height; 0 keeps the source."), QStringLiteral("px"), QStringLiteral("0") },
        { QStringLiteral("video-kbps"), QStringLiteral("Video bitrate."), QStringLiteral("kbps"), QStringLiteral("0") },
        { QStringLiteral("audio-kbps"), QStringLiteral("Audio bitrate."), QStringLiteral("kbps"), QStringLiteral("192") },
        { QStringLiteral("no-hw"), QStringLiteral("Decode in software.") },
        { QStringLiteral("start-ms"), QStringLiteral("Trim: start."), QStringLiteral("ms"), QStringLiteral("0") },
        { QStringLiteral("end-ms"), QStringLiteral("Trim: end (0 = to the end)."), QStringLiteral("ms"), QStringLiteral("0") },
        { QStringLiteral("crop"), QStringLiteral("Crop rectangle in source pixels."), QStringLiteral("x,y,w,h") },
        { QStringLiteral("transform"), QStringLiteral("90, 180, 270, hflip or vflip."), QStringLiteral("type") },
        { QStringLiteral("source-size"), QStringLiteral("Source frame size, needed with crop or transform."), QStringLiteral("WxH") },
        { QStringLiteral("no-audio"), QStringLiteral("Leave the audio out.") },
    });
    cli.process(app);

    QTextStream out(stdout);
    const QUrl input(cli.value(QStringLiteral("input")));
    const QString output = cli.value(QStringLiteral("output"));
    if (!input.isLocalFile() || output.isEmpty()) {
        out << "done fail " << QCoreApplication::translate("pulse-convert", "Missing input or output") << Qt::endl;
        return 1;
    }
    g_partial = QFile::encodeName(output).toStdString();
    std::signal(SIGTERM, onTerminate);
    std::signal(SIGINT, onTerminate);
    // The app holds our stdin open; end of input means it has gone away.
    // Raw read(): a stdio read would hold the FILE lock and deadlock exit().
    std::thread([] {
        char buf[64];
        while (PULSE_READ(0, buf, sizeof buf) > 0) {
        }
        if (!g_complete)
            onTerminate(0);
    }).detach();

    pulse::Engine::Options options;
    options.appId = QStringLiteral("org.pulse.Player");
    options.appName = QStringLiteral("Pulse");
    options.appVersion = QStringLiteral(PULSE_VERSION);
    options.extraArguments = { QStringLiteral("--aout=adummy"), QStringLiteral("--vout=vdummy"), QStringLiteral("--quiet") };
    pulse::Engine engine(options);
    if (!engine.isReady()) {
        out << "done fail " << QCoreApplication::translate("pulse-convert", "The playback engine could not start") << Qt::endl;
        return 1;
    }

    pulse::TranscodeProfile profile;
    profile.container = cli.value(QStringLiteral("container"));
    profile.videoCodec = cli.value(QStringLiteral("video"));
    profile.audioCodec = cli.value(QStringLiteral("audio"));
    profile.maxHeight = cli.value(QStringLiteral("height")).toInt();
    profile.videoKbps = cli.value(QStringLiteral("video-kbps")).toInt();
    profile.audioKbps = cli.value(QStringLiteral("audio-kbps")).toInt();
    profile.hardwareDecoding = !cli.isSet(QStringLiteral("no-hw"));
    profile.startMs = cli.value(QStringLiteral("start-ms")).toLongLong();
    profile.endMs = cli.value(QStringLiteral("end-ms")).toLongLong();
    profile.transform = cli.value(QStringLiteral("transform"));
    profile.noAudio = cli.isSet(QStringLiteral("no-audio"));
    if (const QStringList c = cli.value(QStringLiteral("crop")).split(QLatin1Char(',')); c.size() == 4)
        profile.crop = QRect(c[0].toInt(), c[1].toInt(), c[2].toInt(), c[3].toInt());
    if (const QStringList wh = cli.value(QStringLiteral("source-size")).split(QLatin1Char('x')); wh.size() == 2) {
        profile.sourceWidth = wh[0].toInt();
        profile.sourceHeight = wh[1].toInt();
    }

    pulse::Transcoder transcoder;
    int last = -1;
    QObject::connect(&transcoder, &pulse::Transcoder::progress, [&](double pos, qint64 lengthMs) {
        const int permille = int(pos * 1000);
        if (permille == last)
            return;
        last = permille;
        out << "progress " << pos << ' ' << lengthMs << Qt::endl;
    });
    QObject::connect(&transcoder, &pulse::Transcoder::finished, [&](bool ok, const QString &error) {
        g_complete = ok;
        if (ok)
            out << "done ok" << Qt::endl;
        else
            out << "done fail " << error << Qt::endl;
        app.exit(ok ? 0 : 1);
    });
    if (!transcoder.start(input, output, profile)) {
        out << "done fail " << QCoreApplication::translate("pulse-convert", "This file could not be converted.") << Qt::endl;
        return 1;
    }
    return app.exec();
}
