// Pulse engine adapter — converts one file to another format with the core's
// stream output (11 Convert & Export). The app layer queues jobs; this class
// runs one at a time and never touches the source file.
#pragma once

#include <QObject>
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

signals:
    void progress(double position, qint64 lengthMs);
    void finished(bool ok, const QString &error);

private:
    struct Private;
    std::unique_ptr<Private> d;
};

} // namespace pulse
