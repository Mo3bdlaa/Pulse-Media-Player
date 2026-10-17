# Pulse architecture

```
┌──────────────────────────────── QML (qml/) ────────────────────────────────┐
│ Main.qml: routes, entry rules, shortcuts, drag-and-drop                    │
│ shell/  TitleBar · Sidebar · BottomNav · MiniPlayer · CommandPalette       │
│ screens/ Home · Library · Playlists · Convert · Queue · Network · Settings │
│ library/ playlists/ convert/  the parts of those three screens             │
│ player/  PlayerScreen (video + audio) · Timeline · ToolsPanel · QueueList  │
│ components/ PulseButton · IconButton · NavItem · PulseSlider · Segmented … │
│ theme/Theme.qml  ← generated from design/tokens.json                       │
└───────────────┬──────────────────────────────────────────┬─────────────────┘
                │ Qt properties / slots (import Pulse.Core) │
┌───────────────▼─────────── app services (src/app) ───────▼─────────────────┐
│ PlayQueue · RecentMedia · Preferences (versioned) · MediaInput · Icons      │
│ Library · Playlists · ConvertQueue ──(desktop)──▶ pulse-convert helper     │
└───────────────┬────────────────────────────────────────────────────────────┘
┌───────────────▼────────── engine adapter (src/engine) ─────────────────────┐
│ Engine (libvlc_instance) · Player (libvlc_media_player) · VideoOutput (GL) │
│ ThumbnailProvider · MediaProbe · MediaInspector · Transcoder               │
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

* **`ThumbnailProvider`** serves `image://thumb/…`: frames and embedded covers
  from the core's thumbnailer and parser, cached on disk.
* **`MediaProbe`** parses local files in the background (duration, size,
  codecs, tags) for the Library and Playlists.
* **`MediaInspector`** gathers everything about one file for Media Details
  (07) and Now Playing (12): tags, every video, audio and subtitle track, and
  chapters. Chapters are not part of the parser's results, so the inspector
  briefly opens the file paused, decoding one frame into a 16×16 scratch
  buffer, reads the chapter list and closes it again. Results are cached per
  file.
* **`Transcoder`** converts one file through the core's stream output
  (`#transcode{…}:std{…}`). It takes a plain `TranscodeProfile`; the chain
  syntax stays inside the adapter.

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
* **`Library`** (06) — an index of folders the user adds, kept in one JSON
  file. A background scan finds media; `MediaProbe` fills in durations,
  resolutions and tags; file names give titles, years and episodes
  (`mediainfo.cpp`). Items are sorted into Movies, TV Shows, Music and Other.
  Files are never moved or changed; an unplugged drive keeps its items, marked
  offline.
* **`Playlists`** (08) — saved lists of files and addresses (never copies),
  with M3U/M3U8 import and export.
* **`ConvertQueue`** (11) — presets, a job queue and its history. Output goes
  next to the source as `<name> (Pulse).<ext>` and never overwrites. Audio
  already in the target codec is copied rather than re-encoded. On desktop
  each job runs in the `pulse-convert` helper (`src/convert_main.cpp`), which
  reports progress on stdout and removes its partial file if it is stopped
  or the app goes away.

### Known core issue

VLC 4.0-dev's transcoder can read freed memory in
`modules/stream_out/transcode/pcr_sync.c` (`vlc_pcr_sync_SignalFrameOutput`)
when audio and video are both re-encoded. It is reproducible with plain libVLC
calls and is not caused by Pulse. Pulse does not patch the core. It copies
matching audio, which avoids the fault in the common case, and it isolates
every job in the helper, so the fault fails only that job ("Try again with
Keep Original Audio"). The fix arrives with the upstream sync.

## Entry rules (design.md §5.2)

`main.cpp` collects media arguments. With media, `Main.qml` fills the queue and
routes straight to the player; Home is never shown. With no media, Home opens.
Opening never requires the library.

## Rendering backend

`main.cpp` selects Qt Quick's OpenGL backend and shared contexts. On Windows,
a Direct3D 11 path (`libvlc_video_engine_d3d11`) can be added behind the same
`VideoOutput` interface; on Apple platforms a Metal interop path likewise. Both
are adapter-only changes.
