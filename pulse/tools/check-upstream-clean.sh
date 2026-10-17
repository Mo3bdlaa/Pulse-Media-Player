#!/usr/bin/env bash
# Pulse — upstream isolation guard.
#
# Pulse is a fork of VLC that never edits upstream files. Everything Pulse owns
# lives under the paths listed in PULSE_OWNED below. This script fails if any
# other path differs from the last upstream VLC commit merged into HEAD, so
# `git merge upstream/master` can always be applied without conflicts.
#
# Usage: pulse/tools/check-upstream-clean.sh [upstream-ref]
#   upstream-ref defaults to "upstream/master" (falls back to "origin/master").

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# Paths Pulse is allowed to own. Keep this list short and never add a path that
# also exists upstream.
PULSE_OWNED=(
    "pulse"
    ".github"
)

ref="${1:-}"
if [ -z "$ref" ]; then
    if git rev-parse --verify -q upstream/master >/dev/null; then
        ref=upstream/master
    else
        ref=origin/master
    fi
fi

if ! git rev-parse --verify -q "$ref" >/dev/null; then
    echo "error: upstream ref '$ref' not found." >&2
    echo "       git remote add upstream https://code.videolan.org/videolan/vlc.git" >&2
    echo "       git fetch upstream master" >&2
    exit 2
fi

# The newest upstream commit already merged into HEAD. Diffing against it (not
# against the tip of upstream) ignores upstream work that is not merged yet.
base="$(git merge-base HEAD "$ref" || true)"
if [ -z "$base" ]; then
    echo "error: HEAD shares no history with '$ref' (shallow clone? try 'git fetch --unshallow')." >&2
    exit 2
fi

excludes=()
for p in "${PULSE_OWNED[@]}"; do
    excludes+=(":(exclude)$p")
done

changed="$(git diff --name-status "$base" HEAD -- . "${excludes[@]}")"

# Owned paths must not collide with anything upstream ships.
collisions=""
for p in "${PULSE_OWNED[@]}"; do
    if git cat-file -e "$ref:$p" 2>/dev/null; then
        collisions+="  $p"$'\n'
    fi
done

status=0
if [ -n "$changed" ]; then
    echo "✗ Upstream files were modified (Pulse must never edit VLC files):"
    echo "$changed" | sed 's/^/  /'
    echo
    echo "  Move the change under pulse/, or, if a core change is truly unavoidable,"
    echo "  add it as a reviewed patch in pulse/patches/ (see pulse/docs/UPSTREAM_SYNC.md)."
    status=1
fi
if [ -n "$collisions" ]; then
    echo "✗ Upstream now ships a path that Pulse owns:"
    printf '%s' "$collisions"
    status=1
fi

if [ "$status" -eq 0 ]; then
    echo "✓ Upstream tree untouched (compared with $(git rev-parse --short "$base") from $ref)."
fi
exit "$status"
