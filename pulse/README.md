# Pulse

**Play anything. Feel more.** — a modern media player built on the VLC engine.

Pulse is an independent fork of VLC with a new interface for Windows, macOS,
Linux, Android and iOS. The VLC core in this repository is **never edited**:
Pulse lives entirely in this `pulse/` folder (plus `.github/`), talks to the
core only through the public libVLC API, and merges every upstream VLC update
automatically.

> Pulse is not affiliated with or endorsed by VideoLAN. Playback is powered by
> libVLC, © VideoLAN and contributors, under the GNU (L)GPL.

## How the pieces fit

```
Pulse-Media-Player/
├── src/ lib/ modules/ include/ …   upstream VLC, byte-for-byte (never edited)
├── .github/workflows/              CI + daily upstream sync
└── pulse/
    ├── design/                     tokens.json + the 17 design boards (source of truth)
    ├── src/engine/                 the ONLY code that calls libVLC (adapter)
    ├── src/app/                    queue, recents, library, playlists, convert queue
    ├── src/convert_main.cpp        pulse-convert: runs one conversion per process
    ├── qml/                        the UI: theme, components, shell, screens, player
    ├── assets/                     icons, provisional logo
    ├── tests/                      engine contract tests + queue tests
    ├── tools/                      guards, libVLC build, upstream sync, theme generator
    └── docs/                       design spec, architecture, platforms, reference art
```

* **Core updates without rework** — see [docs/UPSTREAM_SYNC.md](docs/UPSTREAM_SYNC.md).
* **Architecture and the engine boundary** — see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
* **Platforms and what works where** — see [docs/PLATFORMS.md](docs/PLATFORMS.md).
* **Design** — see [design/README.md](design/README.md) and [docs/design.md](docs/design.md).

## Build (Linux, desktop development)

Requirements: Qt ≥ 6.4 (Quick, QuickControls2, Svg, OpenGL, plus the Qt5Compat
GraphicalEffects and QtQuick.Particles QML modules), CMake ≥ 3.21,
Ninja, meson ≥ 1.10, and the FFmpeg and TagLib development libraries.

```sh
# 1. Build libVLC from this repository's upstream sources (no patches).
pulse/tools/build-libvlc.sh build-libvlc            # full: every feature with installed deps
# or: pulse/tools/build-libvlc.sh build-libvlc --profile minimal

# 2. Build Pulse against it.
export PKG_CONFIG_PATH=$PWD/build-libvlc/install/lib/pkgconfig
cmake -S pulse -B build-pulse -G Ninja
cmake --build build-pulse
ctest --test-dir build-pulse --output-on-failure

# 3. Run.
export LD_LIBRARY_PATH=$(dirname "$(find build-libvlc/install -name libvlc.so | head -1)")
build-pulse/pulse                       # opens Home
build-pulse/pulse ~/Videos/movie.mkv    # opens straight into playback
```

`pulse-convert` is built and installed next to `pulse`; Convert uses it to run
each job in its own process.

`PULSE_VLC_ARGS` passes raw core options for debugging, e.g.
`PULSE_VLC_ARGS="--verbose=2"`.

## Rules for contributors

1. **Never edit a file outside `pulse/` or `.github/`.** CI (`tools/check-upstream-clean.sh`) fails if you do.
2. **Only `src/engine/*.cpp` may include `<vlc/…>` or call `libvlc_*`.** CI (`tools/check-engine-boundary.sh`) enforces it.
3. **Colours, type, spacing and motion come from `design/tokens.json`.** Edit the tokens, run `tools/gen-theme.py`; never hand-edit `qml/theme/Theme.qml`.
4. **Ship only working controls.** Anything not implemented yet is shown as *Planned*, never as a dead button (design.md §12).
