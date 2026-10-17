// Engine contract tests: they pin the behaviour Pulse relies on, so an
// upstream libVLC change that breaks it fails CI before it reaches users.

#include "app/convertqueue.hpp"
#include "engine/engine.hpp"
#include "engine/mediainspector.hpp"
#include "engine/mediaprobe.hpp"
#include "engine/player.hpp"
#include "engine/transcoder.hpp"

#include <QDataStream>
#include <QFile>
#include <QProcess>
#include <QSignalSpy>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QtTest>

using namespace pulse;

namespace {

// Writes a mono 16-bit PCM WAV of `seconds` silence; no external tools needed.
QString writeWav(const QString &path, int seconds)
{
    const quint32 rate = 8000, dataSize = rate * 2 * quint32(seconds);
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly))
        return {};
    QDataStream s(&f);
    s.setByteOrder(QDataStream::LittleEndian);
    s.writeRawData("RIFF", 4); s << quint32(36 + dataSize);
    s.writeRawData("WAVE", 4);
    s.writeRawData("fmt ", 4); s << quint32(16) << quint16(1) << quint16(1) << rate << rate * 2 << quint16(2) << quint16(16);
    s.writeRawData("data", 4); s << dataSize;
    f.write(QByteArray(int(dataSize), '\0'));
    return path;
}

} // namespace

class EngineTest : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase()
    {
        QStandardPaths::setTestModeEnabled(true);
        Engine::Options o;
        o.appId = QStringLiteral("org.pulse.Player.tests");
        o.appName = QStringLiteral("Pulse");
        o.appVersion = QStringLiteral("test");
        o.extraArguments = { QStringLiteral("--aout=adummy"), QStringLiteral("--vout=vdummy") };
        m_engine = new Engine(o, this);
        QVERIFY2(m_engine->isReady(), "libVLC failed to initialise");
        QVERIFY(m_dir.isValid());
        m_wav = QUrl::fromLocalFile(writeWav(m_dir.filePath(QStringLiteral("tone.wav")), 3));
    }

    void reportsCoreVersion()
    {
        QVERIFY(m_engine->coreVersion().startsWith(QLatin1Char('4')));
        QVERIFY(!m_engine->equalizerPresets().isEmpty());
        QCOMPARE(m_engine->equalizerBands().size(), 10);
    }

    void playsLocalFileToEnd()
    {
        Player player;
        QSignalSpy ended(&player, &Player::endReached);
        player.open(m_wav);
        QTRY_COMPARE_WITH_TIMEOUT(player.state(), Player::Playing, 10000);
        QTRY_VERIFY_WITH_TIMEOUT(player.length() > 2500 && player.length() < 3500, 5000);
        QCOMPARE(player.audioTracks().size(), 1);
        QVERIFY(!player.hasVideo());
        QVERIFY(ended.wait(10000));
    }

    void seeksAndPauses()
    {
        Player player;
        player.open(m_wav);
        QTRY_COMPARE_WITH_TIMEOUT(player.state(), Player::Playing, 10000);
        QTRY_VERIFY_WITH_TIMEOUT(player.isSeekable(), 5000);
        player.seek(2000);
        QTRY_VERIFY_WITH_TIMEOUT(player.time() >= 1900, 5000);
        player.togglePause();
        QTRY_COMPARE_WITH_TIMEOUT(player.state(), Player::Paused, 5000);
        player.togglePause();
        QTRY_COMPARE_WITH_TIMEOUT(player.state(), Player::Playing, 5000);
    }

    void startTimeIsHonoured()
    {
        Player player;
        player.open(m_wav, 1500);
        QTRY_COMPARE_WITH_TIMEOUT(player.state(), Player::Playing, 10000);
        QTRY_VERIFY_WITH_TIMEOUT(player.time() >= 1400, 5000);
    }

    void reportsErrorForMissingFile()
    {
        Player player;
        QSignalSpy error(&player, &Player::errorOccurred);
        player.open(QUrl::fromLocalFile(m_dir.filePath(QStringLiteral("missing.mkv"))));
        QVERIFY(error.wait(10000));
        QCOMPARE(player.state(), Player::Error);
    }

    void picturePropertiesRoundTrip()
    {
        Player player;
        player.setBrightness(150);
        QCOMPARE(player.brightness(), 100);
        player.setHue(-30);
        QCOMPARE(player.hue(), -30);
        player.resetPicture();
        QCOMPARE(player.hue(), 0);
        player.setEqualizerPreset(0);
        QVERIFY(player.isEqualizerEnabled());
        QCOMPARE(player.equalizerAmps().size(), 10);
    }

    void probesDurationAndCodec()
    {
        MediaProbe probe;
        QSignalSpy done(&probe, &MediaProbe::probed);
        probe.probe(m_wav);
        QVERIFY(done.wait(10000));
        const QVariantMap info = done.first().at(1).toMap();
        QVERIFY(info.value(QStringLiteral("durationMs")).toLongLong() > 2500);
        QVERIFY(!info.value(QStringLiteral("hasVideo")).toBool());
        QVERIFY(!info.value(QStringLiteral("audioCodec")).toString().isEmpty());
    }

    void inspectsTracksAndFile()
    {
        MediaInspector inspector;
        inspector.setUrl(m_wav);
        QVERIFY(inspector.isLoading());
        QTRY_VERIFY_WITH_TIMEOUT(!inspector.isLoading(), 10000);
        const QVariantMap d = inspector.details();
        QCOMPARE(d.value(QStringLiteral("fileName")).toString(), QStringLiteral("tone.wav"));
        QCOMPARE(d.value(QStringLiteral("container")).toString(), QStringLiteral("WAVE"));
        QVERIFY(d.value(QStringLiteral("durationMs")).toLongLong() > 2500);
        const QVariantList audio = d.value(QStringLiteral("audio")).toList();
        QCOMPARE(audio.size(), 1);
        QCOMPARE(audio.first().toMap().value(QStringLiteral("sampleRate")).toInt(), 8000);
        QVERIFY(d.value(QStringLiteral("video")).toList().isEmpty());
        // A second visit is served from the cache.
        inspector.setUrl(QUrl());
        inspector.setUrl(m_wav);
        QVERIFY(!inspector.isLoading());
        QCOMPARE(inspector.details().value(QStringLiteral("fileName")).toString(), QStringLiteral("tone.wav"));
    }

    void convertsAudioAndPlaysTheResult_data()
    {
        QTest::addColumn<QString>("container");
        QTest::addColumn<QString>("audioCodec");
        QTest::newRow("mp3") << QStringLiteral("mp3") << QStringLiteral("mp3");
        QTest::newRow("mp4/aac") << QStringLiteral("mp4") << QStringLiteral("aac");
        QTest::newRow("mkv/aac") << QStringLiteral("mkv") << QStringLiteral("aac");
    }

    void convertsAudioAndPlaysTheResult()
    {
        QFETCH(QString, container);
        QFETCH(QString, audioCodec);
        TranscodeProfile p;
        p.container = container;
        p.videoCodec = QStringLiteral("none");
        p.audioCodec = audioCodec;
        const QString out = m_dir.filePath(QStringLiteral("out.") + (container == QLatin1String("mp4") ? QStringLiteral("m4a") : container));
        Transcoder t;
        QSignalSpy done(&t, &Transcoder::finished);
        QVERIFY(t.start(m_wav, out, p));
        QVERIFY(done.wait(30000));
        QVERIFY2(done.first().at(0).toBool(), qPrintable(done.first().at(1).toString()));
        QVERIFY(QFileInfo(out).size() > 1000);

        MediaProbe probe;
        QSignalSpy probed(&probe, &MediaProbe::probed);
        probe.probe(QUrl::fromLocalFile(out));
        QVERIFY(probed.wait(10000));
        QVERIFY(probed.first().at(1).toMap().value(QStringLiteral("durationMs")).toLongLong() > 2000);
    }

    void cancelRemovesPartialOutput()
    {
        TranscodeProfile p;
        p.container = QStringLiteral("mp3");
        p.videoCodec = QStringLiteral("none");
        p.audioCodec = QStringLiteral("mp3");
        const QString out = m_dir.filePath(QStringLiteral("cancel.mp3"));
        Transcoder t;
        QSignalSpy done(&t, &Transcoder::finished);
        QVERIFY(t.start(m_wav, out, p));
        t.cancel();
        QVERIFY(done.wait(10000));
        QVERIFY(!done.first().at(0).toBool());
        QVERIFY(!t.isRunning());
        QVERIFY(!QFileInfo::exists(out));
    }

    void queueConvertsIntoHistory()
    {
        ConvertQueue queue;
        QCOMPARE(queue.addUrls({ m_wav, QUrl(QStringLiteral("https://example.org/stream.m3u8")) }), 1);
        QCOMPARE(queue.active()->count(), 1);
        QCOMPARE(queue.active()->data(queue.active()->index(0), ConvertJobs::PresetRole).toString(), QStringLiteral("mp3"));
        const QString expected = queue.outputPathFor(m_wav, QStringLiteral("mp3"));
        QVERIFY(expected.endsWith(QStringLiteral("tone (Pulse).mp3")));
        queue.startAll();
        QVERIFY(queue.isRunning());
        QTRY_COMPARE_WITH_TIMEOUT(queue.completed()->count(), 1, 30000);
        QCOMPARE(queue.completed()->data(queue.completed()->index(0), ConvertJobs::StatusRole).toString(), QStringLiteral("done"));
        QVERIFY(QFileInfo(expected).size() > 1000);
        QVERIFY(!queue.isRunning());
        // Never overwrites: the next output gets a new name.
        QVERIFY(queue.outputPathFor(m_wav, QStringLiteral("mp3")).endsWith(QStringLiteral("tone (Pulse) 2.mp3")));
    }

#ifdef PULSE_CONVERT_HELPER
    // The app runs conversions in this helper; pin its protocol and cleanup.
    void helperKeepsFinishedOutput()
    {
        const QString out = m_dir.filePath(QStringLiteral("helper.mp3"));
        QProcess helper;
        helper.start(QStringLiteral(PULSE_CONVERT_HELPER),
                     { QStringLiteral("--input"), m_wav.toString(), QStringLiteral("--output"), out, QStringLiteral("--container"),
                       QStringLiteral("mp3"), QStringLiteral("--video"), QStringLiteral("none"), QStringLiteral("--audio"), QStringLiteral("mp3") });
        QVERIFY(helper.waitForFinished(30000));
        QCOMPARE(helper.exitCode(), 0);
        QVERIFY(helper.readAllStandardOutput().contains("done ok"));
        QVERIFY(QFileInfo(out).size() > 1000);
    }

    void helperRemovesPartialOutputWhenStopped()
    {
        const QString out = m_dir.filePath(QStringLiteral("helper-stopped.mp3"));
        QFile::remove(out);
        QProcess helper;
        helper.start(QStringLiteral(PULSE_CONVERT_HELPER),
                     { QStringLiteral("--input"), m_wav.toString(), QStringLiteral("--output"), out, QStringLiteral("--container"),
                       QStringLiteral("mp3"), QStringLiteral("--video"), QStringLiteral("none"), QStringLiteral("--audio"), QStringLiteral("mp3") });
        QVERIFY(helper.waitForStarted());
        helper.closeWriteChannel(); // what the helper sees when the app goes away
        QVERIFY(helper.waitForFinished(30000));
        QVERIFY(!QFileInfo::exists(out) || helper.readAllStandardOutput().contains("done ok"));
    }

    void queueRunsJobsBackToBackThroughTheHelper()
    {
        qputenv("PULSE_CONVERT_HELPER", PULSE_CONVERT_HELPER);
        const QUrl second = QUrl::fromLocalFile(writeWav(m_dir.filePath(QStringLiteral("second.wav")), 2));
        ConvertQueue queue;
        QCOMPARE(queue.addUrls({ m_wav, second }), 2);
        queue.startAll();
        QTRY_COMPARE_WITH_TIMEOUT(queue.completed()->count(), 2, 60000);
        for (int r = 0; r < 2; ++r) {
            QCOMPARE(queue.completed()->data(queue.completed()->index(r), ConvertJobs::StatusRole).toString(), QStringLiteral("done"));
            QVERIFY(QFileInfo(queue.completed()->data(queue.completed()->index(r), ConvertJobs::OutputRole).toUrl().toLocalFile()).size() > 1000);
        }
        QTRY_VERIFY(!queue.isRunning());
        qunsetenv("PULSE_CONVERT_HELPER");
    }
#endif

private:
    Engine *m_engine = nullptr;
    QTemporaryDir m_dir;
    QUrl m_wav;
};

QTEST_GUILESS_MAIN(EngineTest)
#include "tst_engine.moc"
