# Pulse design

* **Canvas:** https://claude.ai/artifact/5FCsbGDPfgJ9UZuTYn9ruR, with 17 boards:
  Foundations, the 12 desktop screens and 4 phone screens. The same boards are
  checked in under `screens/` as `.dc.html` files.
* **Tokens:** `tokens.json` is the single source for colour, type, spacing,
  radii, sizes and motion. `tools/gen-theme.py` turns it into
  `qml/theme/Theme.qml`; CI fails if the two drift apart.
* **Spec:** `../docs/design.md` (product rules) and `../docs/reference/` (the
  original concept art, kept for reference only).

## How the boards map to code

| Board | QML |
| --- | --- |
| 00 Foundations | `qml/theme/Theme.qml`, `qml/components/*` |
| 01 Welcome / Home | `qml/screens/HomeScreen.qml` |
| 02 Video Player | `qml/player/PlayerScreen.qml` (video mode), `Timeline.qml` |
| 03 Audio Player | `qml/player/PlayerScreen.qml` (audio mode) |
| 04 Playback Queue | `qml/screens/QueueScreen.qml`, `qml/player/QueueList.qml` |
| 05 Playback Tools | `qml/player/ToolsPanel.qml` |
| 06 Media Library | `qml/screens/LibraryScreen.qml`, `qml/library/*` |
| 07 Media Details | `ToolsPanel` Info tab today; a full screen is next |
| 08 Playlists | `qml/screens/PlaylistsScreen.qml`, `qml/playlists/*` |
| 09 Network & Streams | `qml/screens/NetworkScreen.qml` (URL playback; discovery P3) |
| 10 Settings | `qml/screens/SettingsScreen.qml` |
| 11 Convert & Export | `qml/screens/ConvertScreen.qml`, `qml/convert/*` |
| 12 Expanded Now Playing | planned: P1, after frame thumbnails |
| M1–M4 Phone | the same QML at compact width: `BottomNav`, bottom sheets |

## Visual direction (matches the concept art)

The app follows the 12 concept screens in `docs/reference/`, not a flattened
reinterpretation of them:

* **Ember scene** (`qml/components/HeroScene.qml`): a molten planet over a ridge
  line with drifting embers. It is drawn in code, so it is owned art and scales to
  any size. It sits behind Home and every page banner (`PageBanner.qml`).
* **Glow:** filled accent surfaces use the ember gradient
  (`accentBright` → `accentDeep`) with a soft bloom (`AccentGlow.qml`). This
  covers the primary button, the active nav item, the play ring, the active tool
  tab and the timeline knob. The window has an ember rim (`frameGlow`).
* **Glass:** cards and floating panels (tools, queue, settings groups,
  recents) are translucent dark glass with a hairline border.
* **Imagery is real:** recent files, the queue, Up Next and timeline previews
  show frames from the user's files. Audio shows its embedded cover
  (`ThumbnailProvider`, cached on disk). Placeholders appear only while
  loading, or for streams.
* **Player:** chapter labels over the timeline, a ring play button, two-line
  track chips, rounded-square tool buttons, and a floating tools card with a
  vertical tab rail (02 and 05).
* **Audio (03):** artwork with bloom, title with the last word in ember, and
  pulse bars. The bars are a decorative visualiser, not a waveform.
* **Text on accent is white, bold, ≥ 14 px**, as in the concept art. On the
  gradient this meets WCAG's 3:1 large/bold-text ratio, not the 4.5:1 body-text
  ratio, so accent fills never carry small text.
* **Selection is never colour alone:** a filled pill, a bolder weight and an
  icon change. Keyboard focus is a gold ring (`highlight`).
* **Reduce motion** stops the embers, the pulse bars and the loading pulse.
* **Not shipped:** the copyrighted posters and stills in the concept art.
* **Logo:** `assets/logo/pulse-mark.svg` is provisional, traced from
  `docs/reference/Pulse_Logo_24_Original_Reference.png`. A precise approved
  vector master is still required (design.md §2).
* **Font:** Inter. Put `InterVariable.ttf` (SIL OFL) in `assets/fonts/` to
  bundle it; otherwise the system sans-serif is used.

The design canvas boards in `screens/` predate this direction and are kept for
layout and copy only. The concept art and the running app are the visual
reference.
