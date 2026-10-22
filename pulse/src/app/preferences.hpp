// Pulse — user preferences: versioned, persisted, migratable.
#pragma once

#include <QObject>
#include <QVariant>

namespace pulse {

class Preferences : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int schemaVersion READ schemaVersion CONSTANT)
    Q_PROPERTY(bool keepRecent READ keepRecent WRITE setKeepRecent NOTIFY keepRecentChanged)
    Q_PROPERTY(bool resumePlayback READ resumePlayback WRITE setResumePlayback NOTIFY resumePlaybackChanged)
    Q_PROPERTY(bool autoplayNext READ autoplayNext WRITE setAutoplayNext NOTIFY autoplayNextChanged)
    Q_PROPERTY(int seekStepMs READ seekStepMs WRITE setSeekStepMs NOTIFY seekStepMsChanged)
    Q_PROPERTY(int controlsHideMs READ controlsHideMs WRITE setControlsHideMs NOTIFY controlsHideMsChanged)
    Q_PROPERTY(bool hardwareDecoding READ hardwareDecoding WRITE setHardwareDecoding NOTIFY hardwareDecodingChanged)
    Q_PROPERTY(bool useSystemFrame READ useSystemFrame WRITE setUseSystemFrame NOTIFY useSystemFrameChanged)
    Q_PROPERTY(bool reduceMotion READ reduceMotion WRITE setReduceMotion NOTIFY reduceMotionChanged)
    Q_PROPERTY(bool artworkBackground READ artworkBackground WRITE setArtworkBackground NOTIFY artworkBackgroundChanged)
    Q_PROPERTY(int volume READ volume WRITE setVolume NOTIFY volumeChanged)

public:
    static constexpr int kSchemaVersion = 1;

    explicit Preferences(QObject *parent = nullptr);
    int schemaVersion() const { return kSchemaVersion; }

    bool keepRecent() const { return m_keepRecent; }
    void setKeepRecent(bool v) { if (m_keepRecent == v) return; m_keepRecent = v; store("keepRecent", v); emit keepRecentChanged(); }
    bool resumePlayback() const { return m_resumePlayback; }
    void setResumePlayback(bool v) { if (m_resumePlayback == v) return; m_resumePlayback = v; store("resumePlayback", v); emit resumePlaybackChanged(); }
    bool autoplayNext() const { return m_autoplayNext; }
    void setAutoplayNext(bool v) { if (m_autoplayNext == v) return; m_autoplayNext = v; store("autoplayNext", v); emit autoplayNextChanged(); }
    int seekStepMs() const { return m_seekStepMs; }
    void setSeekStepMs(int v) { if (m_seekStepMs == v) return; m_seekStepMs = v; store("seekStepMs", v); emit seekStepMsChanged(); }
    int controlsHideMs() const { return m_controlsHideMs; }
    void setControlsHideMs(int v) { if (m_controlsHideMs == v) return; m_controlsHideMs = v; store("controlsHideMs", v); emit controlsHideMsChanged(); }
    bool hardwareDecoding() const { return m_hardwareDecoding; }
    void setHardwareDecoding(bool v) { if (m_hardwareDecoding == v) return; m_hardwareDecoding = v; store("hardwareDecoding", v); emit hardwareDecodingChanged(); }
    bool useSystemFrame() const { return m_useSystemFrame; }
    void setUseSystemFrame(bool v) { if (m_useSystemFrame == v) return; m_useSystemFrame = v; store("useSystemFrame", v); emit useSystemFrameChanged(); }
    bool reduceMotion() const { return m_reduceMotion; }
    void setReduceMotion(bool v) { if (m_reduceMotion == v) return; m_reduceMotion = v; store("reduceMotion", v); emit reduceMotionChanged(); }
    bool artworkBackground() const { return m_artworkBackground; }
    void setArtworkBackground(bool v) { if (m_artworkBackground == v) return; m_artworkBackground = v; store("artworkBackground", v); emit artworkBackgroundChanged(); }
    int volume() const { return m_volume; }
    void setVolume(int v) { if (m_volume == v) return; m_volume = v; store("volume", v); emit volumeChanged(); }

    Q_INVOKABLE void resetAll();

signals:
    void keepRecentChanged();
    void resumePlaybackChanged();
    void autoplayNextChanged();
    void seekStepMsChanged();
    void controlsHideMsChanged();
    void hardwareDecodingChanged();
    void useSystemFrameChanged();
    void reduceMotionChanged();
    void artworkBackgroundChanged();
    void volumeChanged();

private:
    void store(const char *key, const QVariant &value);
    void load();
    void migrate(int from);

    bool m_keepRecent = true;
    bool m_resumePlayback = true;
    bool m_autoplayNext = true;
    int m_seekStepMs = 10000;
    int m_controlsHideMs = 3000;
    bool m_hardwareDecoding = true;
    bool m_useSystemFrame = false;
    bool m_reduceMotion = false;
    bool m_artworkBackground = true;
    int m_volume = 100;
};

} // namespace pulse
