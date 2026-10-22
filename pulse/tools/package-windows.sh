#!/usr/bin/env bash
# Pulse — package the Windows app: a portable zip and an installer.
#
# Usage (Git Bash on Windows, Qt's bin and MinGW on PATH, Inno Setup installed):
#   pulse/tools/package-windows.sh <libvlc-dir> <pulse-build-dir> <out-dir> [version]
#
# <libvlc-dir> is the folder tools/build-libvlc-windows.sh produces (install/):
# libvlc.dll, libvlccore.dll, plugins\, lua\ and sdk\.

set -euo pipefail

vlc="$(cd "$1" && pwd)"
build="$(cd "$2" && pwd)"
mkdir -p "$3"
out="$(cd "$3" && pwd)"
version="${4:-dev}"
root="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"

stage="$out/Pulse"
rm -rf "$stage"
mkdir -p "$stage"

# --- Pulse and Qt ------------------------------------------------------------
cp "$build/pulse.exe" "$build/pulse-convert.exe" "$stage/"
windeployqt --release --no-translations --compiler-runtime \
    --qmldir "$root/pulse/qml" "$stage/pulse.exe"
windeployqt --release --no-translations --compiler-runtime "$stage/pulse-convert.exe"

# --- libVLC and its plugins --------------------------------------------------
# libVLC looks for plugins\ next to libvlccore.dll.
cp "$vlc"/*.dll "$stage/"
cp -r "$vlc/plugins" "$stage/plugins"
[ -d "$vlc/lua" ] && cp -r "$vlc/lua" "$stage/lua"
if [ -x "$vlc/vlc-cache-gen.exe" ]; then
    "$vlc/vlc-cache-gen.exe" "$stage/plugins" || true
fi

# --- notices -------------------------------------------------------------------
cp "$root/COPYING" "$stage/COPYING.txt"
cp "$root/pulse/packaging/RELEASE_NOTES.md" "$stage/README.txt"

# --- portable zip and installer ----------------------------------------------
name="Pulse-$version-win64"
rm -f "$out/$name.zip"
(cd "$out" && 7z a -tzip -mx=9 "$name.zip" Pulse >/dev/null)
iscc //Q "//DAppVersion=$version" "//DSourceDir=$(cygpath -w "$stage")" "//DOutputDir=$(cygpath -w "$out")" \
    "$(cygpath -w "$root/pulse/packaging/windows/pulse.iss")"

(cd "$out" && sha256sum "$name.zip" > "$name.zip.sha256" && sha256sum "$name-setup.exe" > "$name-setup.exe.sha256")
echo "Built $out/$name.zip and $out/$name-setup.exe"
