#include "convertqueue.hpp"
#include "mediainfo.hpp"
#include "mediainput.hpp"

#include "engine/mediaprobe.hpp"
#include "engine/transcoder.hpp"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QProcess>
#include <QFileInfo>
#include <QSettings>
#include <QStandardPaths>

namespace pulse {

namespace {

struct Preset
{
    const char *id;
    const char *icon;
    const char *name;
    const char *detail;
    const char *container; // "" = from settings (custom)
    const char *video;
    const char *audio;
    int height;
};

const Preset kPresets[] = {
    { "mp4", "play", QT_TRANSLATE_NOOP("ConvertQueue", "MP4 (H.264)"), QT_TRANSLATE_NOOP("ConvertQueue", "Best compatibility"), "mp4", "h264", "aac", 0 },
    { "mkv", "play", QT_TRANSLATE_NOOP("ConvertQueue", "MKV (H.265)"), QT_TRANSLATE_NOOP("ConvertQueue", "High quality"), "mkv", "hevc", "aac", 0 },
    { "web", "globe", QT_TRANSLATE_NOOP("ConvertQueue", "Web (1080p)"), QT_TRANSLATE_NOOP("ConvertQueue", "For streaming"), "mp4", "h264", "aac", 1080 },
    { "mobile", "phone", QT_TRANSLATE_NOOP("ConvertQueue", "Mobile (720p)"), QT_TRANSLATE_NOOP("ConvertQueue", "For mobile devices"), "mp4", "h264", "aac", 720 },
    { "mp3", "music", QT_TRANSLATE_NOOP("ConvertQueue", "Audio (MP3)"), QT_TRANSLATE_NOOP("ConvertQueue", "Extract audio"), "mp3", "none", "mp3", 0 },
    { "custom", "settings", QT_TRANSLATE_NOOP("ConvertQueue", "Custom"), QT_TRANSLATE_NOOP("ConvertQueue", "Your settings below"), "", "", "", 0 },
};

// The helper ships next to the app on desktop; without it, convert in process.
QString helperPath()
{
#if defined(Q_OS_ANDROID) || defined(Q_OS_IOS)
    return {};
#else
    // PULSE_CONVERT_HELPER points elsewhere (tests, unusual package layouts).
    const QString custom = qEnvironmentVariable("PULSE_CONVERT_HELPER");
    if (!custom.isEmpty())
        return QFileInfo::exists(custom) ? custom : QString();
    const QString path = QCoreApplication::applicationDirPath() + QStringLiteral("/pulse-convert")
#if defined(Q_OS_WIN)
        + QStringLiteral(".exe")
#endif
        ;
    return QFileInfo::exists(path) ? path : QString();
#endif
}

const Preset *presetFor(const QString &id)
{
    for (const Preset &p : kPresets)
        if (id == QLatin1String(p.id))
            return &p;
    return &kPresets[0];
}

// Video bitrate (kb/s) for a target height at "high"; medium and low scale it down.
int videoKbps(int height, const QString &quality)
{
    const int base = height >= 2000 ? 20000 : height >= 1000 ? 8000 : height >= 700 ? 5000 : 2500;
    const double scale = quality == QLatin1String("low") ? 0.35 : quality == QLatin1String("medium") ? 0.6 : 1.0;
    return int(base * scale);
}

QString etaText(qint64 secs)
{
    if (secs < 0)
        return {};
    if (secs < 60)
        return ConvertQueue::tr("less than a minute");
    const qint64 mins = (secs + 30) / 60;
    if (mins < 60)
        return mins == 1 ? ConvertQueue::tr("1 minute") : ConvertQueue::tr("%1 minutes").arg(mins);
    return ConvertQueue::tr("%1 h %2 min").arg(mins / 60).arg(mins % 60);
}

QString detailFor(const ConvertJobs::Job &job)
{
    QStringList parts;
    const qint64 ms = job.info.value(QStringLiteral("durationMs")).toLongLong();
    if (ms > 0)
        parts << MediaInput::formatTime(ms);
    if (job.url.isLocalFile())
        parts << MediaInput::formatSize(QFileInfo(job.url.toLocalFile()).size());
    const QString q = qualityLabel(job.info.value(QStringLiteral("width")).toInt(), job.info.value(QStringLiteral("height")).toInt());
    QString codec = job.info.value(QStringLiteral("videoCodec")).toString();
    if (codec.isEmpty())
        codec = job.info.value(QStringLiteral("audioCodec")).toString();
    codec = codec.section(QLatin1Char(' '), 0, 0).section(QLatin1Char('/'), 0, 0);
    if (!q.isEmpty())
        parts << (codec.isEmpty() ? q : QStringLiteral("%1 (%2)").arg(q, codec));
    else if (!codec.isEmpty())
        parts << codec;
    return parts.join(QStringLiteral(" · "));
}

} // namespace

// ----------------------------------------------------------------- ConvertJobs

int ConvertJobs::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : int(jobs.size());
}

QVariant ConvertJobs::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= jobs.size())
        return {};
    const Job &j = jobs[index.row()];
    switch (role) {
    case IdRole: return j.id;
    case UrlRole: return j.url;
    case Qt::DisplayRole:
    case NameRole: return MediaInput::displayName(j.url);
    case DetailRole: return detailFor(j);
    case PresetRole: return j.preset;
    case ResolutionRole: return j.resolution;
    case StatusRole: return j.status;
    case ProgressRole: return j.progress;
    case EtaRole: return etaText(j.etaSecs);
    case ErrorRole: return j.error;
    case OutputRole: return j.output.isEmpty() ? QUrl() : QUrl::fromLocalFile(j.output);
    case FinishedRole: return j.finished;
    }
    return {};
}

QHash<int, QByteArray> ConvertJobs::roleNames() const
{
    return {
        { IdRole, "jobId" }, { UrlRole, "url" }, { NameRole, "name" }, { DetailRole, "detail" },
        { PresetRole, "preset" }, { ResolutionRole, "resolution" }, { StatusRole, "status" },
        { ProgressRole, "progress" }, { EtaRole, "eta" }, { ErrorRole, "error" }, { OutputRole, "output" },
        { FinishedRole, "finished" },
    };
}

void ConvertJobs::append(const Job &job)
{
    beginInsertRows({}, int(jobs.size()), int(jobs.size()));
    jobs << job;
    endInsertRows();
    emit countChanged();
}

void ConvertJobs::prepend(const Job &job)
{
    beginInsertRows({}, 0, 0);
    jobs.prepend(job);
    endInsertRows();
    emit countChanged();
}

ConvertJobs::Job ConvertJobs::take(int row)
{
    beginRemoveRows({}, row, row);
    Job j = jobs.takeAt(row);
    endRemoveRows();
    emit countChanged();
    return j;
}

void ConvertJobs::touch(int row)
{
    emit dataChanged(index(row), index(row));
}

int ConvertJobs::rowOf(int id) const
{
    for (int i = 0; i < jobs.size(); ++i)
        if (jobs[i].id == id)
            return i;
    return -1;
}

// ----------------------------------------------------------------- ConvertQueue

ConvertQueue::ConvertQueue(QObject *parent)
    : QObject(parent)
    , m_active(new ConvertJobs(this))
    , m_completed(new ConvertJobs(this))
    , m_probe(new MediaProbe(this))
    , m_transcoder(new Transcoder(this))
{
    QSettings s;
    s.beginGroup(QStringLiteral("convert"));
    m_preset = s.value(QStringLiteral("preset"), m_preset).toString();
    m_videoCodec = s.value(QStringLiteral("videoCodec"), m_videoCodec).toString();
    m_audioCodec = s.value(QStringLiteral("audioCodec"), m_audioCodec).toString();
    m_quality = s.value(QStringLiteral("quality"), m_quality).toString();
    m_keepAudio = s.value(QStringLiteral("keepOriginalAudio"), m_keepAudio).toBool();
    m_hw = s.value(QStringLiteral("hardwareDecoding"), m_hw).toBool();
    m_trash = s.value(QStringLiteral("trashSource"), m_trash).toBool();

    connect(m_probe, &MediaProbe::probed, this, &ConvertQueue::applyProbe);
    connect(m_transcoder, &Transcoder::progress, this, &ConvertQueue::onProgress);
    connect(m_transcoder, &Transcoder::finished, this, &ConvertQueue::onFinished);
}

ConvertQueue::~ConvertQueue()
{
    // Quitting mid-job: stop the helper and leave no partial file behind.
    if (m_helper) {
        m_helper->disconnect(this);
        cancelCurrent();
        if (!m_helper->waitForFinished(3000))
            m_helper->kill();
        const int row = m_active->rowOf(m_currentId);
        if (row >= 0)
            QFile::remove(m_active->jobs[row].output);
    }
}

QVariantList ConvertQueue::presets() const
{
    QVariantList out;
    for (const Preset &p : kPresets)
        out << QVariantMap{ { QStringLiteral("id"), QString::fromLatin1(p.id) },
                            { QStringLiteral("icon"), QString::fromLatin1(p.icon) },
                            { QStringLiteral("name"), tr(p.name) },
                            { QStringLiteral("detail"), tr(p.detail) } };
    return out;
}

QVariantList ConvertQueue::resolutions() const
{
    return {
        QVariantMap{ { QStringLiteral("height"), 0 }, { QStringLiteral("name"), tr("Original") } },
        QVariantMap{ { QStringLiteral("height"), 2160 }, { QStringLiteral("name"), QStringLiteral("4K") } },
        QVariantMap{ { QStringLiteral("height"), 1080 }, { QStringLiteral("name"), QStringLiteral("1080p") } },
        QVariantMap{ { QStringLiteral("height"), 720 }, { QStringLiteral("name"), QStringLiteral("720p") } },
        QVariantMap{ { QStringLiteral("height"), 480 }, { QStringLiteral("name"), QStringLiteral("480p") } },
    };
}

QString ConvertQueue::presetName(const QString &id)
{
    return tr(presetFor(id)->name);
}

void ConvertQueue::store(const char *key, const QVariant &value)
{
    QSettings s;
    s.setValue(QStringLiteral("convert/") + QLatin1String(key), value);
    emit settingsChanged();
}

void ConvertQueue::setPreset(const QString &v) { if (m_preset != v) { m_preset = v; store("preset", v); } }
void ConvertQueue::setVideoCodec(const QString &v) { if (m_videoCodec != v) { m_videoCodec = v; store("videoCodec", v); } }
void ConvertQueue::setAudioCodec(const QString &v) { if (m_audioCodec != v) { m_audioCodec = v; store("audioCodec", v); } }
void ConvertQueue::setQuality(const QString &v) { if (m_quality != v) { m_quality = v; store("quality", v); } }
void ConvertQueue::setKeepOriginalAudio(bool v) { if (m_keepAudio != v) { m_keepAudio = v; store("keepOriginalAudio", v); } }
void ConvertQueue::setHardwareDecoding(bool v) { if (m_hw != v) { m_hw = v; store("hardwareDecoding", v); } }
void ConvertQueue::setTrashSource(bool v) { if (m_trash != v) { m_trash = v; store("trashSource", v); } }

int ConvertQueue::addUrls(const QList<QUrl> &urls)
{
    int added = 0;
    for (const QUrl &u : MediaInput::expand(urls)) {
        if (!u.isLocalFile() || !QFileInfo::exists(u.toLocalFile()))
            continue;
        ConvertJobs::Job j;
        j.id = m_nextId++;
        j.url = u;
        // Audio files can only become audio.
        j.preset = MediaInput::isAudio(u) ? QStringLiteral("mp3") : m_preset;
        j.resolution = presetFor(j.preset)->height;
        m_active->append(j);
        m_probe->probe(u);
        ++added;
    }
    return added;
}

void ConvertQueue::applyProbe(const QUrl &url, const QVariantMap &info)
{
    for (auto *model : { m_active, m_completed })
        for (int r = 0; r < model->jobs.size(); ++r)
            if (model->jobs[r].url == url) {
                model->jobs[r].info = info;
                model->touch(r);
            }
}

void ConvertQueue::setJobPreset(int row, const QString &preset)
{
    if (row < 0 || row >= m_active->jobs.size() || m_active->jobs[row].status != QLatin1String("queued"))
        return;
    auto &j = m_active->jobs[row];
    j.preset = presetFor(preset)->id;
    j.resolution = presetFor(preset)->height;
    m_active->touch(row);
}

void ConvertQueue::setJobResolution(int row, int height)
{
    if (row < 0 || row >= m_active->jobs.size() || m_active->jobs[row].status != QLatin1String("queued"))
        return;
    m_active->jobs[row].resolution = height;
    m_active->touch(row);
}

void ConvertQueue::removeJob(int row)
{
    if (row < 0 || row >= m_active->jobs.size())
        return;
    if (m_active->jobs[row].id == m_currentId) {
        m_cancelling = true;
        cancelCurrent(); // onFinished moves it to history
        return;
    }
    m_active->take(row);
}

void ConvertQueue::clearActive()
{
    for (int r = m_active->jobs.size() - 1; r >= 0; --r)
        if (m_active->jobs[r].id != m_currentId)
            m_active->take(r);
    if (m_currentId) {
        m_cancelling = true;
        cancelCurrent();
    }
    if (m_running) {
        m_running = false;
        emit runningChanged();
    }
}

void ConvertQueue::startAll()
{
    if (m_running)
        return;
    m_running = true;
    emit runningChanged();
    runNext();
}

QString ConvertQueue::outputPathFor(const QUrl &url, const QString &preset) const
{
    const Preset *p = presetFor(preset);
    QString ext = QString::fromLatin1(p->container);
    if (ext.isEmpty())
        ext = m_videoCodec == QLatin1String("hevc") ? QStringLiteral("mkv") : QStringLiteral("mp4");
    const QFileInfo src(url.toLocalFile());
    QString dir = src.absolutePath();
    if (!QFileInfo(dir).isWritable())
        dir = QStandardPaths::writableLocation(ext == QLatin1String("mp3") ? QStandardPaths::MusicLocation
                                                                           : QStandardPaths::MoviesLocation);
    const QString base = src.completeBaseName() + QStringLiteral(" (Pulse)");
    QString path = QDir(dir).filePath(base + QLatin1Char('.') + ext);
    for (int n = 2; QFileInfo::exists(path); ++n)
        path = QDir(dir).filePath(QStringLiteral("%1 %2.%3").arg(base).arg(n).arg(ext));
    return path;
}

void ConvertQueue::runNext()
{
    if (!m_running || m_currentId)
        return;
    int row = -1;
    for (int r = 0; r < m_active->jobs.size(); ++r)
        if (m_active->jobs[r].status == QLatin1String("queued")) {
            row = r;
            break;
        }
    if (row < 0) {
        m_running = false;
        emit runningChanged();
        return;
    }
    auto &j = m_active->jobs[row];
    const Preset *p = presetFor(j.preset);
    TranscodeProfile profile;
    profile.container = QString::fromLatin1(p->container);
    profile.videoCodec = QString::fromLatin1(p->video);
    profile.audioCodec = QString::fromLatin1(p->audio);
    if (profile.container.isEmpty()) {
        profile.videoCodec = m_videoCodec;
        profile.audioCodec = m_audioCodec;
        profile.container = m_videoCodec == QLatin1String("hevc") ? QStringLiteral("mkv") : QStringLiteral("mp4");
    }
    // Audio already in the target codec is copied: no quality loss, faster,
    // and it sidesteps a core transcoder fault (VLC 4.0-dev, pcr_sync.c) that
    // can hit when audio and video are both re-encoded.
    const QString srcAudio = j.info.value(QStringLiteral("audioFourcc")).toString();
    const bool sameAudio = (profile.audioCodec == QLatin1String("aac") && srcAudio == QLatin1String("mp4a"))
                        || (profile.audioCodec == QLatin1String("mp3") && srcAudio == QLatin1String("mpga"));
    if ((m_keepAudio || sameAudio) && profile.container != QLatin1String("mp3"))
        profile.audioCodec = QStringLiteral("copy");
    // Never upscale; an explicit height keeps the encoder's frame size exact.
    const int source = j.info.value(QStringLiteral("height")).toInt();
    int height = j.resolution > 0 ? j.resolution : source;
    if (source > 0 && height > source)
        height = source;
    profile.maxHeight = height & ~1;
    profile.videoKbps = videoKbps(height > 0 ? height : 1080, m_quality);
    profile.audioKbps = m_quality == QLatin1String("low") ? 128 : m_quality == QLatin1String("medium") ? 160 : 192;
    profile.hardwareDecoding = m_hw;

    j.output = outputPathFor(j.url, j.preset);
    j.status = QStringLiteral("converting");
    j.progress = 0;
    j.etaSecs = -1;
    j.clock.start();
    m_currentId = j.id;
    m_active->touch(row);
    const bool started = helperPath().isEmpty() ? m_transcoder->start(j.url, j.output, profile)
                                                : startHelper(j.url, j.output, profile);
    if (!started)
        onFinished(false, tr("This file could not be converted."));
}

bool ConvertQueue::startHelper(const QUrl &input, const QString &output, const TranscodeProfile &p)
{
    QStringList args{
        QStringLiteral("--input"), input.toString(QUrl::FullyEncoded), QStringLiteral("--output"), output,
        QStringLiteral("--container"), p.container, QStringLiteral("--video"), p.videoCodec,
        QStringLiteral("--audio"), p.audioCodec, QStringLiteral("--height"), QString::number(p.maxHeight),
        QStringLiteral("--video-kbps"), QString::number(p.videoKbps),
        QStringLiteral("--audio-kbps"), QString::number(p.audioKbps),
    };
    if (!p.hardwareDecoding)
        args << QStringLiteral("--no-hw");
    // Each handler works on its own process: the next job's helper may
    // already be running when the previous one finally exits.
    auto *proc = new QProcess(this);
    m_helper = proc;
    proc->setProcessChannelMode(QProcess::SeparateChannels);
    proc->setStandardErrorFile(QProcess::nullDevice());
    connect(proc, &QProcess::readyReadStandardOutput, this, [this, proc] { readHelper(proc); });
    connect(proc, &QProcess::finished, this, [this, proc, output](int, QProcess::ExitStatus) {
        readHelper(proc);
        const bool reported = proc->property("reported").toBool();
        if (m_helper == proc)
            m_helper = nullptr;
        proc->deleteLater();
        if (!reported) {
            QFile::remove(output); // the helper stopped without finishing the file
            onFinished(false, m_keepAudio ? tr("The converter stopped unexpectedly.")
                                          : tr("The converter stopped unexpectedly. Try again with “Keep Original Audio”."));
        }
    });
    proc->start(helperPath(), args);
    return proc->waitForStarted(5000);
}

void ConvertQueue::readHelper(QProcess *proc)
{
    while (proc->canReadLine()) {
        const QString line = QString::fromUtf8(proc->readLine()).trimmed();
        if (proc->property("reported").toBool())
            continue;
        if (line.startsWith(QLatin1String("progress "))) {
            onProgress(line.section(QLatin1Char(' '), 1, 1).toDouble(), line.section(QLatin1Char(' '), 2, 2).toLongLong());
        } else if (line.startsWith(QLatin1String("done "))) {
            proc->setProperty("reported", true);
            if (m_helper == proc)
                m_helper = nullptr; // finished; the next job may start now
            const bool ok = line == QLatin1String("done ok");
            onFinished(ok, ok ? QString() : line.section(QLatin1Char(' '), 2));
        }
    }
}

void ConvertQueue::cancelCurrent()
{
    if (!m_helper) {
        m_transcoder->cancel();
        return;
    }
    // The helper removes its partial file on SIGTERM; Windows has no
    // SIGTERM for console programs, so the finished() handler removes it.
#if defined(Q_OS_WIN)
    m_helper->kill();
#else
    m_helper->terminate();
#endif
}

void ConvertQueue::onProgress(double position, qint64)
{
    const int row = m_active->rowOf(m_currentId);
    if (row < 0)
        return;
    auto &j = m_active->jobs[row];
    j.progress = qBound(0.0, position, 1.0);
    const qint64 elapsed = j.clock.elapsed();
    if (j.progress > 0.02 && elapsed > 2000)
        j.etaSecs = qint64(elapsed * (1.0 - j.progress) / j.progress / 1000.0);
    m_active->touch(row);
}

void ConvertQueue::onFinished(bool ok, const QString &error)
{
    const int row = m_active->rowOf(m_currentId);
    m_currentId = 0;
    const bool wasCancelled = m_cancelling;
    m_cancelling = false;
    if (row >= 0) {
        ConvertJobs::Job j = m_active->take(row);
        const bool cancelled = !ok && wasCancelled;
        j.status = ok ? QStringLiteral("done") : cancelled ? QStringLiteral("cancelled") : QStringLiteral("failed");
        j.progress = ok ? 1.0 : j.progress;
        j.etaSecs = -1;
        j.error = ok ? QString() : error;
        j.finished = QDateTime::currentDateTime();
        if (ok && m_trash && QFileInfo(j.output).size() > 0)
            QFile::moveToTrash(j.url.toLocalFile());
        if (!ok)
            j.output.clear();
        m_completed->prepend(j);
        if (!cancelled)
            emit jobFinished(MediaInput::displayName(j.url), ok, j.error);
    }
    runNext();
}

void ConvertQueue::retry(int completedRow)
{
    if (completedRow < 0 || completedRow >= m_completed->jobs.size())
        return;
    ConvertJobs::Job j = m_completed->take(completedRow);
    j.status = QStringLiteral("queued");
    j.progress = 0;
    j.error.clear();
    j.output.clear();
    j.id = m_nextId++;
    m_active->append(j);
}

void ConvertQueue::removeCompleted(int row)
{
    if (row >= 0 && row < m_completed->jobs.size())
        m_completed->take(row);
}

void ConvertQueue::clearCompleted()
{
    while (!m_completed->jobs.isEmpty())
        m_completed->take(0);
}

} // namespace pulse
