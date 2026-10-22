#!/usr/bin/env bash
# Pulse — build libVLC from the (untouched) upstream sources in this repository.
#
# The core is built exactly as upstream ships it: Pulse only chooses meson
# options, it never patches sources. The stock VLC Qt and skins interfaces are
# switched off because Pulse provides its own UI.
#
# Usage: pulse/tools/build-libvlc.sh [build-dir] [--profile full|minimal] [-- extra meson args]
#   full    : every feature whose dependencies are installed (desktop builds)
#   minimal : only what the CI smoke tests need (fast, few dependencies)

set -euo pipefail

root="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
build_dir="$root/build-libvlc"
profile="full"
extra=()

while [ $# -gt 0 ]; do
    case "$1" in
        --profile) profile="$2"; shift 2 ;;
        --) shift; extra=("$@"); break ;;
        *) build_dir="$1"; shift ;;
    esac
done

# meson needs an absolute prefix; accept relative build dirs (as CI passes).
build_dir="$(realpath -m "$build_dir")"

common=(
    --prefix="$build_dir/install"
    --buildtype=release
    --libdir=lib
    -Dqt=disabled
    -Dskins2=disabled
    -Dtests=disabled
)

case "$profile" in
    full)
        opts=()
        ;;
    minimal)
        opts=(
            -Dauto_features=disabled
            -Dlua=disabled
            -Dnls=disabled
            -Davcodec=enabled
            -Davformat=enabled
            -Dswscale=enabled
            -Dtaglib=enabled
        )
        ;;
    *) echo "unknown profile: $profile" >&2; exit 2 ;;
esac

if [ -f "$build_dir/build.ninja" ]; then
    meson setup --reconfigure "$build_dir" "$root" "${common[@]}" "${opts[@]}" "${extra[@]}"
else
    meson setup "$build_dir" "$root" "${common[@]}" "${opts[@]}" "${extra[@]}"
fi
ninja -C "$build_dir"
ninja -C "$build_dir" install

pc_dir="$(dirname "$(find "$build_dir/install" -name libvlc.pc | head -n1)")"
echo
echo "libVLC installed to $build_dir/install"
echo "Configure Pulse with:"
echo "  export PKG_CONFIG_PATH=$pc_dir"
