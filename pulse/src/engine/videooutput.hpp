// Pulse engine adapter — video surface for Qt Quick.
//
// The core renders each frame into a GL texture shared with the scene graph,
// so video composes with QML overlays on every platform (desktop GL and
// mobile GLES) without native child windows.
#pragma once

#include <QQuickItem>
#include <QPointer>
#include <memory>

namespace pulse {

class Player;
class VideoSink;

class VideoOutput : public QQuickItem
{
    Q_OBJECT
    Q_PROPERTY(pulse::Player *player READ player WRITE setPlayer NOTIFY playerChanged)
    Q_PROPERTY(bool hasFrame READ hasFrame NOTIFY hasFrameChanged)

public:
    explicit VideoOutput(QQuickItem *parent = nullptr);
    ~VideoOutput() override;

    Player *player() const;
    void setPlayer(Player *player);
    bool hasFrame() const;

    /// Called by the sink from a core thread when a new frame is ready.
    void frameReady();

signals:
    void playerChanged();
    void hasFrameChanged();

protected:
    QSGNode *updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *) override;
    void geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry) override;
    void itemChange(ItemChange change, const ItemChangeData &value) override;

private:
    void reportSize();

    QPointer<Player> m_player;
    std::shared_ptr<VideoSink> m_sink;
    bool m_hasFrame = false;
};

} // namespace pulse
