#include "mediainput.hpp"

#include <QCollator>
#include <QDir>
#include <QDirIterator>
#include <QLocale>
#include <QFileInfo>
#include <QSet>
#include <QStandardPaths>
#include <algorithm>

namespace pulse {

namespace {

const QSet<QString> &videoExtensions()
{
    static const QSet<QString> s = {
        "3g2", "3gp", "asf", "avi", "divx", "dv", "f4v", "flv", "m2t", "m2ts", "m2v", "m4v",
        "mkv", "mov", "mp2", "mp4", "mpeg", "mpg", "mts", "mxf", "ogm", "ogv", "rm", "rmvb",
        "ts", "vob", "webm", "wmv", "y4m",
    };
    return s;
}

const QSet<QString> &audioExtensions()
{
    static const QSet<QString> s = {
        "aac", "ac3", "aif", "aiff", "alac", "amr", "ape", "au", "dts", "flac", "it", "m4a",
        "m4b", "mid", "mka", "mod", "mp1", "mp2", "mp3", "mpc", "oga", "ogg", "opus", "ra",
        "s3m", "spx", "tta", "voc", "wav", "wma", "wv", "xm",
    };
    return s;
}

const QSet<QString> &subtitleExtensions()
{
    static const QSet<QString> s = { "ass", "idx", "srt", "ssa", "sub", "sup", "ttml", "vtt" };
    return s;
}

QString suffix(const QUrl &url)
{
    return QFileInfo(url.path()).suffix().toLower();
}

} // namespace

MediaInput::MediaInput(QObject *parent)
    : QObject(parent)
{
}

QUrl MediaInput::fromUserInput(const QString &text)
{
    const QString t = text.trimmed();
    if (t.isEmpty())
        return {};
    const QFileInfo fi(t);
    if (fi.exists())
        return QUrl::fromLocalFile(fi.absoluteFilePath());
    return QUrl::fromUserInput(t, QDir::currentPath(), QUrl::AssumeLocalFile);
}

QList<QUrl> MediaInput::expandFolder(const QUrl &folder)
{
    QList<QUrl> out;
    if (!folder.isLocalFile())
        return out;
    QStringList files;
    QDirIterator it(folder.toLocalFile(), QDir::Files | QDir::Readable, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        const QString path = it.next();
        const QString ext = QFileInfo(path).suffix().toLower();
        if (videoExtensions().contains(ext) || audioExtensions().contains(ext))
            files << path;
    }
    QCollator collator;
    collator.setNumericMode(true);
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    std::sort(files.begin(), files.end(), collator);
    for (const QString &f : files)
        out << QUrl::fromLocalFile(f);
    return out;
}

QList<QUrl> MediaInput::expand(const QList<QUrl> &urls)
{
    QList<QUrl> out;
    for (const QUrl &url : urls) {
        if (url.isLocalFile() && QFileInfo(url.toLocalFile()).isDir())
            out << expandFolder(url);
        else if (!isSubtitle(url))
            out << url;
    }
    return out;
}

bool MediaInput::isSubtitle(const QUrl &url)
{
    return subtitleExtensions().contains(suffix(url));
}

bool MediaInput::isAudio(const QUrl &url)
{
    return audioExtensions().contains(suffix(url));
}

bool MediaInput::isMedia(const QUrl &url)
{
    const QString ext = suffix(url);
    return videoExtensions().contains(ext) || audioExtensions().contains(ext);
}

bool MediaInput::exists(const QUrl &url)
{
    return !url.isLocalFile() || QFileInfo::exists(url.toLocalFile());
}

QString MediaInput::displayName(const QUrl &url)
{
    if (url.isLocalFile())
        return QFileInfo(url.toLocalFile()).fileName();
    const QString name = url.fileName();
    return name.isEmpty() ? url.toDisplayString(QUrl::RemoveUserInfo) : name;
}

QString MediaInput::describe(const QUrl &url)
{
    if (url.isLocalFile()) {
        const QFileInfo fi(url.toLocalFile());
        if (!fi.exists())
            return tr("File not found");
        return QStringLiteral("%1 · %2").arg(fi.suffix().toUpper(), formatSize(fi.size()));
    }
    return QStringLiteral("%1 · %2").arg(url.scheme().toUpper(), tr("Stream"));
}

QString MediaInput::formatTime(qint64 ms)
{
    if (ms < 0)
        ms = 0;
    const qint64 total = ms / 1000;
    const qint64 h = total / 3600, m = (total / 60) % 60, s = total % 60;
    if (h > 0)
        return QStringLiteral("%1:%2:%3").arg(h).arg(m, 2, 10, QLatin1Char('0')).arg(s, 2, 10, QLatin1Char('0'));
    return QStringLiteral("%1:%2").arg(m).arg(s, 2, 10, QLatin1Char('0'));
}

QString MediaInput::formatSize(qint64 bytes)
{
    const double b = double(bytes);
    if (b >= 1e9)
        return QStringLiteral("%1 GB").arg(b / 1e9, 0, 'f', 1);
    if (b >= 1e6)
        return QStringLiteral("%1 MB").arg(b / 1e6, 0, 'f', 0);
    if (b >= 1e3)
        return QStringLiteral("%1 KB").arg(b / 1e3, 0, 'f', 0);
    return QStringLiteral("%1 B").arg(bytes);
}

QString MediaInput::scheme(const QUrl &url)
{
    return url.scheme();
}

QString MediaInput::picturesFolder()
{
    return QStandardPaths::writableLocation(QStandardPaths::PicturesLocation);
}

QString MediaInput::relativeTime(const QDateTime &when)
{
    if (!when.isValid())
        return {};
    const qint64 secs = when.secsTo(QDateTime::currentDateTime());
    if (secs < 60)
        return tr("just now");
    if (secs < 3600) {
        const int m = int(secs / 60);
        return m == 1 ? tr("1 minute ago") : tr("%1 minutes ago").arg(m);
    }
    if (secs < 86400) {
        const int h = int(secs / 3600);
        return h == 1 ? tr("1 hour ago") : tr("%1 hours ago").arg(h);
    }
    const qint64 days = when.date().daysTo(QDate::currentDate());
    if (days == 1)
        return tr("Yesterday");
    if (days < 7)
        return tr("%1 days ago").arg(days);
    return QLocale().toString(when.date(), QLocale::ShortFormat);
}

void MediaInput::clearThumbnailCache()
{
    QDir(QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/thumbs")).removeRecursively();
}

QStringList MediaInput::mediaArguments(const QStringList &args)
{
    QStringList out;
    for (int i = 1; i < args.size(); ++i)
        if (!args[i].startsWith(QLatin1Char('-')))
            out << args[i];
    return out;
}

} // namespace pulse
