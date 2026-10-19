// Pulse — Convert & Export (11): presets, a job queue and its history.
//
// Jobs run one at a time. On desktop each runs in the pulse-convert helper
// process, so a fault in an encoder fails that job instead of the player;
// elsewhere the engine's Transcoder runs in process. Output goes next to
// the source as "<name> (Pulse).<ext>" and never overwrites an existing file.
#pragma once

#include <QAbstractListModel>
#include <QDateTime>
#include <QElapsedTimer>
#include <QUrl>
#include <QVariantList>
#include <QVector>

class QProcess;

namespace pulse {

class MediaProbe;
class Transcoder;
struct TranscodeProfile;

class ConvertJobs : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum Role {
        IdRole = Qt::UserRole + 1, UrlRole, NameRole, DetailRole, PresetRole, ResolutionRole, StatusRole,
        ProgressRole, EtaRole, ErrorRole, OutputRole, FinishedRole
    };

    struct Job
    {
        int id = 0;
        QUrl url;
        QString preset;
        int resolution = 0; ///< target height; 0 keeps the source
        QString status = QStringLiteral("queued"); ///< queued, converting, done, failed, cancelled
        double progress = 0;
        qint64 etaSecs = -1;
        QString error;
        QString output;
        QDateTime finished;
        QVariantMap info; ///< from MediaProbe
        QVariantMap edit; ///< Edit & Export: startMs, endMs, crop [x,y,w,h], transform, noAudio, sourceWidth, sourceHeight
        QElapsedTimer clock;
    };

    using QAbstractListModel::QAbstractListModel;
    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;
    int count() const { return int(jobs.size()); }

    void append(const Job &job);
    void prepend(const Job &job);
    Job take(int row);
    void touch(int row);
    int rowOf(int id) const;

    QVector<Job> jobs;

signals:
    void countChanged();
};

class ConvertQueue : public QObject
{
    Q_OBJECT
    Q_PROPERTY(ConvertJobs *active READ active CONSTANT)
    Q_PROPERTY(ConvertJobs *completed READ completed CONSTANT)
    Q_PROPERTY(bool running READ isRunning NOTIFY runningChanged)
    Q_PROPERTY(QVariantList presets READ presets CONSTANT)
    Q_PROPERTY(QVariantList resolutions READ resolutions CONSTANT)
    Q_PROPERTY(QString preset READ preset WRITE setPreset NOTIFY settingsChanged)
    Q_PROPERTY(QString videoCodec READ videoCodec WRITE setVideoCodec NOTIFY settingsChanged)
    Q_PROPERTY(QString audioCodec READ audioCodec WRITE setAudioCodec NOTIFY settingsChanged)
    Q_PROPERTY(QString quality READ quality WRITE setQuality NOTIFY settingsChanged)
    Q_PROPERTY(bool keepOriginalAudio READ keepOriginalAudio WRITE setKeepOriginalAudio NOTIFY settingsChanged)
    Q_PROPERTY(bool hardwareDecoding READ hardwareDecoding WRITE setHardwareDecoding NOTIFY settingsChanged)
    Q_PROPERTY(bool trashSource READ trashSource WRITE setTrashSource NOTIFY settingsChanged)

public:
    explicit ConvertQueue(QObject *parent = nullptr);
    ~ConvertQueue() override;

    ConvertJobs *active() const { return m_active; }
    ConvertJobs *completed() const { return m_completed; }
    bool isRunning() const { return m_running; }
    QVariantList presets() const;
    QVariantList resolutions() const;

    QString preset() const { return m_preset; }
    void setPreset(const QString &v);
    QString videoCodec() const { return m_videoCodec; }
    void setVideoCodec(const QString &v);
    QString audioCodec() const { return m_audioCodec; }
    void setAudioCodec(const QString &v);
    QString quality() const { return m_quality; }
    void setQuality(const QString &v);
    bool keepOriginalAudio() const { return m_keepAudio; }
    void setKeepOriginalAudio(bool v);
    bool hardwareDecoding() const { return m_hw; }
    void setHardwareDecoding(bool v);
    bool trashSource() const { return m_trash; }
    void setTrashSource(bool v);

    /// Queues local media files with the selected preset; returns how many were added.
    Q_INVOKABLE int addUrls(const QList<QUrl> &urls);
    /// Queues an edited copy of `url` (see Job::edit) and starts the queue.
    Q_INVOKABLE void addEdit(const QUrl &url, const QVariantMap &edit, const QString &preset);
    Q_INVOKABLE void setJobPreset(int row, const QString &preset);
    Q_INVOKABLE void setJobResolution(int row, int height);
    Q_INVOKABLE void removeJob(int row);
    Q_INVOKABLE void clearActive();
    Q_INVOKABLE void startAll();
    Q_INVOKABLE void retry(int completedRow);
    Q_INVOKABLE void removeCompleted(int row);
    Q_INVOKABLE void clearCompleted();
    Q_INVOKABLE static QString presetName(const QString &id);
    /// The output path for `url` with `preset`, without creating it.
    Q_INVOKABLE QString outputPathFor(const QUrl &url, const QString &preset, bool edited = false) const;

signals:
    void runningChanged();
    void settingsChanged();
    void jobFinished(const QString &name, bool ok, const QString &error);

private:
    void runNext();
    bool startHelper(const QUrl &input, const QString &output, const TranscodeProfile &profile);
    void cancelCurrent();
    void readHelper(QProcess *proc);
    void onProgress(double position, qint64 lengthMs);
    void onFinished(bool ok, const QString &error);
    void applyProbe(const QUrl &url, const QVariantMap &info);
    void store(const char *key, const QVariant &value);

    ConvertJobs *m_active;
    ConvertJobs *m_completed;
    MediaProbe *m_probe;
    Transcoder *m_transcoder;
    QProcess *m_helper = nullptr; ///< helper running the current job
    int m_nextId = 1;
    int m_currentId = 0;
    bool m_cancelling = false;
    bool m_running = false;

    QString m_preset = QStringLiteral("mp4");
    QString m_videoCodec = QStringLiteral("h264");
    QString m_audioCodec = QStringLiteral("aac");
    QString m_quality = QStringLiteral("high");
    bool m_keepAudio = false;
    bool m_hw = true;
    bool m_trash = false;
};

} // namespace pulse
