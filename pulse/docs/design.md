# Pulse — Product Design Specification

**Version:** 1.0 (design baseline)  
**Status:** Concept approved for exploration; not yet an implemented product  
**Platforms:** Desktop (Windows, macOS, Linux) and mobile (Android, iOS)  
**Lineage:** Independent, redesigned fork of VLC media player  
**Primary reference:** `Pulse_12_Screens_and_Logo.zip`

> **Play anything. Feel more.**

## 1. Product vision

Pulse modernizes the VLC media-player experience while preserving the fast, flexible, local-first utility that makes VLC valuable. It is **a media player first**, not a streaming service or library-first entertainment dashboard.

### Non-negotiable behavior

1. **Opening an associated media file launches directly into playback.** Do not route through Welcome, Library, an onboarding flow, or a promotional screen.
2. **Launching Pulse without a file opens Welcome / Home.** The primary choices are Open File, Open Folder, and Open URL.
3. **The library is optional.** No indexing, accounts, metadata downloads, or media organization are required to play a file.
4. **Media is the hero.** Video should fill the usable player surface; controls appear when needed, then disappear.
5. **Power is available, not imposed.** Advanced VLC capabilities belong in contextual tools rather than permanent onscreen clutter.
6. **Local-first and privacy-respecting.** Do not require sign-in, cloud sync, or network access for basic playback.
7. **Desktop and mobile share one visual language**, but use appropriate interaction models for keyboard/mouse versus touch.

### Goals

- Fast launch and minimal time-to-first-frame.
- Broad format, subtitle, audio track, and stream support, limited by the actual VLC fork and platform capabilities.
- Beautiful, expressive design without compromising legibility or utility.
- Accessible controls, discoverable settings, and clear feedback.
- Library, playlists, conversion, and network features available on demand.

### Not goals

- Recreating Netflix/Spotify as the default home experience.
- Requiring media scanning to play individual files.
- Forcing recommendations, social feeds, accounts, or advertisements into the player.
- Assuming every underlying VLC capability exists identically on every platform.

## 2. Identity and branding

| Element | Decision |
| --- | --- |
| Product name | **Pulse** |
| Repository name | `pulse` |
| Descriptor | A modern media player, built as an independent VLC fork |
| Tagline | **Play anything. Feel more.** |
| Character | Bold, expressive, cinematic, efficient, confident |
| Palette | **01 — Signal Ember** |
| Logo | **Concept #24** from the 32-logo exploration board |
| Secondary motif | Concept #07's waveform may inform audio visualizations and motion, **not** replace the primary logo |

### Logo direction

Concept #24 is the **two-part, right-facing fast-forward/play mark**: a solid rounded ember-orange play triangle on the left and a separate warm gold/yellow chevron on the right. The shapes are adjacent but distinct, with breathing room; there is **no enclosing ring**, letter P, or waveform. The wide-spaced `PULSE` wordmark is optional in compact placements.

**Canonical reference:** `Pulse_Logo_24_Original_Reference.png` inside the design archive (the cropped source reference). Prior AI-generated transparent recreations were **not exact matches** and **must not be treated as final production assets**. Before release, redraw the approved logo as a precise vector and obtain approval at large, small, monochrome, and app-icon sizes.

Logo use:
- Full lockup: mark + `PULSE`, for Welcome, About, marketing, and desktop chrome.
- Icon: mark alone, for application icons, taskbar/dock, toolbar, loading, and mobile launcher.
- Minimum size: test the geometry at 16, 24, 32, 48, and 64 px; adjust optical spacing without changing the recognizable silhouette.
- Build light-background and dark-background versions, plus a single-color fallback.
- Avoid unauthorized official VideoLAN branding or claims of endorsement. Credit source software appropriately.

## 3. Color system — Signal Ember

Use the selected palette direction as the source of truth; the following values are **implementation starter tokens** and should be color-sampled/verified against the approved palette board before final production sign-off.

| Token | Suggested hex | Role |
| --- | --- | --- |
| `--color-bg` | `#111217` | Main near-black application background |
| `--color-surface` | `#1F2430` | Cards, sidebars, panels |
| `--color-accent` | `#FF6A28` | Primary actions, active states, progress |
| `--color-highlight` | `#FFD166` | Secondary glow, gradient tip, special emphasis |
| `--color-text` | `#F7F4EF` | Primary text and icons |
| `--color-surface-raised` | `#2A2E39` | Hover or raised panels (derived) |
| `--color-text-secondary` | `#AAAAB3` | Supporting text (derived) |
| `--color-border` | `#393944` | Borders/dividers (derived) |
| `--color-error` | `#FF5A63` | Errors (derived, accessibility-check) |
| `--color-success` | `#62C999` | Success (derived, accessibility-check) |

**Accent gradient:** `linear-gradient(110deg, #FF6A28 0%, #FF9A3A 55%, #FFD166 100%)`.

Rules:
- Reserve ember orange for important actions, active controls, selection, and progress; avoid outlining every card in orange.
- Use warm highlights sparingly. Film artwork must remain visually dominant.
- Default surfaces are matte and subtle; strong glows are for branded moments or focus, not for dense technical panels.
- Maintain WCAG-appropriate contrast: target **4.5:1** for normal text, **3:1** for large text and meaningful UI graphics.
- Video overlays should use a dark scrim/gradient so controls remain readable against bright frames.
- Support OS high-contrast and reduced-motion preferences.

## 4. Typography, shape, and motion

- **UI font:** Inter or a comparable highly legible, widely available sans-serif; system-font fallback required.
- **Display/wordmark:** custom geometric wide-tracked uppercase treatment; avoid using the wordmark font for dense UI.
- **Hierarchy:** display 32–44 px desktop / 26–32 px mobile; section titles 20–24 px; body 14–16 px; metadata 12–13 px, never tiny in production.
- **Spacing scale:** 4, 8, 12, 16, 24, 32, 48 px. Minimum touch target **44 × 44 pt** on iOS / approximately **48 × 48 dp** on Android.
- **Radii:** 8 px small controls, 12 px cards, 16–20 px major surfaces; circular primary play control.
- **Motion:** 120–180 ms for small control states; 200–300 ms for sheets/panels; calm, purposeful easing.
- **Hover/focus:** clear distinction between hover, keyboard focus, selected, playing, and disabled states. Never rely on color alone.
- **Motion accessibility:** disable decorative parallax, looping glows, and reactive effects when reduced motion is enabled.

## 5. Information architecture — 12 mockup screens

The following inventory follows the **actual files in the agreed design archive**. Some images are promotional concept compositions rather than production-ready pixel-accurate screens; use them as visual references, not executable specifications.

| # | Screen | Primary content | Primary actions | Reference image in ZIP |
| --- | --- | --- | --- | --- |
| 01 | **Welcome / Home** | Open-media hero, drop area, recent files, optional quick links and shortcuts | Open File, Open Folder, Open URL, resume recent | `01_Welcome_Home.png` |
| 02 | **Video Player** | Full video surface, auto-hide transport/timeline, volume, chapter/track controls | Play/pause, seek, subtitles, audio, fullscreen, tools | `02_Video_Player.png` |
| 03 | **Audio Player** | Artwork or fallback visual, track metadata, waveform (optional), progress, volume | Play/pause, previous/next, shuffle/repeat, queue, output | `03_Audio_Player.png` |
| 04 | **Playback Queue** | Current item and ordered upcoming media with duration/type | Reorder, remove, clear, shuffle, repeat, save playlist | `04_Playback_Queue.png` |
| 05 | **Playback Tools** | Video, audio, subtitles, speed, effects, track timing, chapters, A–B loop | Adjust settings, reset, capture screenshot | `05_Playback_Tools.png` |
| 06 | **Media Library** | Optional indexed directories, grids/lists, search, recently added, continue watching | Add/remove folder, scan, filter, play | `06_Media_Library.png` |
| 07 | **Media Details** | Real file metadata, video/audio codecs, tracks, chapters, file path and technical info | Play, add to queue, open folder, copy details | `07_Media_Details.png` |
| 08 | **Playlists** | Playlist list, mixed-media playlist contents, import/export | New playlist, rename, reorder, add/remove, play all | `08_Playlists.png` |
| 09 | **Network & Streams** | Open URL, saved streams, recent addresses, discovered sources where supported | Connect/open, refresh, browse, save | `09_Network_Streams.png` |
| 10 | **Settings** | General, playback, appearance, file associations, subtitles, library, network, advanced | Change defaults, reset, manage shortcuts | `10_Settings.png` |
| 11 | **Convert & Export** | Input selection, output presets, codec/options, output destination, job queue | Add files, choose preset, convert, cancel | `11_Convert_Export.png` |
| 12 | **Expanded Now Playing** | Theater-style media detail + progress + chapter and up-next context | Resume, chapters, track selection, toggle info/queue | `12_Now_Playing.png` |

**Scope clarification:** The earlier planning draft listed About & Updates as screen 12 and placed Convert at 10 / Settings at 11. The generated images instead depict **Settings at 10, Convert at 11, and expanded Now Playing at 12**. This document follows the delivered visual assets. **About, Updates, Licenses, and Credits are sections/dialogs within Settings**, not a 13th primary screen.

### 5.1 Main navigation

**Desktop:** compact left navigation for Welcome, Library, Playlists, Network, Convert, Settings. Now Playing/Queue are reachable from player controls and can optionally appear contextually in navigation. Avoid showing a permanent sidebar over a playing video.

**Mobile:** bottom navigation on non-player screens, with a maximum of 4–5 destinations and a `More` section when necessary. Fullscreen video hides the bottom navigation. Playback tools use bottom sheets; queue and details can open as dedicated sheets/screens as appropriate.

### 5.2 Entry-point state machine

```text
Launch Pulse
├── A file or supported stream is supplied
│   └── Open Player immediately
│       ├── Video → Video Player
│       └── Audio → Audio Player
└── No media supplied
    └── Welcome / Home
        ├── Open File / Folder → Player or Queue
        ├── Open URL → Network playback
        ├── Recent file → Player
        └── Optional navigation → Library / Playlists / Network / Tools
```

If opening fails, show a useful inline error with Retry, File Information, and troubleshooting details. Never silently drop a file or force library import.

## 6. Core screen behavior

### 01 — Welcome / Home

- Default only for an empty launch.
- Primary CTA: **Open File**. Secondary: **Open Folder** and **Open URL**.
- Desktop: drag-and-drop entire window or large visible target; dropping multiple files starts a queue.
- Mobile: native document picker, open-with/share-to-Pulse integration, and supported network URL entry.
- Recent files: optional, removable, and controllable in privacy settings; no fake posters or required online metadata.
- No mandatory account, indexing wizard, or tutorial.

### 02 — Video Player

- First priority: an unobstructed, appropriately scaled video canvas.
- Transport overlay: play/pause, scrub, elapsed/remaining time, volume, fullscreen, subtitle and audio track selectors, tools, queue.
- Hide controls after a short period of inactivity; reveal on mouse move/tap and keep visible while keyboard focus or a menu is active.
- Hover/touch scrubbing previews are progressive enhancements, available only if supported efficiently.
- Dedicated subtitle picker allows loading external subtitle files and adjusting delay.
- Chapters, playback speed, and picture-in-picture appear only where platform playback supports them.
- Keep navigation, big decorative hero sections, and library grids out of the video canvas.

### 03 — Audio Player

- Artwork when available; appealing logo/gradient fallback when missing.
- Legible title, album/artist metadata if present; never require an internet lookup.
- Timeline, transport, shuffle/repeat, queue, audio output and volume.
- Equalizer and visualizer are optional enhancements and must not affect playback performance.
- Keep playing on navigation or screen lock where permitted by the OS.

### 04 — Playback Queue

- Distinctly mark **Now Playing** versus **Up Next**.
- Reorder via drag-and-drop on desktop, accessible reorder actions on mobile.
- Enqueue from file opening, folder opening, Playlists, Library, and the OS share/open workflow.
- Clearing the queue must not delete any file.
- Saving a queue creates a playlist, not a copy of media.

### 05 — Playback Tools

- Organized categories: Video, Audio, Subtitles, Playback, Advanced.
- Video: crop, rotate, deinterlace, aspect ratio, brightness/contrast/saturation.
- Audio: track/device, gain/equalizer, sync.
- Subtitles: track, load file, sync, styling.
- Playback: speed, A–B loop, chapters and screenshot.
- Advanced: codec information and rare filters behind expandable controls.
- Always show numeric feedback, a clear Reset action, and only controls actually supported by the current engine/platform.

### 06 — Media Library

- Fully optional and opt-in for directory indexing.
- Folder-based browsing works even with no fetched posters or metadata.
- Filters: Movies, TV, Music, Other; search, recent and sort options.
- Offline and unrecognized media remain playable.
- Missing paths show a reconnect/remap action, not automatic destructive removal.
- Scan progress and data sources should be transparent.

### 07 — Media Details

- Prioritize **real technical information read from the file**: path, container, size, duration, resolution, framerate, codec, bitrate, color space, audio/subtitle tracks, chapters.
- Additional film synopsis, commercial ratings, cast, and poster metadata are **optional online enrichments**, disabled unless consent/settings allow and a legitimate metadata provider is configured.
- Never present generated sample movie metadata as if detected from the local file.

### 08 — Playlists

- Support common playlist import/export formats as validated by backend capabilities (e.g., M3U/M3U8 where supported).
- Mixed audio/video playlists are permitted.
- Adding to a playlist references media paths or accessible URLs; does not duplicate source files.
- File missing/unavailable states are recoverable.

### 09 — Network & Streams

- Clear URL input with paste support and history controls.
- Protocol support must be based on tested underlying VLC implementation, not generic UI claims.
- Local network browsing (e.g., SMB, UPnP/DLNA) depends on device permissions, operating system, and compiled modules.
- Do not hard-code discovery results or show fabricated connected devices.
- Passwords/credentials must use platform-secure storage and must never be printed into diagnostic logs.

### 10 — Settings

- Tabs or searchable sections: General, Playback, Appearance, Audio & Video, Subtitles, Library, Network, Shortcuts, Advanced.
- Appearance starts with Signal Ember dark; light/system modes are future choices only if fully designed and tested.
- Preferences should be named clearly, persist across launches, and indicate when restart is needed.
- Provide import/export/reset preferences where feasible.
- **About & Updates:** version, build identifiers, open-source notices, source attribution, release notes, update mechanism if implemented.

### 11 — Convert & Export

- Separate source input from output destination and preset.
- Offer honest preset descriptions (e.g., MP4/H.264, extract audio) only after backend capability validation.
- Show individual job progress, queue states, error messages, and cancellation.
- Do **not** default to deleting source files, even after success.
- Warn before output overwrite; prefer a safe new filename.
- Platform caveat: conversion can be desktop-first if the mobile backend/OS cannot support the same workflow.

### 12 — Expanded Now Playing

- Optional expanded view containing media artwork/info, chapters, up-next list, and rich context around playback.
- It **does not replace** the immediate immersive Video Player in screen 02.
- For local files with no metadata, display filename and actual technical attributes rather than fake film catalog information.
- On mobile, queue/info are tabs or sheets; avoid a dense information dashboard while viewing video fullscreen.

## 7. Shared reusable UI components

| Component | Required states / behavior |
| --- | --- |
| App shell | Sidebar / mobile bottom nav, active destination, resize handling |
| Pulse logo lockup | Icon/wordmark, dark/light/monochrome variants |
| Primary button | Default, hover, focus, pressed, loading, disabled |
| Icon button | Tooltip, focus label, accessible name, compact and touch sizes |
| Media thumbnail/card | Artwork, fallback, metadata, resume marker, missing file state |
| Media list row | Title, duration/type, selected, playing, unavailable, overflow menu |
| Playback transport | Play/pause, skip, seek, time, volume, toggle visibility |
| Timeline | Buffered/played areas, scrubbing, chapter marks, accessible slider |
| Queue panel | Reorder, remove, current item, empty state |
| Advanced tools drawer | Category tabs, form controls, reset, apply where needed |
| Bottom sheet | Snap points, swipe dismissal when safe, keyboard/screen reader focus |
| Modal/dialog | Proper focus management, escape/back dismissal and destructive confirmation |
| Form control | Toggle, slider, select, text field with visible value and validation |
| Toast/error | Concise message, optional action, nonintrusive and accessible |
| Loading/empty state | No false media data; meaningful next action |

## 8. Responsive layout & interaction

### Desktop

- Reference layouts use a dark app shell and compact sidebar when **not in immersive playback**.
- Recommended design widths: 1280, 1440, and 1920 px, plus narrow resizable window states.
- Use flexible grid/list layout, never clip functional controls at small window sizes.
- Support keyboard shortcuts, drag-and-drop, context menus, OS file associations and native file dialogs.
- Controls should be discoverable via tooltips and keyboard focus; mouse hover is supplementary.

### Mobile

- Design at representative widths around 360–430 dp/pt; verify compact layouts and large text.
- Use bottom navigation outside video fullscreen; sheets for contextual tools.
- Keep primary playback controls within easy reach, respecting notches, safe areas, system bars, and landscape orientation.
- Support system media controls, headphones/Bluetooth events, media opening through OS share targets, and audio background behavior where supported.
- Avoid relying on hover, tiny gesture targets, or desktop-exclusive interactions.

### Keyboard / remote / accessibility

- Implement common player shortcuts such as Space (play/pause), arrows (seek/volume as specified), F (fullscreen), M (mute), and Esc (close overlay/exit fullscreen); make conflicts and changes discoverable in Settings.
- Logical focus order, visible keyboard focus, labels for every icon-only control, captions/subtitle access, and screen-reader announcements of playback state.
- Test in high-DPI desktop and with mobile font scaling.

## 9. Navigation and user flows

### Flow A — double-click a movie

`OS file association → Pulse bootstrap → Video Player → playback starts → controls auto-hide`.

No Welcome, metadata scan, login, or library insertion required. If resume is enabled and a saved position exists, offer a quick unobtrusive Resume/Restart action (or use the saved behavior configured in settings).

### Flow B — open a folder

`Welcome → Open Folder → playable entries become a queue → play first compatible file`.

If the user elects **Add to Library**, index the folder in a separate explicit action. Do not treat Open Folder as implicit permanent library enrollment.

### Flow C — adjust subtitles

`Video Player → Subtitles → choose embedded track / load file → optional sync/style → return to video`.

Keep the playing media visible behind the panel and preserve the user's position.

### Flow D — stream a URL

`Welcome/Open URL or Network → validate URL → connect → Player → error/retry when unreachable`.

Show clear status without claiming universal protocol availability.

### Flow E — organize a library

`Library → Add Folder → permission/selection → scan → search/filter → Media Details or Play`.

Library usage remains optional and should not change normal double-click playback behavior.

## 10. Visual content and asset guidance

- The screen mockups are aesthetic references and include illustrative sci-fi imagery, example movies, fictional playlists, sample progress times, and made-up data.
- **Do not ship copyrighted movie poster art, film stills, actor likenesses, or third-party marks from mockups** without applicable permission/licensing. Substitute owned/cleared assets or user-provided local file thumbnails.
- Use the selected logo **#24 reference**, not the earlier inaccurate glossy replacements, for the final vector work.
- Media thumbnails should be generated from user files where technically possible or use safe generic placeholders.
- Avoid heavy decorative sci-fi backgrounds on every operational screen: in production, artwork should derive from current media or be used only in limited onboarding/brand moments.

## 11. Technical architecture considerations (not a commitment)

Pulse is currently conceived as a **VLC fork**, not merely a separately built front-end consuming libVLC. Decide whether to modify upstream desktop Qt/QML surfaces, share components with mobile applications, or build independent platform front ends only after assessing upstream project architecture and maintainability.

- **Playback engine:** preserve tested native VLC functionality, platform decoding paths, subtitles, audio tracks, and error reporting.
- **UI architecture:** separate playback state/controller from presentation, so desktop and mobile views use consistent state models.
- **Library index:** independent optional subsystem; never block playback while scanning.
- **Preferences:** versioned, migratable data schema with platform-aware defaults.
- **Media metadata:** distinguish data extracted locally from data supplied by external services.
- **Licensing:** a distributed fork must preserve required notices and comply with applicable VLC GPL license conditions and dependencies. The **VLC name/cone trademarks** are separate from software copyright permissions; avoid presenting Pulse as official VLC.
- **Platform parity:** define a capability matrix before committing to iOS, Android, Linux, Windows, and macOS features.

## 12. Implementation priority

| Phase | Scope | Exit criterion |
| --- | --- | --- |
| **P0 — Player-first MVP** | Open file/URL, desktop video player, basic audio player, seek, track/subtitle selection, volume, fullscreen, basic settings, recent files | A double-clicked supported video starts quickly without touching the library |
| **P1 — Power playback** | Queue, chapters, speed, advanced tools, shortcuts, PiP where supported, accessibility testing | Core VLC playback controls remain available and usable |
| **P2 — Optional organization** | Library, search, folder indexing, playlists, media technical details | Indexing remains explicitly optional; files play without metadata |
| **P3 — Extended utilities** | Network browsing, conversion/export, richer metadata, cross-platform refinements | Each utility is feature-tested per operating system and clearly marked if unsupported |

### Acceptance checklist

- [ ] Open a local video from the file manager directly into playback.
- [ ] Launch Pulse without media into an uncluttered Welcome screen.
- [ ] Open audio, video, a folder/queue, and a network URL without a mandatory library.
- [ ] Switch subtitles and audio tracks while preserving playback state.
- [ ] Auto-hide controls correctly, including keyboard and accessibility edge cases.
- [ ] Media Library can be unused, disabled, or empty without impairing the player.
- [ ] UI works at compact desktop window widths and mobile safe areas.
- [ ] No fictional mockup content is mistaken for real local metadata.
- [ ] Every implemented control is functional; unimplemented features are not shown as working.
- [ ] Logo #24 is traced to a clean, approved vector master.
- [ ] GPL attribution and platform distribution requirements are reviewed before release.

## 13. Reference assets and known inconsistencies

- `Pulse_12_Screens_and_Logo.zip`: 12 numbered PNG design mockups plus the approved **Logo #24 source reference**.
- `pulse_color_palette_exploration_board.png`: palette selection board; user chose **01 — Signal Ember**.
- `pulse_logo_exploration_board.png` / `PULSE Logo Exploration Board(1).png`: 32 logo options; user chose **24**.
- `image(8).png`: user-supplied small crop clarifying exact logo #24 silhouette.

**Design-review notes:**
1. The delivered image for Screen 04 includes a composite containing other screens. Use the **Playback Queue area**, not the entire composition, as its reference.
2. Screen 06 also shares a composition with the previous screen; use the **Media Library section**.
3. Screen 10 in the archive is **Settings** despite the initial plan labeling 10 as Convert; Screen 11 is **Convert**; Screen 12 is **Expanded Now Playing**, not About & Updates.
4. All artwork, dimensions, colors, file metadata, and controls shown in generated images require implementation-level validation and design QA.

---

**Decision hierarchy:** player-first behavior > functional clarity > accessibility > consistency > expression. Pulse should feel bold, but it must never make watching a movie harder than it is in VLC.
