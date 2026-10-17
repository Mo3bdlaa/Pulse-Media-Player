# Pulse architecture

```
┌──────────────────────────────── QML (qml/) ────────────────────────────────┐
│ Main.qml: routes, entry rules, shortcuts, drag-and-drop                    │
│ shell/  TitleBar · Sidebar · BottomNav · MiniPlayer · CommandPalette       │
│ screens/ Home · Queue · Network · Settings · Planned (P2/P3 destinations)  │
│ player/  PlayerScreen (video + audio) · Timeline · ToolsPanel · QueueList  │
│ components/ PulseButton · IconButton · NavItem · PulseSlider · Segmented … │
│ theme/Theme.qml  ← generated from design/tokens.json                       │
└───────────────┬──────────────────────────────────────────┬─────────────────┘
                │ Qt properties / slots (import Pulse.Core) │
┌───────────────▼─────────── app services (src/app) ───────▼─────────────────┐
│ PlayQueue · RecentMedia · Preferences (versioned) · MediaInput · Icons      │
└───────────────┬────────────────────────────────────────────────────────────┘
┌───────────────▼────────── engine adapter (src/engine) ─────────────────────┐
│ Engine (libvlc_instance) · Player (libvlc_media_player) · VideoOutput (GL) │
│ the only code that includes <vlc/vlc.h>                                    │
└───────────────┬────────────────────────────────────────────────────────────┘
                │ public libVLC 4 API
┌───────────────▼────────── upstream VLC (untouched) ────────────────────────┐
│ libvlc · libvlccore · modules (demux, codecs, outputs, filters, access …)  │
└────────────────────────────────────────────────────────────────────────────┘
```

## Engine adapter

* **`Engine`** owns the `libvlc_instance_t`. It applies Pulse's core options
  (no VLC title/OSD, hardware decoding preference), sets branding through
  `libvlc_set_app_id` / `libvlc_set_user_agent`, and reports the core version
  and equalizer presets.
* **`Player`** wraps one `libvlc_media_player_t`. libVLC 4 delivers events
  through a versioned `libvlc_media_player_cbs` struct on core threads; the
  adapter re-posts each one to the Qt thread and exposes plain properties:
  state, time and length (ms), tracks, chapters, delays, A–B loop, picture
  adjustment, aspect and crop, deinterlace, equalizer and audio devices.
* **`VideoOutput`** is a `QQuickItem`. The core renders each frame into a
  triple-buffered OpenGL framebuffer through `libvlc_video_set_output_callbacks`,
  on a context that shares textures with Qt Quick. The scene graph samples the
  newest finished frame, so video composes with QML overlays on desktop GL and
  mobile GLES alike, with no native child windows. The core letterboxes, crops
  and scales to the size the item reports, so aspect and crop work unchanged.

Times are milliseconds in the adapter; libVLC 4 uses microseconds internally.

## App services

* **`PlayQueue`** — the queue is UI-owned; the engine plays one item at a
  time. Shuffle and repeat live here. `playRequested(url)` is the only path to
  playback, so Next, Previous, picking a row and end-of-media share one flow.
* **`RecentMedia`** — recent files with resume positions, stored only locally;
  disabling it clears it.
* **`Preferences`** — every setting is a typed, persisted property with a
  schema version and a migration hook (`migrate(from)`).
* **`MediaInput`** — paths, URLs, drops and folders become playable URLs;
  folders expand into naturally sorted queues; subtitles are recognised so a
  dropped `.srt` attaches to the current video.
* **`IconProvider`** — `image://icon/<name>?color=…` recolours the stroke icons
  in `assets/icons`, the same set used on the design boards.

## Entry rules (design.md §5.2)

`main.cpp` collects media arguments. With media, `Main.qml` fills the queue and
routes straight to the player; Home is never shown. With no media, Home opens.
Opening never requires the library.

## Rendering backend

`main.cpp` selects Qt Quick's OpenGL backend and shared contexts. On Windows,
a Direct3D 11 path (`libvlc_video_engine_d3d11`) can be added behind the same
`VideoOutput` interface; on Apple platforms a Metal interop path likewise. Both
are adapter-only changes.
