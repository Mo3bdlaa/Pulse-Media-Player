// Pulse engine adapter — one playback session.
//
// Exposes the playback core as plain Qt properties so screens bind to state
// instead of calling the core. Times are milliseconds; core callbacks arrive
// on core threads and are re-emitted on the object's thread.
#pragma once

#include <QObject>
#include <QString>
#include <QUrl>
#include <QVariantList>
#include <memory>

namespace pulse {

class Player : public QObject
{
    Q_OBJECT

    Q_PROPERTY(State state READ state NOTIFY stateChanged)
    Q_PROPERTY(bool playing READ isPlaying NOTIFY stateChanged)
    Q_PROPERTY(bool hasMedia READ hasMedia NOTIFY mediaChanged)
    Q_PROPERTY(QUrl url READ url NOTIFY mediaChanged)
    Q_PROPERTY(QString errorString READ errorString NOTIFY errorOccurred)

    Q_PROPERTY(qint64 time READ time NOTIFY timeChanged)
    Q_PROPERTY(qint64 length READ length NOTIFY lengthChanged)
    Q_PROPERTY(double position READ position NOTIFY timeChanged)
    Q_PROPERTY(double buffering READ buffering NOTIFY bufferingChanged)
    Q_PROPERTY(bool seekable READ isSeekable NOTIFY capabilitiesChanged)
    Q_PROPERTY(bool pausable READ isPausable NOTIFY capabilitiesChanged)
    Q_PROPERTY(bool rateChangeable READ isRateChangeable NOTIFY capabilitiesChanged)

    // Volume in percent, 0–200 (software gain above 100). Boost adds up to
    // +12 dB on top through the equalizer's preamp: "Ultra Volume", ~8×.
    Q_PROPERTY(int volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(double boost READ boost WRITE setBoost NOTIFY volumeChanged)
    Q_PROPERTY(bool muted READ isMuted WRITE setMuted NOTIFY volumeChanged)
    Q_PROPERTY(double rate READ rate WRITE setRate NOTIFY rateChanged)

    // Metadata read from the media itself (never fetched online here).
    Q_PROPERTY(QString title READ title NOTIFY metaChanged)
    Q_PROPERTY(QString artist READ artist NOTIFY metaChanged)
    Q_PROPERTY(QString album READ album NOTIFY metaChanged)
    Q_PROPERTY(QString genre READ genre NOTIFY metaChanged)
    Q_PROPERTY(QString date READ date NOTIFY metaChanged)
    Q_PROPERTY(QUrl artworkUrl READ artworkUrl NOTIFY metaChanged)

    // Tracks: lists of { id, name, language, selected, codec, ... }.
    Q_PROPERTY(bool hasVideo READ hasVideo NOTIFY tracksChanged)
    Q_PROPERTY(QVariantList videoTracks READ videoTracks NOTIFY tracksChanged)
    Q_PROPERTY(QVariantList audioTracks READ audioTracks NOTIFY tracksChanged)
    Q_PROPERTY(QVariantList subtitleTracks READ subtitleTracks NOTIFY tracksChanged)
    Q_PROPERTY(QString currentAudioTrack READ currentAudioTrack NOTIFY tracksChanged)
    Q_PROPERTY(QString currentSubtitleTrack READ currentSubtitleTrack NOTIFY tracksChanged)

    // Chapters of the current title: { name, time, duration } in ms.
    Q_PROPERTY(QVariantList chapters READ chapters NOTIFY chaptersChanged)
    Q_PROPERTY(int currentChapter READ currentChapter NOTIFY chaptersChanged)

    Q_PROPERTY(qint64 audioDelay READ audioDelay WRITE setAudioDelay NOTIFY delaysChanged)
    Q_PROPERTY(qint64 subtitleDelay READ subtitleDelay WRITE setSubtitleDelay NOTIFY delaysChanged)

    // A–B loop, ms; -1 when unset.
    Q_PROPERTY(qint64 loopA READ loopA NOTIFY loopChanged)
    Q_PROPERTY(qint64 loopB READ loopB NOTIFY loopChanged)

    // Picture, UI scale: -100..100 (hue in degrees -180..180).
    Q_PROPERTY(int brightness READ brightness WRITE setBrightness NOTIFY adjustChanged)
    Q_PROPERTY(int contrast READ contrast WRITE setContrast NOTIFY adjustChanged)
    Q_PROPERTY(int saturation READ saturation WRITE setSaturation NOTIFY adjustChanged)
    Q_PROPERTY(int hue READ hue WRITE setHue NOTIFY adjustChanged)
    Q_PROPERTY(int gamma READ gamma WRITE setGamma NOTIFY adjustChanged)
    Q_PROPERTY(QString aspectRatio READ aspectRatio WRITE setAspectRatio NOTIFY geometryChanged)
    Q_PROPERTY(QString cropRatio READ cropRatio WRITE setCropRatio NOTIFY geometryChanged)
    Q_PROPERTY(int deinterlace READ deinterlace WRITE setDeinterlace NOTIFY geometryChanged)

    // Equalizer: preset index (-1 = off), 10 bands in dB (-20..20), preamp dB.
    Q_PROPERTY(int equalizerPreset READ equalizerPreset WRITE setEqualizerPreset NOTIFY equalizerChanged)
    Q_PROPERTY(bool equalizerEnabled READ isEqualizerEnabled WRITE setEqualizerEnabled NOTIFY equalizerChanged)
    Q_PROPERTY(QVariantList equalizerAmps READ equalizerAmps NOTIFY equalizerChanged)
    Q_PROPERTY(double equalizerPreamp READ equalizerPreamp WRITE setEqualizerPreamp NOTIFY equalizerChanged)

    // Audio outputs: { id, name }.
    Q_PROPERTY(QVariantList audioDevices READ audioDevices NOTIFY audioDevicesChanged)

public:
    enum State { Idle, Opening, Playing, Paused, Stopped, Error };
    Q_ENUM(State)

    enum TrackType { VideoTrack, AudioTrack, SubtitleTrack };
    Q_ENUM(TrackType)

    explicit Player(QObject *parent = nullptr);
    ~Player() override;

    State state() const;
    bool isPlaying() const;
    bool hasMedia() const;
    QUrl url() const;
    QString errorString() const;

    qint64 time() const;
    qint64 length() const;
    double position() const;
    double buffering() const;
    bool isSeekable() const;
    bool isPausable() const;
    bool isRateChangeable() const;

    int volume() const;
    void setVolume(int volume);
    bool isMuted() const;
    void setMuted(bool muted);
    double rate() const;
    void setRate(double rate);

    QString title() const;
    QString artist() const;
    QString album() const;
    QString genre() const;
    QString date() const;
    QUrl artworkUrl() const;

    bool hasVideo() const;
    QVariantList videoTracks() const;
    QVariantList audioTracks() const;
    QVariantList subtitleTracks() const;
    QString currentAudioTrack() const;
    QString currentSubtitleTrack() const;

    QVariantList chapters() const;
    int currentChapter() const;

    qint64 audioDelay() const;
    void setAudioDelay(qint64 ms);
    qint64 subtitleDelay() const;
    void setSubtitleDelay(qint64 ms);

    qint64 loopA() const;
    qint64 loopB() const;

    int brightness() const;
    void setBrightness(int v);
    int contrast() const;
    void setContrast(int v);
    int saturation() const;
    void setSaturation(int v);
    int hue() const;
    void setHue(int v);
    int gamma() const;
    void setGamma(int v);
    QString aspectRatio() const;
    void setAspectRatio(const QString &ratio);
    QString cropRatio() const;
    void setCropRatio(const QString &ratio);
    int deinterlace() const;
    void setDeinterlace(int mode);

    int equalizerPreset() const;
    void setEqualizerPreset(int index);
    bool isEqualizerEnabled() const;
    void setEqualizerEnabled(bool enabled);
    QVariantList equalizerAmps() const;
    double equalizerPreamp() const;
    double boost() const;
    void setBoost(double db);
    void setEqualizerPreamp(double db);

    QVariantList audioDevices() const;

    /// Opaque core player handle; only meaningful inside src/engine.
    void *nativeHandle() const;
    /// Keeps an engine-internal object alive until the core player is released.
    void keepAlive(std::shared_ptr<void> object);

public slots:
    /// Opens a local path or any URL the core understands and starts playback.
    void open(const QUrl &url, qint64 startTimeMs = 0);
    void play();
    void pause();
    void togglePause();
    void stop();

    void seek(qint64 ms);
    void seekBy(qint64 deltaMs);
    void setPosition(double position);
    void setChapter(int index);
    void nextChapter();
    void previousChapter();

    void selectTrack(int type, const QString &id);
    void disableTrack(int type);
    bool addSubtitleFile(const QUrl &url);

    void setLoopA();
    void setLoopB();
    void clearLoop();

    void resetPicture();
    void setEqualizerAmp(int band, double db);
    void resetEqualizer();
    void setAudioDevice(const QString &id);
    void refreshAudioDevices();

    /// Saves the current frame and returns the target path ("" on failure).
    QString takeSnapshot(const QString &directory);

signals:
    void stateChanged();
    void mediaChanged();
    void timeChanged();
    void lengthChanged();
    void bufferingChanged();
    void capabilitiesChanged();
    void volumeChanged();
    void rateChanged();
    void metaChanged();
    void tracksChanged();
    void chaptersChanged();
    void delaysChanged();
    void loopChanged();
    void adjustChanged();
    void geometryChanged();
    void equalizerChanged();
    void audioDevicesChanged();

    void endReached();
    void errorOccurred(const QString &message);
    void snapshotSaved(const QString &path);

private:
    struct Private;
    std::unique_ptr<Private> d;
};

} // namespace pulse
