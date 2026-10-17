#include "iconprovider.hpp"

#include <QColor>
#include <QFile>
#include <QPainter>
#include <QSvgRenderer>
#include <QUrlQuery>

namespace pulse {

IconProvider::IconProvider()
    : QQuickImageProvider(QQuickImageProvider::Image)
{
}

QImage IconProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    const int q = int(id.indexOf(QLatin1Char('?')));
    const QString name = q < 0 ? id : id.left(q);
    const QUrlQuery query(q < 0 ? QString() : id.mid(q + 1));
    const QString color = query.queryItemValue(QStringLiteral("color"), QUrl::FullyDecoded);

    QFile file(QStringLiteral(":/qt/qml/Pulse/assets/icons/%1.svg").arg(name));
    QByteArray svg;
    if (file.open(QIODevice::ReadOnly))
        svg = file.readAll();
    // QML colours may carry alpha (#AARRGGBB); SVG gets the RGB, the painter the alpha.
    const QColor tint(color.isEmpty() ? QStringLiteral("#F7F4EF") : color);
    svg.replace("currentColor", tint.name(QColor::HexRgb).toUtf8());

    const QSize target = requestedSize.width() > 0 && requestedSize.height() > 0 ? requestedSize : QSize(24, 24);
    QImage image(target, QImage::Format_ARGB32_Premultiplied);
    image.fill(Qt::transparent);
    if (!svg.isEmpty()) {
        QSvgRenderer renderer(svg);
        QPainter painter(&image);
        painter.setOpacity(tint.alphaF());
        renderer.render(&painter);
    } else {
        qWarning("pulse: missing icon '%s'", qPrintable(name));
    }
    if (size)
        *size = target;
    return image;
}

} // namespace pulse
