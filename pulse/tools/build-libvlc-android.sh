#!/usr/bin/env bash
# Pulse — build libVLC for Android from the (untouched) upstream sources in
# this repository, the way upstream CI does (extras/ci/gitlab-ci.yml,
# ".android-common"): VideoLAN's Android image, VideoLAN's libvlcjni build
# script at the commit upstream pins, and the prebuilt third-party libraries
# VideoLAN publishes for this tree's contrib revision.
#
# Usage: pulse/tools/build-libvlc-android.sh [out-dir] [abi]
#   abi: arm64 (default) or x86_64
#   Produces <out-dir>/install/<android-abi>/ with lib/libvlc.so (the core and
#   every module in one library) and include/vlc/.
#
# Needs Docker and network access. The build directories live in the source
# tree (build-android-*, contrib/<triplet>), all git-ignored.

set -euo pipefail

root="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
out="$(realpath -m "${1:-$root/build-libvlc-android}")"
arch="${2:-arm64}"
case "$arch" in
    arm64)  triplet=aarch64-linux-android; abi=arm64-v8a ;;
    x86_64) triplet=x86_64-linux-android;  abi=x86_64 ;;
    *) echo "unsupported abi: $arch" >&2; exit 2 ;;
esac

ci="$root/extras/ci/gitlab-ci.yml"
image="$(sed -n 's/^ *VLC_ANDROID_IMAGE: *//p' "$ci")"
jni_commit="$(sed -n 's/.*cd libvlcjni && git checkout \([0-9a-f]*\).*/\1/p' "$ci")"
contrib_sha="$("$root/extras/ci/get-contrib-sha.sh" "android-$arch" | tail -n1)"
contrib_url=""
for ext in tar.zst tar.bz2; do
    url="https://artifacts.videolan.org/vlc/android-$arch/vlc-contrib-$triplet-$contrib_sha.$ext"
    if curl -fsIL -o /dev/null "$url"; then contrib_url="$url"; break; fi
done
if [ -z "$contrib_url" ]; then
    echo "No prebuilt Android libraries for contrib revision $contrib_sha" >&2
    echo "(artifacts.videolan.org/vlc/android-$arch); merge a newer upstream VLC or build contribs by hand." >&2
    exit 1
fi

mkdir -p "$out"
if [ ! -d "$out/libvlcjni/.git" ]; then
    git clone https://code.videolan.org/videolan/libvlcjni.git "$out/libvlcjni"
fi
git -C "$out/libvlcjni" fetch -q origin "$jni_commit" 2>/dev/null || true
git -C "$out/libvlcjni" checkout -q "$jni_commit"

proxy_env=()
for v in HTTPS_PROXY HTTP_PROXY https_proxy http_proxy NO_PROXY no_proxy; do
    [ -n "${!v:-}" ] && proxy_env+=(-e "$v")
done
extra=()
if [ -n "${PULSE_CA_BUNDLE:-}" ]; then
    extra+=(-v "$PULSE_CA_BUNDLE:/ca.crt:ro" -e SSL_CERT_FILE=/ca.crt -e CURL_CA_BUNDLE=/ca.crt -e GIT_SSL_CAINFO=/ca.crt)
fi
# Optional folder of host tools put first on PATH (e.g. a newer ninja when
# GitHub downloads are blocked).
if [ -n "${PULSE_HOST_TOOLS:-}" ]; then
    extra+=(-v "$PULSE_HOST_TOOLS:/hosttools:ro" -e PULSE_HOST_PATH=/hosttools)
fi

# libvlcjni looks for the VLC sources in libvlcjni/vlc.
docker run --rm --user root --network host "${proxy_env[@]}" "${extra[@]}" \
    -v "$out/libvlcjni:/work/libvlcjni" -v "$root:/work/libvlcjni/vlc" -w /work/libvlcjni \
    -e VLC_PREBUILT_CONTRIBS_URL="$contrib_url" \
    "$image" bash -euo pipefail -c "
        git config --global --add safe.directory '*'
        [ -n \"\${PULSE_HOST_PATH:-}\" ] && export PATH=\"\$PULSE_HOST_PATH:\$PATH\"
        ./buildsystem/build-libvlc.sh -a $arch --release --static-cpp --with-prebuilt-contribs"

dest="$out/install/$abi"
rm -rf "$dest"
mkdir -p "$dest/lib" "$dest/include"
cp "$out/libvlcjni/libvlc/jni/libs/$abi/libvlc.so" "$dest/lib/"
cp -r "$root/build-android-$triplet/install/include/vlc" "$dest/include/"

echo
echo "libVLC for Android ($abi) installed to $dest"
