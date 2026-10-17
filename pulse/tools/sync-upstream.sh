#!/usr/bin/env bash
# Pulse — merge the latest upstream VLC into the current branch.
#
# Because Pulse never edits upstream files, this merge is conflict-free by
# construction. The script still verifies that, and leaves the build and test
# gate to the caller (CI runs pulse/tools/build-libvlc.sh and the Pulse tests
# before the merge is published).
#
# Usage: pulse/tools/sync-upstream.sh [--remote URL] [--branch master]

set -euo pipefail

remote_url="https://code.videolan.org/videolan/vlc.git"
branch="master"
while [ $# -gt 0 ]; do
    case "$1" in
        --remote) remote_url="$2"; shift 2 ;;
        --branch) branch="$2"; shift 2 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

cd "$(git rev-parse --show-toplevel)"

if [ -n "$(git status --porcelain)" ]; then
    echo "error: working tree is not clean." >&2
    exit 2
fi

if git remote get-url upstream >/dev/null 2>&1; then
    git remote set-url upstream "$remote_url"
else
    git remote add upstream "$remote_url"
fi

if [ "$(git rev-parse --is-shallow-repository)" = "true" ]; then
    git fetch --unshallow origin || true
fi
git fetch --no-tags upstream "$branch"

before="$(git rev-parse HEAD)"
if git merge-base --is-ancestor "upstream/$branch" HEAD; then
    echo "Already up to date with upstream/$branch."
    exit 0
fi

new_commits="$(git rev-list --count HEAD.."upstream/$branch")"
echo "Merging $new_commits new upstream commit(s) from upstream/$branch…"

git -c user.name="${GIT_AUTHOR_NAME:-Pulse Upstream Sync}" \
    -c user.email="${GIT_AUTHOR_EMAIL:-pulse-sync@users.noreply.github.com}" \
    merge --no-edit --no-ff -m "Merge upstream VLC ($branch @ $(git rev-parse --short "upstream/$branch"))" \
    "upstream/$branch"

pulse/tools/check-upstream-clean.sh "upstream/$branch"

echo "Merged $before..$(git rev-parse HEAD)."
