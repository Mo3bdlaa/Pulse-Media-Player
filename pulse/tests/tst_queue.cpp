#include "app/playqueue.hpp"

#include <QSignalSpy>
#include <QtTest>

using namespace pulse;

class QueueTest : public QObject
{
    Q_OBJECT

    static QList<QUrl> urls(int n)
    {
        QList<QUrl> out;
        for (int i = 0; i < n; ++i)
            out << QUrl(QStringLiteral("https://example.org/%1.mp4").arg(i));
        return out;
    }

private slots:
    void setItemsRequestsPlayback()
    {
        PlayQueue q;
        QSignalSpy play(&q, &PlayQueue::playRequested);
        q.setItems(urls(3), 1);
        QCOMPARE(q.count(), 3);
        QCOMPARE(q.currentIndex(), 1);
        QCOMPARE(play.count(), 1);
        QCOMPARE(play.first().first().toUrl(), urls(3)[1]);
    }

    void advanceStopsAtEndUnlessRepeating()
    {
        PlayQueue q;
        q.setItems(urls(2), 1);
        QVERIFY(!q.advance());
        q.setRepeat(PlayQueue::RepeatAll);
        QVERIFY(q.advance());
        QCOMPARE(q.currentIndex(), 0);
    }

    void repeatOneReplaysCurrent()
    {
        PlayQueue q;
        q.setItems(urls(2), 0);
        q.setRepeat(PlayQueue::RepeatOne);
        QSignalSpy play(&q, &PlayQueue::playRequested);
        QVERIFY(q.advance());
        QCOMPARE(q.currentIndex(), 0);
        QCOMPARE(play.count(), 1);
    }

    void moveKeepsCurrentItem()
    {
        PlayQueue q;
        q.setItems(urls(4), 1);
        q.move(1, 3);
        QCOMPARE(q.currentIndex(), 3);
        q.move(0, 3);
        QCOMPARE(q.currentIndex(), 2);
    }

    void removeAndClearNeverPlay()
    {
        PlayQueue q;
        q.setItems(urls(3), 2);
        QSignalSpy play(&q, &PlayQueue::playRequested);
        q.remove(0);
        QCOMPARE(q.currentIndex(), 1);
        q.clear();
        QCOMPARE(q.count(), 0);
        QCOMPARE(play.count(), 0);
    }
};

QTEST_GUILESS_MAIN(QueueTest)
#include "tst_queue.moc"
