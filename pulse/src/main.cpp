// Pulse — application entry point.

#include "app/appinfo.hpp"
#include "app/convertqueue.hpp"
#include "app/iconprovider.hpp"
#include "app/library.hpp"
#include "app/mediainput.hpp"
#include "app/playlists.hpp"
#include "app/playqueue.hpp"
#include "app/preferences.hpp"
#include "app/recentmedia.hpp"
#include "engine/engine.hpp"
#include "engine/mediainspector.hpp"
#include "engine/mediaprobe.hpp"
#include "engine/player.hpp"
#include "engine/thumbnailer.hpp"
#include "engine/videooutput.hpp"

#include <QFontDatabase>
#include <QGuiApplication>
#include <QIcon>
#include <QProcessEnvironment>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QSurfaceFormat>
#include <QUrl>

int main(int argc, char *argv[])
{
    // Video frames are shared between the core's GL context and Qt Quick's.
    QCoreApplication::setAttribute(Qt::AA_ShareOpenGLContexts);
    QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);

    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("Pulse"));
    QGuiApplication::setOrganizationName(QStringLiteral("Pulse"));
    QGuiApplication::setOrganizationDomain(QStringLiteral("pulse.player"));
    QGuiApplication::setApplicationVersion(QStringLiteral(PULSE_VERSION));
    QGuiApplication::setDesktopFileName(QStringLiteral("org.pulse.Player"));
    QGuiApplication::setWindowIcon(QIcon(QStringLiteral(":/qt/qml/Pulse/assets/logo/pulse-mark.svg")));

    // Inter is bundled when present in assets/fonts (OFL); otherwise the system sans is used.
    for (const char *f : { ":/qt/qml/Pulse/assets/fonts/InterVariable.ttf" })
        QFontDatabase::addApplicationFont(QString::fromLatin1(f));

    pulse::Preferences prefs;

    pulse::Engine::Options options;
    options.appId = QStringLiteral("org.pulse.Player");
    options.appName = QStringLiteral("Pulse");
    options.appVersion = QStringLiteral(PULSE_VERSION);
    options.iconName = QStringLiteral("org.pulse.Player");
    options.hardwareDecoding = prefs.hardwareDecoding();
    options.extraArguments = QProcessEnvironment::systemEnvironment()
                                 .value(QStringLiteral("PULSE_VLC_ARGS"))
                                 .split(QLatin1Char(' '), Qt::SkipEmptyParts);
    pulse::Engine engine(options);
    if (!engine.isReady())
        return 1;

    pulse::Player player;
    pulse::PlayQueue queue;
    pulse::RecentMedia recent;
    pulse::MediaInput input;
    pulse::Library library;
    pulse::Playlists playlists;
    pulse::ConvertQueue converter;

    // One background probe feeds durations and tags to the Library and Playlists.
    pulse::MediaProbe probe;
    QObject::connect(&library, &pulse::Library::probeRequested, &probe, &pulse::MediaProbe::probe);
    QObject::connect(&playlists, &pulse::Playlists::probeRequested, &probe, &pulse::MediaProbe::probe);
    QObject::connect(&probe, &pulse::MediaProbe::probed, &library, &pulse::Library::applyProbe);
    QObject::connect(&probe, &pulse::MediaProbe::probed, &playlists, &pulse::Playlists::applyProbe);
    library.rescan();
    playlists.refreshDurations();

    pulse::AppInfo info;
    info.version = QStringLiteral(PULSE_VERSION);
#if defined(Q_OS_ANDROID) || defined(Q_OS_IOS)
    info.mobile = true;
#endif
    for (const QString &arg : pulse::MediaInput::mediaArguments(app.arguments()))
        info.initialMedia << pulse::MediaInput::fromUserInput(arg);

    const char *uri = "Pulse.Core";
    qmlRegisterSingletonInstance(uri, 1, 0, "Engine", &engine);
    qmlRegisterSingletonInstance(uri, 1, 0, "Player", &player);
    qmlRegisterSingletonInstance(uri, 1, 0, "Queue", &queue);
    qmlRegisterSingletonInstance(uri, 1, 0, "Recent", &recent);
    qmlRegisterSingletonInstance(uri, 1, 0, "Prefs", &prefs);
    qmlRegisterSingletonInstance(uri, 1, 0, "MediaInput", &input);
    qmlRegisterSingletonInstance(uri, 1, 0, "AppInfo", &info);
    qmlRegisterSingletonInstance(uri, 1, 0, "Library", &library);
    qmlRegisterSingletonInstance(uri, 1, 0, "Playlists", &playlists);
    qmlRegisterSingletonInstance(uri, 1, 0, "Converter", &converter);
    qmlRegisterUncreatableType<pulse::ConvertJobs>(uri, 1, 0, "ConvertJobs", QStringLiteral("Owned by Converter"));
    qmlRegisterType<pulse::VideoOutput>(uri, 1, 0, "VideoOutput");
    qmlRegisterType<pulse::MediaInspector>(uri, 1, 0, "MediaInspector");

    QQmlApplicationEngine qml;
    qml.addImageProvider(QStringLiteral("icon"), new pulse::IconProvider);
    qml.addImageProvider(QStringLiteral("thumb"), new pulse::ThumbnailProvider);
    qml.addImportPath(QStringLiteral("qrc:/qt/qml"));
    QObject::connect(&qml, &QQmlApplicationEngine::objectCreationFailed, &app,
                     [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    qml.load(QUrl(QStringLiteral("qrc:/qt/qml/Pulse/qml/Main.qml")));

    const int rc = app.exec();
    player.stop();
    return rc;
}
