# Platforms

One codebase (Qt 6 / QML + libVLC 4) targets every platform. The UI adapts by
width (`Theme.compactBreakpoint`, 720 px): sidebar and title bar on desktop,
bottom navigation, bottom sheets and touch sizing on phones.

## Status

| Platform | UI | Engine (libVLC) | CI | Packaging |
| --- | --- | --- | --- | --- |
| Linux x86-64 | ✅ runs, verified on Xvfb | ✅ built from this tree | ✅ build, tests, smoke run | ✅ AppImage (`tools/package-linux.sh`); Flatpak next |
| Windows x64 | ✅ same QML; frameless window, native dialogs | ✅ built from this tree with VideoLAN's win64 toolchain image and prebuilt contribs (`tools/build-libvlc-windows.sh`) | ✅ build, tests, smoke run (`pulse-windows.yml`) | ✅ installer (Inno Setup) and portable zip (`tools/package-windows.sh`) |
| macOS (arm64, x86-64) | ✅ same QML | build with VideoLAN's macOS contribs | ⏳ next | `.app` / DMG next |
| Android (arm64, x86_64) | ✅ compact layout | ✅ built from this tree the way upstream CI does: VideoLAN's Android image and libvlcjni build script, prebuilt contribs (`tools/build-libvlc-android.sh`); one `libvlc.so` with every module | ✅ build, emulator smoke run (`pulse-android.yml`) | ✅ signed APK per ABI (`tools/package-android.sh`); Play Store AAB next |
| iOS / iPadOS | ✅ compact layout | VideoLAN's Apple build (`extras/package/apple`) | ⏳ | IPA next |

✅ done · ⏳ planned. Linux, Windows and Android are built and tested in CI. The other
platforms reuse the same app and engine code; what remains is building the core
with VideoLAN's per-platform scripts (already in this tree under
`extras/package/`) and packaging.

## Windows build

1. `pulse/tools/build-libvlc-windows.sh` (Linux + Docker) runs upstream's
   `extras/package/win32/build.sh` unchanged in the image upstream CI uses for
   win64, with the prebuilt third-party libraries VideoLAN publishes for this
   tree's contrib revision. The result is laid out like VLC for Windows
   (`libvlc.dll`, `plugins\`, `sdk\`).
2. Pulse is built on Windows with Qt's MinGW toolchain:
   `cmake -DPULSE_LIBVLC_DIR=<that folder>/sdk …`.
3. `pulse/tools/package-windows.sh` adds Qt (`windeployqt`), libVLC and its
   plugins, and builds `Pulse-<version>-win64.zip` and `…-setup.exe`
   (`packaging/windows/pulse.iss`).

## Android build

1. `pulse/tools/build-libvlc-android.sh <out> arm64|x86_64` (Linux + Docker)
   runs VideoLAN's `libvlcjni/buildsystem/build-libvlc.sh` at the commit
   upstream CI pins, in upstream's Android image, with prebuilt contribs. The
   result is one `libvlc.so` (core and modules) plus headers. Pulse hands the
   core the Java VM itself (`attachJavaVm()` in `src/engine/engine.cpp`), so
   no Java bindings are needed.
2. `pulse/tools/package-android.sh` builds Pulse with Qt for Android
   (`QT_ANDROID_EXTRA_LIBS` bundles `libvlc.so`), then aligns and signs the
   APK. Manifest and launcher icons: `packaging/android/`.

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
| Library (folders you add) | ✅ | ✅ needs storage permission | ✅ app documents | Pulse's own index (`src/app/library.cpp`); no `medialibrary` dependency |
| Playlists, M3U import/export | ✅ | ✅ | ✅ | |
| Convert / export | ✅ helper process | in process | in process | needs the core's `stream_out_transcode` and FFmpeg encoders |
| Background audio, media keys | ⏳ | ⏳ | ⏳ | MPRIS / SMTC / MPNowPlaying |

Desktop conversions run in `pulse-convert`, a helper executable installed next
to `pulse`, so a fault in an encoder fails that job instead of the player.
Android and iOS do not allow helper processes, so there the same `Transcoder`
runs inside the app.
