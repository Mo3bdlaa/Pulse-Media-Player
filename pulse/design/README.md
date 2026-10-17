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
| 06 Media Library | `qml/screens/PlannedScreen.qml` (P2) |
| 07 Media Details | `ToolsPanel` Info tab today; full screen with the Library (P2) |
| 08 Playlists | `PlannedScreen` (P2) |
| 09 Network & Streams | `qml/screens/NetworkScreen.qml` (URL playback; discovery P3) |
| 10 Settings | `qml/screens/SettingsScreen.qml` |
| 11 Convert & Export | `PlannedScreen` (P3) |
| 12 Expanded Now Playing | planned: P1, after frame thumbnails |
| M1–M4 Phone | the same QML at compact width: `BottomNav`, bottom sheets |

## Decisions standardised from the concept art

* **Text on accent is dark** (`textOnAccent` #111217, 7:1). White on #FF6A28 is
  only 2.9:1 and fails WCAG.
* **Selection is never colour alone:** a raised fill, a 3 px accent bar and a
  heavier weight. Keyboard focus is a gold ring (`highlight`).
* **One sidebar for every screen:** Home, Library, Playlists, Network, Convert,
  Settings. Now Playing and Queue appear above them only while media is loaded.
  The player itself is immersive, with no sidebar.
* **Phone navigation:** Home, Library, Playlists, Network, More. It is hidden in the player.
* **No invented metadata:** thumbnails are neutral placeholders until frame
  thumbnails land, titles come from tags or the file name, and online
  enrichment is opt-in.
* **Brand glow only on Home.** Operational screens stay matte.
* **Logo:** `assets/logo/pulse-mark.svg` is provisional, traced by eye from
  `docs/reference/Pulse_Logo_24_Original_Reference.png`. A precise approved
  vector master is still required (design.md §2).
* **Font:** Inter. Put `InterVariable.ttf` (SIL OFL) in `assets/fonts/` to
  bundle it; otherwise the system sans-serif is used.
