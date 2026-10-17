# Platforms

One codebase (Qt 6 / QML + libVLC 4) targets every platform. The UI adapts by
width (`Theme.compactBreakpoint`, 720 px): sidebar and title bar on desktop,
bottom navigation, bottom sheets and touch sizing on phones.

## Status

| Platform | UI | Engine (libVLC) | CI | Packaging |
| --- | --- | --- | --- | --- |
| Linux x86-64 | ✅ runs, verified on Xvfb | ✅ built from this tree | ✅ build, tests, smoke run | `.desktop` file; AppImage/Flatpak next |
| Windows x64 | ✅ same QML; frameless window, native dialogs | build with VideoLAN's Windows toolchain (llvm-mingw + contribs) | ⏳ next | MSIX / NSIS next |
| macOS (arm64, x86-64) | ✅ same QML | build with VideoLAN's macOS contribs | ⏳ next | `.app` / DMG next |
| Android | ✅ compact layout | VideoLAN's Android build (`extras/package/android`) | ⏳ | AAB next |
| iOS / iPadOS | ✅ compact layout | VideoLAN's Apple build (`extras/package/apple`) | ⏳ | IPA next |

✅ done · ⏳ planned. Only Linux is built and tested in CI today. The other
platforms reuse the same app and engine code; what remains is building the core
with VideoLAN's per-platform scripts (already in this tree under
`extras/package/`) and packaging.

## Capability matrix (design.md §11)

Controls appear only where the platform and the build support them.

| Capability | Desktop | Android | iOS | Notes |
| --- | --- | --- | --- | --- |
| Files, folders, drag-and-drop | ✅ | picker / share | picker / share | |
| Network URLs (HTTP, HLS, DASH, RTSP …) | ✅ | ✅ | ✅ | depends on built modules |
| Tracks, subtitles, delays | ✅ | ✅ | ✅ | |
| Chapters, A–B loop, speed | ✅ | ✅ | ✅ | |
| Picture adjust, aspect, crop, deinterlace | ✅ | ✅ | ✅ | GPU filters |
| Equalizer | ✅ | ✅ | ✅ | |
| Audio output selection | ✅ | system | system (AirPlay) | |
| Screenshot | ✅ | ✅ | ✅ | |
| Picture-in-picture | ⏳ | ⏳ | ⏳ | per-OS APIs |
| Local network browsing (SMB, UPnP) | ⏳ P3 | ⏳ | ⏳ needs Local Network permission | |
| Library | ⏳ P2 | ⏳ | ⏳ | VideoLAN `medialibrary` |
| Convert / export | ⏳ P3 | maybe | no | desktop first |
| Background audio, media keys | ⏳ | ⏳ | ⏳ | MPRIS / SMTC / MPNowPlaying |
