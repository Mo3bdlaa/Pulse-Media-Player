#include "mediainfo.hpp"

#include <QFileInfo>
#include <QRegularExpression>

namespace pulse {

ParsedName parseFileName(const QString &fileName)
{
    ParsedName out;
    QString s = QFileInfo(fileName).completeBaseName();

    static const QRegularExpression episode(QStringLiteral("\\b[Ss](\\d{1,2})[ ._-]?[Ee](\\d{1,3})\\b|\\b(\\d{1,2})x(\\d{2})\\b"));
    static const QRegularExpression year(QStringLiteral("[\\[(]?\\b((?:19|20)\\d{2})\\b[\\])]?"));
    static const QRegularExpression junk(QStringLiteral(
        "\\b(2160p|1080p|720p|480p|4k|uhd|hdr10?|dv|web[- ]?dl|webrip|bluray|brrip|bdrip|dvdrip|hdtv|remux|"
        "x26[45]|h\\.?26[45]|hevc|avc|aac|ac3|dts|atmos|10bit|proper|repack|extended|unrated)\\b.*$"),
        QRegularExpression::CaseInsensitiveOption);

    if (!s.contains(QLatin1Char(' ')))
        s.replace(QLatin1Char('.'), QLatin1Char(' '));
    s.replace(QLatin1Char('_'), QLatin1Char(' '));

    if (const auto m = episode.match(s); m.hasMatch()) {
        out.season = (m.captured(1).isEmpty() ? m.captured(3) : m.captured(1)).toInt();
        out.episode = (m.captured(2).isEmpty() ? m.captured(4) : m.captured(2)).toInt();
        s = s.left(m.capturedStart());
    }
    // The last plausible year wins: "Blade Runner 2049 (2017)" keeps 2049 in the title.
    QRegularExpressionMatch last;
    for (auto it = year.globalMatch(s); it.hasNext();) {
        const auto m = it.next();
        if (m.capturedStart() > 0)
            last = m;
    }
    if (last.hasMatch()) {
        out.year = last.captured(1).toInt();
        s = s.left(last.capturedStart());
    }
    s.remove(junk);
    out.title = s.simplified();
    while (out.title.endsWith(QLatin1Char('-')) || out.title.endsWith(QLatin1Char('(')))
        out.title = out.title.chopped(1).trimmed();
    if (out.title.isEmpty())
        out.title = QFileInfo(fileName).completeBaseName();
    return out;
}

QString qualityLabel(int width, int height)
{
    if (width <= 0 || height <= 0)
        return {};
    if (width >= 3200 || height >= 2000)
        return QStringLiteral("4K");
    if (width >= 1800 || height >= 1000)
        return QStringLiteral("1080p");
    if (width >= 1200 || height >= 700)
        return QStringLiteral("720p");
    return QStringLiteral("SD");
}

QString shortDuration(qint64 ms)
{
    if (ms <= 0)
        return {};
    const qint64 mins = (ms + 30000) / 60000;
    if (ms < 60000)
        return QStringLiteral("0:%1").arg(ms / 1000, 2, 10, QLatin1Char('0'));
    if (mins < 60)
        return QStringLiteral("%1m").arg(mins);
    return QStringLiteral("%1h %2m").arg(mins / 60).arg(mins % 60);
}

} // namespace pulse
