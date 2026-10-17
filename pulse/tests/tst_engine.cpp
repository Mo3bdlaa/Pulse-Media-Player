// Engine contract tests: they pin the behaviour Pulse relies on, so an
// upstream libVLC change that breaks it fails CI before it reaches users.

#include "engine/engine.hpp"
#include "engine/player.hpp"

#include <QDataStream>
#include <QFile>
#include <QSignalSpy>
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

private:
    Engine *m_engine = nullptr;
    QTemporaryDir m_dir;
    QUrl m_wav;
};

QTEST_GUILESS_MAIN(EngineTest)
#include "tst_engine.moc"
