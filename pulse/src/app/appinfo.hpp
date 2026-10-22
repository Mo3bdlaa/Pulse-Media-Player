// Pulse — build and launch facts exposed to QML.
#pragma once

#include <QObject>
#include <QUrl>
#include <QVariantList>

namespace pulse {

class AppInfo : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString version MEMBER version CONSTANT)
    Q_PROPERTY(bool mobile MEMBER mobile CONSTANT)
    Q_PROPERTY(QVariantList initialMedia MEMBER initialMedia CONSTANT)

public:
    using QObject::QObject;

    QString version;
    bool mobile = false;
    QVariantList initialMedia; ///< URLs given on the command line or by the OS
};

} // namespace pulse
