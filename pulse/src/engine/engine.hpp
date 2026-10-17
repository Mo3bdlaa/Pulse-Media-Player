// Pulse engine adapter — process-wide playback core.
//
// This is the only layer allowed to talk to libVLC (see
// tools/check-engine-boundary.sh). Public headers expose Qt types only, so an
// upstream libVLC API change is absorbed inside src/engine/*.cpp.
#pragma once

#include <QObject>
#include <QStringList>
#include <QVariantList>
#include <memory>

namespace pulse {

class Engine : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString coreVersion READ coreVersion CONSTANT)
    Q_PROPERTY(QString coreChangeset READ coreChangeset CONSTANT)
    Q_PROPERTY(QString coreCompiler READ coreCompiler CONSTANT)
    Q_PROPERTY(bool ready READ isReady CONSTANT)
    Q_PROPERTY(QVariantList equalizerPresets READ equalizerPresets CONSTANT)
    Q_PROPERTY(QVariantList equalizerBands READ equalizerBands CONSTANT)

public:
    struct Options
    {
        QString appId;
        QString appName;
        QString appVersion;
        QString iconName;
        bool hardwareDecoding = true;
        QStringList extraArguments; ///< raw core options, e.g. from PULSE_VLC_ARGS
    };

    explicit Engine(const Options &options, QObject *parent = nullptr);
    ~Engine() override;

    static Engine *instance();

    bool isReady() const;
    QString coreVersion() const;
    QString coreChangeset() const;
    QString coreCompiler() const;
    QVariantList equalizerPresets() const;
    QVariantList equalizerBands() const;

    /// Opaque core handle; only meaningful inside src/engine.
    void *nativeHandle() const;

private:
    struct Private;
    std::unique_ptr<Private> d;
};

} // namespace pulse
