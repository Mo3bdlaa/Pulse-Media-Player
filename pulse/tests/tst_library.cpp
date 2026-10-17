// Library, playlist and file-name tests: no core needed, files are fakes.

#include "app/library.hpp"
#include "app/mediainfo.hpp"
#include "app/playlists.hpp"

#include <QFile>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QtTest>

using namespace pulse;

namespace {
void touchFile(const QString &path)
{
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile f(path);
    f.open(QIODevice::WriteOnly);
    f.write("x");
}
} // namespace

class LibraryTest : public QObject
{
    Q_OBJECT

private slots:
    void parsesFileNames_data()
    {
        QTest::addColumn<QString>("file");
        QTest::addColumn<QString>("title");
        QTest::addColumn<int>("year");
        QTest::addColumn<int>("season");
        QTest::addColumn<int>("episode");
        QTest::newRow("dotted") << "Blade.Runner.2049.2017.2160p.HDR.x265.mkv" << "Blade Runner 2049" << 2017 << 0 << 0;
        QTest::newRow("parens") << "Dune (2024).mkv" << "Dune" << 2024 << 0 << 0;
        QTest::newRow("episode") << "The.Last.of.Us.S01E03.1080p.WEB-DL.mkv" << "The Last of Us" << 0 << 1 << 3;
        QTest::newRow("x-style") << "Show Name 2x05.avi" << "Show Name" << 0 << 2 << 5;
        QTest::newRow("plain") << "Midnight Drive.mp3" << "Midnight Drive" << 0 << 0 << 0;
        QTest::newRow("year only") << "2012.mp4" << "2012" << 0 << 0 << 0;
    }

    void parsesFileNames()
    {
        QFETCH(QString, file);
        const ParsedName n = parseFileName(file);
        QTEST(n.title, "title");
        QTEST(n.year, "year");
        QTEST(n.season, "season");
        QTEST(n.episode, "episode");
    }

    void labels()
    {
        QCOMPARE(qualityLabel(3840, 2160), QStringLiteral("4K"));
        QCOMPARE(qualityLabel(1920, 800), QStringLiteral("1080p"));
        QCOMPARE(qualityLabel(1280, 720), QStringLiteral("720p"));
        QCOMPARE(qualityLabel(0, 0), QString());
        QCOMPARE(shortDuration(9972000), QStringLiteral("2h 46m"));
        QCOMPARE(shortDuration(53 * 60000), QStringLiteral("53m"));
    }

    void classifies()
    {
        QCOMPARE(Library::classify("/m/song.flac", true, 0, 0, {}), QStringLiteral("music"));
        QCOMPARE(Library::classify("/m/x.S01E02.mkv", false, 0, 1, {}), QStringLiteral("tv"));
        QCOMPARE(Library::classify("/media/Movies/x.mkv", false, 0, 0, {}), QStringLiteral("movies"));
        QCOMPARE(Library::classify("/media/x.mkv", false, 2 * 3600 * 1000, 0, {}), QStringLiteral("movies"));
        QCOMPARE(Library::classify("/media/clip.mp4", false, 60000, 0, {}), QStringLiteral("other"));
    }

    void scansFiltersAndPersists()
    {
        QTemporaryDir dir;
        touchFile(dir.filePath("media/Movies/Dune (2024).mkv"));
        touchFile(dir.filePath("media/TV/The.Last.of.Us.S01E03.mkv"));
        touchFile(dir.filePath("media/Music/Midnight Drive.mp3"));
        touchFile(dir.filePath("media/notes.txt"));
        const QString store = dir.filePath("library.json");
        {
            Library lib(store);
            QSignalSpy probes(&lib, &Library::probeRequested);
            lib.addFolder(QUrl::fromLocalFile(dir.filePath("media")));
            QTRY_COMPARE(lib.totalCount(), 3);
            QCOMPARE(lib.counts().value("movies").toInt(), 1);
            QCOMPARE(lib.counts().value("tv").toInt(), 1);
            QCOMPARE(lib.counts().value("music").toInt(), 1);
            QVERIFY(probes.count() >= 3);

            lib.setCategory("music");
            QCOMPARE(lib.count(), 1);
            lib.setCategory("all");
            lib.setSearch("dune");
            QCOMPARE(lib.count(), 1);
            QCOMPARE(lib.data(lib.index(0), Library::TitleRole).toString(), QStringLiteral("Dune"));
            lib.setSearch({});

            const QUrl dune = QUrl::fromLocalFile(dir.filePath("media/Movies/Dune (2024).mkv"));
            lib.applyProbe(dune, { { "durationMs", 9972000 }, { "width", 3840 }, { "height", 2160 } });
            QCOMPARE(lib.item(dune).value("quality").toString(), QStringLiteral("4K"));
            QCOMPARE(lib.item(dune).value("subtitle").toString(), QStringLiteral("2024 · 2h 46m"));
            QCOMPARE(lib.folders().size(), 1);
        }
        {
            Library lib(store); // reloads; the deleted file leaves on rescan
            QCOMPARE(lib.totalCount(), 3);
            QFile::remove(dir.filePath("media/TV/The.Last.of.Us.S01E03.mkv"));
            QSignalSpy content(&lib, &Library::contentChanged);
            lib.rescan();
            QTRY_COMPARE(lib.totalCount(), 2);
            lib.removeFolder(lib.folders().first().toMap().value("path").toString());
            QCOMPARE(lib.totalCount(), 0);
        }
    }

    void playlistsEditAndRoundTripM3u()
    {
        QTemporaryDir dir;
        touchFile(dir.filePath("a.mp4"));
        touchFile(dir.filePath("b.mp3"));
        const QUrl a = QUrl::fromLocalFile(dir.filePath("a.mp4")), b = QUrl::fromLocalFile(dir.filePath("b.mp3"));
        const QString store = dir.filePath("playlists.json");
        QString id;
        {
            Playlists p(store);
            id = p.create("My Movie Night", { a });
            QCOMPARE(p.totalCount(), 1);
            QCOMPARE(p.get(id).value("kind").toString(), QStringLiteral("movies"));
            p.addUrls(id, { b });
            QCOMPARE(p.get(id).value("kind").toString(), QStringLiteral("custom"));
            p.applyProbe(a, { { "durationMs", 60000 } });
            QCOMPARE(p.get(id).value("durationMs").toLongLong(), 60000);
            p.moveItem(id, 1, 0);
            QCOMPARE(p.items(id).first().toMap().value("url").toUrl(), b);
            p.setDescription(id, "Epic stories");
            QVERIFY(p.exportM3u(id, QUrl::fromLocalFile(dir.filePath("out.m3u8"))));
            p.setFilter("music");
            QCOMPARE(p.count(), 0);
            p.setFilter("all");
            p.create("Empty");
            QCOMPARE(p.counts().value("custom").toInt(), 2);
        }
        Playlists p(store);
        QCOMPARE(p.totalCount(), 2);
        QCOMPARE(p.get(id).value("description").toString(), QStringLiteral("Epic stories"));
        const QString imported = p.importM3u(QUrl::fromLocalFile(dir.filePath("out.m3u8")));
        QVERIFY(!imported.isEmpty());
        QCOMPARE(p.get(imported).value("name").toString(), QStringLiteral("My Movie Night"));
        QCOMPARE(p.urls(imported), (QList<QUrl>{ b, a }));
        p.clear(imported);
        QCOMPARE(p.get(imported).value("itemCount").toInt(), 0);
        p.remove(imported);
        QCOMPARE(p.totalCount(), 2);
    }
};

QTEST_GUILESS_MAIN(LibraryTest)
#include "tst_library.moc"
