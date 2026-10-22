#!/usr/bin/env bash
# Pulse — build the Android app (APK) for one ABI.
#
# Usage: pulse/tools/package-android.sh <libvlc-dir> <qt-android-dir> <qt-host-dir> <out-dir> [version] [version-code]
#   <libvlc-dir>      install/<abi> from tools/build-libvlc-android.sh
#   <qt-android-dir>  Qt for Android, e.g. .../6.8.3/android_arm64_v8a
#   <qt-host-dir>     the matching desktop Qt, e.g. .../6.8.3/gcc_64
# Needs ANDROID_SDK_ROOT (or ANDROID_HOME), ANDROID_NDK_ROOT (or ANDROID_NDK)
# and a JDK. Signs with the keystore in PULSE_ANDROID_KEYSTORE (password in
# PULSE_ANDROID_KEYSTORE_PASS, alias "pulse") or, without one, with a
# throwaway key generated for this build.

set -euo pipefail

vlc="$(realpath "$1")"
qt="$(realpath "$2")"
qthost="$(realpath "$3")"
out="$(realpath -m "$4")"
version="${5:-dev}"
code="${6:-1}"
root="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
sdk="${ANDROID_SDK_ROOT:-${ANDROID_HOME:?set ANDROID_SDK_ROOT}}"
ndk="${ANDROID_NDK_ROOT:-${ANDROID_NDK:?set ANDROID_NDK_ROOT}}"
abi="$(basename "$vlc")"
build="$out/build-$abi"

"$qt/bin/qt-cmake" -S "$root/pulse" -B "$build" -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DQT_HOST_PATH="$qthost" -DANDROID_SDK_ROOT="$sdk" -DANDROID_NDK_ROOT="$ndk" \
    -DPULSE_LIBVLC_DIR="$vlc" -DPULSE_BUILD_TESTS=OFF -DPULSE_ANDROID_VERSION_CODE="$code"
cmake --build "$build" --target apk

unsigned="$(find "$build/android-build" -name '*-release-unsigned.apk' | head -n1)"
[ -n "$unsigned" ] || { echo "no APK produced" >&2; exit 1; }

tools="$(ls -d "$sdk"/build-tools/* | sort -V | tail -n1)"
keystore="${PULSE_ANDROID_KEYSTORE:-}"
pass="${PULSE_ANDROID_KEYSTORE_PASS:-pulse-preview}"
if [ -z "$keystore" ]; then
    keystore="$build/preview.keystore"
    rm -f "$keystore"
    keytool -genkeypair -keystore "$keystore" -storepass "$pass" -keypass "$pass" -alias pulse \
        -keyalg RSA -keysize 3072 -validity 10000 -dname "CN=Pulse preview build" >/dev/null
fi

name="Pulse-$version-android-$abi.apk"
"$tools/zipalign" -f -p 4 "$unsigned" "$build/aligned.apk"
"$tools/apksigner" sign --ks "$keystore" --ks-pass "pass:$pass" --ks-key-alias pulse \
    --out "$out/$name" "$build/aligned.apk"
"$tools/apksigner" verify "$out/$name"
(cd "$out" && sha256sum "$name" > "$name.sha256")
echo "Built $out/$name"
