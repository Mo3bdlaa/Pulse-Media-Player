#!/usr/bin/env bash
# Pulse — engine boundary guard.
#
# Only the engine adapter (pulse/src/engine/*.cpp) may talk to libVLC. The UI,
# app services and QML must go through the adapter, so an upstream libVLC API
# change is fixed in one place and never ripples into screens.

set -euo pipefail
cd "$(git rev-parse --show-toplevel)/pulse"

violations="$(grep -rnE '#\s*include\s*[<"]vlc/|libvlc_' src qml tests \
    --include='*.cpp' --include='*.hpp' --include='*.h' --include='*.qml' --include='*.js' \
    | grep -vE '^src/engine/[^/]+\.cpp:' || true)"

if [ -n "$violations" ]; then
    echo "✗ libVLC used outside pulse/src/engine/*.cpp:"
    echo "$violations" | sed 's/^/  /'
    exit 1
fi
echo "✓ libVLC is only used inside the engine adapter."
