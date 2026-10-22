**Pulse — Play anything. Feel more.** A media player built on the VLC engine, with a new interface.

This is an **early preview (alpha)**. It is the first downloadable build: please try it and report problems in Issues.

## Download

| System | File |
| --- | --- |
| Windows 10/11 (64-bit) — installer | `Pulse-…-win64-setup.exe` |
| Windows 10/11 (64-bit) — portable | `Pulse-…-win64.zip` |
| Linux (64-bit) | `Pulse-…-x86_64.AppImage` |
| Android 9+ — phones and tablets | `Pulse-…-android-arm64-v8a.apk` |
| Android 9+ — x86_64 (emulators, some Chromebooks) | `Pulse-…-android-x86_64.apk` |

macOS and iOS builds are not available yet.

### Install on Android

Download the `arm64-v8a` APK on the phone, open it and allow installing from
this source when Android asks. This preview is signed with a temporary key: a
later build with the final key will need uninstalling this one first.

### Run on Windows

Run the `setup.exe` (no administrator rights needed) or unzip the portable
build anywhere and start `pulse.exe`. The builds are not code-signed yet, so
SmartScreen may warn: choose **More info → Run anyway**.

### Run on Linux

```sh
chmod +x Pulse-*-x86_64.AppImage
./Pulse-*-x86_64.AppImage            # or: ./Pulse-*-x86_64.AppImage movie.mkv
```

Needs a 64-bit distribution from 2024 or newer (glibc 2.39+), for example
Ubuntu 24.04, Fedora 40, Debian 13 or Linux Mint 22. If double-clicking does
nothing, install FUSE 2 (`sudo apt install libfuse2t64`) or run it with
`--appimage-extract-and-run`. Check the download with the `.sha256` file.

## What's inside

- **Player**: almost every audio and video format and stream (VLC engine), chapters, tracks, subtitles, A–B loop, speed, picture adjustments, equalizer, screenshots, resume where you stopped.
- **Ultra Volume**: up to 200 % plus Boost up to +12 dB.
- **Now Playing**: video inside the app with info, chapters, tracks and Up Next.
- **Library**: add folders; Movies, TV Shows, Music, Other; Recently Added; Continue Watching.
- **Playlists**: create, edit, reorder, import and export M3U.
- **Media Details**: tracks, chapters, frames, file facts.
- **Convert**: MP4, MKV, Web, Mobile and MP3 presets with a queue.
- **Edit & Export**: trim, crop, rotate, mirror, remove audio.

## Known limits in this preview

- Trimming starts at the keyframe before your start point.
- Converting files whose audio must be re-encoded can fail on some files (a bug in the VLC 4 development engine). "Keep Original Audio" avoids it.
- The logo is provisional and network browsing (SMB/UPnP) is not built yet.

Pulse is not affiliated with or endorsed by VideoLAN. Playback is powered by libVLC, © VideoLAN and contributors, under the GNU (L)GPL.
