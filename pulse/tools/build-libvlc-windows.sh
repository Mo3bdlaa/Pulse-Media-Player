#!/usr/bin/env bash
# Pulse — build libVLC for Windows (x86_64) from the (untouched) upstream
# sources in this repository, on Linux, with VideoLAN's own toolchain image and
# the prebuilt third-party libraries VideoLAN publishes for this exact tree.
#
# Usage: pulse/tools/build-libvlc-windows.sh [out-dir]
#   Produces <out-dir>/install laid out like a VLC for Windows folder:
#   libvlc.dll, libvlccore.dll, plugins\, lua\ and sdk\ (include\ and lib\
#   with the import libraries Pulse links against).
#
# Needs Docker and network access. Runs upstream's extras/package/win32/build.sh
# unchanged, as upstream CI builds win64: autotools, libVLC only (-z, Pulse
# is the interface), release mode. (bootstrap writes its generated, git-ignored
# files into the source tree.)

set -euo pipefail

root="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
out="$(realpath -m "${1:-$root/build-libvlc-win64}")"
# The image upstream CI uses for its win64 jobs (extras/ci/gitlab-ci.yml).
image="$(sed -n 's/^ *VLC_WIN64_IMAGE: *//p' "$root/extras/ci/gitlab-ci.yml")"
contrib_sha="$("$root/extras/ci/get-contrib-sha.sh" win64 | tail -n1)"
contrib_url="https://artifacts.videolan.org/vlc/win64/vlc-contrib-x86_64-w64-mingw32-$contrib_sha.tar.zst"

if ! curl -fsIL -o /dev/null "$contrib_url"; then
    echo "No prebuilt Windows libraries for contrib revision $contrib_sha" >&2
    echo "($contrib_url); merge a newer upstream VLC or build contribs by hand." >&2
    exit 1
fi

mkdir -p "$out/build" "$out/hostbin"
# The image runs 32-bit wine only; meson would use it to run its cross sanity
# check. VLC's build never runs target programs, so a stand-in is enough.
printf '#!/bin/sh\nexit 0\n' > "$out/hostbin/wine"
chmod +x "$out/hostbin/wine"
chmod -R a+rwX "$out"

proxy_env=()
for v in HTTPS_PROXY HTTP_PROXY https_proxy http_proxy NO_PROXY no_proxy; do
    [ -n "${!v:-}" ] && proxy_env+=(-e "$v")
done
ca=()
if [ -n "${PULSE_CA_BUNDLE:-}" ]; then
    ca=(-v "$PULSE_CA_BUNDLE:/ca.crt:ro" -e SSL_CERT_FILE=/ca.crt -e CURL_CA_BUNDLE=/ca.crt -e GIT_SSL_CAINFO=/ca.crt)
fi

docker run --rm --user root --network host "${proxy_env[@]}" "${ca[@]}" \
    -v "$root:/vlc" -v "$out:/out" -w /out/build \
    -e VLC_PREBUILT_CONTRIBS_URL="$contrib_url" \
    "$image" bash -euo pipefail -c '
        git config --global --add safe.directory /vlc
        export PATH=/out/hostbin:$PATH
        /vlc/extras/package/win32/build.sh -a x86_64 -p -r -z -o /out/install
        # The package step keeps debug info (1.4 GB); ship stripped binaries.
        find /out/install -maxdepth 3 \( -name "*.dll" -o -name "*.exe" \) -not -path "/out/install/sdk/*" \
            -exec x86_64-w64-mingw32-strip --strip-unneeded {} +'

echo
echo "libVLC for Windows installed to $out/install"
