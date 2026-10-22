#!/usr/bin/env bash
# Pulse — package a Linux AppImage: Pulse + pulse-convert + libVLC (with its
# plugins) + Qt and every library they need, in one file that runs without
# installing anything.
#
# Usage: pulse/tools/package-linux.sh <libvlc-install-dir> <pulse-build-dir> <out-dir> [version]
#
# Needs network access the first time (downloads linuxdeploy and its Qt
# plugin into <out-dir>/tools). Runs without FUSE.

set -euo pipefail

vlc="$(realpath "$1")"
build="$(realpath "$2")"
out="$(realpath -m "$3")"
version="${4:-$(git -C "$(dirname "$0")" describe --tags --always 2>/dev/null || echo dev)}"
root="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
arch="$(uname -m)"

mkdir -p "$out/tools"
appdir="$out/AppDir"
rm -rf "$appdir"

fetch() {
    [ -x "$out/tools/$1" ] && return
    curl -fsSL -o "$out/tools/$1" "$2"
    chmod +x "$out/tools/$1"
}
fetch linuxdeploy "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-$arch.AppImage"
fetch linuxdeploy-plugin-qt "https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-$arch.AppImage"
export APPIMAGE_EXTRACT_AND_RUN=1 PATH="$out/tools:$PATH"

# --- Pulse -------------------------------------------------------------------
install -Dm755 "$build/pulse" "$appdir/usr/bin/pulse"
install -Dm755 "$build/pulse-convert" "$appdir/usr/bin/pulse-convert"
install -Dm644 "$root/pulse/packaging/linux/org.pulse.Player.desktop" "$appdir/usr/share/applications/org.pulse.Player.desktop"
install -Dm644 "$root/pulse/assets/logo/pulse-mark.svg" "$appdir/usr/share/icons/hicolor/scalable/apps/org.pulse.Player.svg"

# --- libVLC and its plugins ----------------------------------------------------
libdir="$(dirname "$(find "$vlc" -name 'libvlc.so' | head -n1)")"
mkdir -p "$appdir/usr/lib"
cp -a "$libdir"/libvlc.so* "$libdir"/libvlccore.so* "$appdir/usr/lib/"
cp -a "$libdir/vlc" "$appdir/usr/lib/vlc"
# The plugins cache speeds up the first start; build it when the tool exists.
if [ -x "$libdir/vlc/vlc-cache-gen" ]; then
    "$libdir/vlc/vlc-cache-gen" "$appdir/usr/lib/vlc/plugins" || true
fi

# Tell the core where its plugins live inside the AppImage.
mkdir -p "$appdir/apprun-hooks"
cat > "$appdir/apprun-hooks/pulse-vlc.sh" <<'EOF'
export VLC_PLUGIN_PATH="$APPDIR/usr/lib/vlc/plugins"
EOF

# --- Qt, QML and system libraries -------------------------------------------
export QML_SOURCES_PATHS="$root/pulse/qml"
export QMAKE="${QMAKE:-$(command -v qmake6 || echo /usr/lib/qt6/bin/qmake)}"
export EXTRA_QT_PLUGINS="svg;waylandcompositor"
export EXTRA_PLATFORM_PLUGINS="libqwayland-egl.so;libqwayland-generic.so"
export LDAI_OUTPUT="$out/Pulse-$version-$arch.AppImage"
export LDAI_UPDATE_INFORMATION=""

plugins=()
while IFS= read -r -d '' so; do plugins+=(--deploy-deps-only "$so"); done \
    < <(find "$appdir/usr/lib/vlc/plugins" -name '*.so' -print0)

linuxdeploy --appdir "$appdir" \
    --executable "$appdir/usr/bin/pulse" \
    --executable "$appdir/usr/bin/pulse-convert" \
    --library "$appdir/usr/lib/libvlc.so" \
    --desktop-file "$appdir/usr/share/applications/org.pulse.Player.desktop" \
    --icon-file "$appdir/usr/share/icons/hicolor/scalable/apps/org.pulse.Player.svg" \
    "${plugins[@]}" \
    --plugin qt \
    --output appimage

(cd "$out" && sha256sum "$(basename "$LDAI_OUTPUT")" > "$(basename "$LDAI_OUTPUT").sha256")
echo "Built $LDAI_OUTPUT"
