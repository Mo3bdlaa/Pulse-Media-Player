// Pulse — recolourable SVG icons: image://icon/<name>?color=%23RRGGBB
#pragma once

#include <QQuickImageProvider>

namespace pulse {

class IconProvider : public QQuickImageProvider
{
public:
    IconProvider();
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;
};

} // namespace pulse
