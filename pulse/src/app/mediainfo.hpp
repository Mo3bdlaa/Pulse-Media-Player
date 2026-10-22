// Pulse — names and labels derived from files, shared by the Library,
// Playlists and Convert.
#pragma once

#include <QString>

namespace pulse {

struct ParsedName
{
    QString title;   ///< "Blade Runner 2049", "The Last of Us"
    int year = 0;    ///< 2017, or 0
    int season = 0;  ///< 1 for "S01E03", or 0
    int episode = 0; ///< 3 for "S01E03", or 0
};

/// "Blade.Runner.2049.(2017).2160p.HDR.mkv" -> {"Blade Runner 2049", 2017}.
ParsedName parseFileName(const QString &fileName);

/// "4K", "1080p", "720p", "SD", or "" when unknown.
QString qualityLabel(int width, int height);

/// "2h 46m", "53m", "3:12" (under a minute shows m:ss), or "".
QString shortDuration(qint64 ms);

} // namespace pulse
