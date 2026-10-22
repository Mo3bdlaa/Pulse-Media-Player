#include "videooutput.hpp"
#include "player.hpp"

#include <QMutex>
#include <QOffscreenSurface>
#include <QOpenGLContext>
#include <QOpenGLFramebufferObject>
#include <QOpenGLFunctions>
#include <QQuickWindow>
#include <QSGSimpleRectNode>
#include <QSGSimpleTextureNode>
#include <QSGTexture>
#include <QThread>
#include <array>

#include <vlc/vlc.h>

namespace pulse {

// Shared between the scene graph (render thread) and the core's video output
// thread. Frames are triple buffered: the core renders into one FBO, the scene
// graph samples another, the third holds the newest finished frame.
class VideoSink
{
public:
    VideoSink()
    {
        // QOffscreenSurface must be created on the GUI thread.
        m_surface.setFormat(QSurfaceFormat::defaultFormat());
        m_surface.create();
    }

    void attach(VideoOutput *item)
    {
        QMutexLocker lock(&m_itemLock);
        m_item = item;
    }

    void setSize(QSize size)
    {
        QMutexLocker lock(&m_reportLock);
        m_size = size;
        if (m_reportResize && size.isValid())
            m_reportResize(m_reportOpaque, unsigned(size.width()), unsigned(size.height()));
    }

    struct Frame
    {
        GLuint texture = 0;
        QSize size;
    };

    Frame takeFrame()
    {
        QMutexLocker lock(&m_frameLock);
        if (m_updated) {
            std::swap(m_swapIdx, m_displayIdx);
            m_updated = false;
        }
        const auto &fbo = m_fbos[m_displayIdx];
        if (!fbo)
            return {};
        return { fbo->texture(), fbo->size() };
    }

    // --- core callbacks (video output thread) ---

    static bool setup(void **opaque, const libvlc_video_setup_device_cfg_t *, libvlc_video_setup_device_info_t *)
    {
        auto *self = static_cast<VideoSink *>(*opaque);
        if (!QOpenGLContext::supportsThreadedOpenGL())
            return false;
        // Created on this thread so makeCurrent() is legal here; shares
        // textures with the scene graph through the global share context.
        self->m_context = std::make_unique<QOpenGLContext>();
        self->m_context->setFormat(QSurfaceFormat::defaultFormat());
        self->m_context->setShareContext(QOpenGLContext::globalShareContext());
        if (!self->m_context->create()) {
            self->m_context.reset();
            return false;
        }
        // The core may call back from several threads; park the context with
        // no thread affinity and adopt it on whichever thread makes it current.
        self->m_context->moveToThread(nullptr);
        return true;
    }

    bool enter()
    {
        if (m_context->thread() != QThread::currentThread())
            m_context->moveToThread(QThread::currentThread());
        return m_context->makeCurrent(&m_surface);
    }

    void leave()
    {
        m_context->doneCurrent();
        m_context->moveToThread(nullptr);
    }

    static void cleanup(void *opaque)
    {
        auto *self = static_cast<VideoSink *>(opaque);
        if (!self->m_context)
            return;
        self->enter();
        {
            QMutexLocker lock(&self->m_frameLock);
            for (auto &fbo : self->m_fbos)
                fbo.reset();
            self->m_updated = false;
        }
        self->m_context->doneCurrent();
        self->m_context.reset();
        self->notifyItem();
    }

    static void setWindow(void *opaque, libvlc_video_output_resize_cb resize,
                          libvlc_video_output_mouse_move_cb, libvlc_video_output_mouse_press_cb,
                          libvlc_video_output_mouse_release_cb, void *reportOpaque)
    {
        auto *self = static_cast<VideoSink *>(opaque);
        QMutexLocker lock(&self->m_reportLock);
        self->m_reportResize = resize;
        self->m_reportOpaque = reportOpaque;
        if (resize && self->m_size.isValid())
            resize(reportOpaque, unsigned(self->m_size.width()), unsigned(self->m_size.height()));
    }

    static bool updateOutput(void *opaque, const libvlc_video_render_cfg_t *cfg, libvlc_video_output_cfg_t *out)
    {
        auto *self = static_cast<VideoSink *>(opaque);
        const QSize size(int(cfg->width), int(cfg->height));
        {
            QMutexLocker lock(&self->m_frameLock);
            for (auto &fbo : self->m_fbos)
                fbo = std::make_unique<QOpenGLFramebufferObject>(size);
            self->m_updated = false;
        }
        self->m_fbos[self->m_renderIdx]->bind();

        out->u.opengl_format = GL_RGBA;
        out->full_range = true;
        out->colorspace = libvlc_video_colorspace_BT709;
        out->primaries = libvlc_video_primaries_BT709;
        out->transfer = libvlc_video_transfer_func_SRGB;
        out->orientation = libvlc_video_orient_top_left;
        return true;
    }

    static void swap(void *opaque)
    {
        auto *self = static_cast<VideoSink *>(opaque);
        self->m_context->functions()->glFlush();
        {
            QMutexLocker lock(&self->m_frameLock);
            std::swap(self->m_swapIdx, self->m_renderIdx);
            self->m_updated = true;
        }
        self->m_fbos[self->m_renderIdx]->bind();
        self->notifyItem();
    }

    static bool makeCurrent(void *opaque, bool current)
    {
        auto *self = static_cast<VideoSink *>(opaque);
        if (!self->m_context)
            return false;
        if (current)
            return self->enter();
        self->leave();
        return true;
    }

    static void *getProcAddress(void *opaque, const char *name)
    {
        auto *self = static_cast<VideoSink *>(opaque);
        return reinterpret_cast<void *>(self->m_context->getProcAddress(name));
    }

    bool isGles() const
    {
        QOpenGLContext *share = QOpenGLContext::globalShareContext();
        return share ? share->isOpenGLES() : QSurfaceFormat::defaultFormat().renderableType() == QSurfaceFormat::OpenGLES;
    }

private:
    void notifyItem()
    {
        QMutexLocker lock(&m_itemLock);
        if (m_item)
            QMetaObject::invokeMethod(m_item, &VideoOutput::frameReady, Qt::QueuedConnection);
    }

    QOffscreenSurface m_surface;
    std::unique_ptr<QOpenGLContext> m_context;

    QMutex m_frameLock;
    std::array<std::unique_ptr<QOpenGLFramebufferObject>, 3> m_fbos;
    size_t m_renderIdx = 0;
    size_t m_swapIdx = 1;
    size_t m_displayIdx = 2;
    bool m_updated = false;

    QMutex m_reportLock;
    QSize m_size;
    libvlc_video_output_resize_cb m_reportResize = nullptr;
    void *m_reportOpaque = nullptr;

    QMutex m_itemLock;
    VideoOutput *m_item = nullptr;
};

VideoOutput::VideoOutput(QQuickItem *parent)
    : QQuickItem(parent)
{
    setFlag(ItemHasContents, true);
}

VideoOutput::~VideoOutput()
{
    if (m_sink)
        m_sink->attach(nullptr);
}

Player *VideoOutput::player() const
{
    return m_player;
}

void VideoOutput::setPlayer(Player *player)
{
    if (m_player == player)
        return;
    if (m_player) {
        qWarning("pulse: VideoOutput can be bound to one player only");
        return;
    }
    m_player = player;
    auto *mp = player ? static_cast<libvlc_media_player_t *>(player->nativeHandle()) : nullptr;
    if (mp) {
        m_sink = std::make_shared<VideoSink>();
        m_sink->attach(this);
        libvlc_video_set_output_callbacks(mp,
            m_sink->isGles() ? libvlc_video_engine_gles2 : libvlc_video_engine_opengl,
            VideoSink::setup, VideoSink::cleanup, VideoSink::setWindow, VideoSink::updateOutput,
            VideoSink::swap, VideoSink::makeCurrent, VideoSink::getProcAddress,
            nullptr, nullptr, m_sink.get());
        // The core may use the sink until the player is released.
        player->keepAlive(m_sink);
        reportSize();
    }
    emit playerChanged();
}

bool VideoOutput::hasFrame() const
{
    return m_hasFrame;
}

void VideoOutput::frameReady()
{
    update();
}

void VideoOutput::reportSize()
{
    if (!m_sink)
        return;
    const qreal dpr = window() ? window()->effectiveDevicePixelRatio() : 1.0;
    const QSize px(qMax(1, qRound(width() * dpr)), qMax(1, qRound(height() * dpr)));
    m_sink->setSize(px);
}

void VideoOutput::geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry)
{
    QQuickItem::geometryChange(newGeometry, oldGeometry);
    if (newGeometry.size() != oldGeometry.size())
        reportSize();
}

void VideoOutput::itemChange(ItemChange change, const ItemChangeData &value)
{
    QQuickItem::itemChange(change, value);
    if (change == ItemSceneChange || change == ItemDevicePixelRatioHasChanged)
        reportSize();
}

QSGNode *VideoOutput::updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *)
{
    const VideoSink::Frame frame = m_sink ? m_sink->takeFrame() : VideoSink::Frame{};
    const bool has = frame.texture != 0;
    if (has != m_hasFrame) {
        m_hasFrame = has;
        QMetaObject::invokeMethod(this, &VideoOutput::hasFrameChanged, Qt::QueuedConnection);
    }
    if (!has) {
        delete oldNode;
        return nullptr;
    }

    auto *node = static_cast<QSGSimpleTextureNode *>(oldNode);
    if (!node) {
        node = new QSGSimpleTextureNode;
        node->setOwnsTexture(true);
        node->setFiltering(QSGTexture::Linear);
        // GL framebuffers are bottom-up; Qt Quick expects top-down textures.
        node->setTextureCoordinatesTransform(QSGSimpleTextureNode::MirrorVertically);
    }
    QSGTexture *texture = QNativeInterface::QSGOpenGLTexture::fromNative(
        frame.texture, window(), frame.size, QQuickWindow::TextureHasAlphaChannel);
    node->setTexture(texture);
    node->setRect(boundingRect());
    return node;
}

} // namespace pulse
