// Pulse engine adapter — converts one file to another format with the core's
// stream output (11 Convert & Export). The app layer queues jobs; this class
// runs one at a time and never touches the source file.
#pragma once

#include <QObject>
#include <QRect>
#include <QUrl>
#include <memory>

namespace pulse {

struct TranscodeProfile
{
    QString container = QStringLiteral("mp4"); ///< mp4, mkv, mp3
    QString videoCodec = QStringLiteral("h264"); ///< h264, hevc, copy, none
    QString audioCodec = QStringLiteral("aac"); ///< aac, mp3, copy
    int maxHeight = 0; ///< 0 keeps the source size
    int videoKbps = 0; ///< 0 lets the encoder decide
    int audioKbps = 192;
    bool hardwareDecoding = true;

    // Minimal editing (Edit & Export). The core applies one video filter per
    // pass reliably, so crop plus rotate/flip runs as two passes.
    qint64 startMs = 0;     ///< trim start; snaps back to the previous keyframe
    qint64 endMs = 0;       ///< trim end; 0 = to the end
    QRect crop;             ///< in source pixels; null = whole frame
    QString transform;      ///< "", "90", "180", "270", "hflip", "vflip"
    int sourceWidth = 0;    ///< required with crop or transform
    int sourceHeight = 0;
    bool noAudio = false;

    bool edits() const { return startMs > 0 || endMs > 0 || !crop.isNull() || !transform.isEmpty() || noAudio; }
};

class Transcoder : public QObject
{
    Q_OBJECT

public:
    explicit Transcoder(QObject *parent = nullptr);
    ~Transcoder() override;

    /// Starts writing `output`; false when the core could not start.
    bool start(const QUrl &input, const QString &output, const TranscodeProfile &profile);
    /// Stops the running job; `finished(false, …)` follows and the partial file is removed.
    void cancel();
    bool isRunning() const;

    /// Two-pass edits write `<output>` + this first; it is removed afterwards.
    static constexpr const char *intermediateSuffix() { return ".pulse-pass1.mkv"; }

signals:
    void progress(double position, qint64 lengthMs);
    void finished(bool ok, const QString &error);

private:
    struct Private;
    std::unique_ptr<Private> d;
};

} // namespace pulse
