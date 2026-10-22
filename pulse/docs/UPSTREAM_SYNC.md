# Staying in sync with upstream VLC

The goal: every VLC improvement reaches Pulse automatically, without merge
conflicts and without breaking the app.

## Why merges cannot conflict

This repository's `master` started as upstream VLC `master` (commit
`11bcb6f`) and shares its full history. Pulse **only adds** files under
`pulse/` and `.github/`, two paths upstream does not ship. A merge of
upstream therefore never touches a file Pulse changed, so Git resolves it
without conflicts every time.

`tools/check-upstream-clean.sh` enforces this on every push and pull request:
it diffs everything outside the Pulse-owned paths against the last upstream
commit merged into `HEAD` and fails on any difference. It also fails if
upstream ever starts shipping a `pulse/` or `.github/` path.

## Why updates do not break the app

Merging cleanly is not enough: upstream can change the libVLC API (libVLC 4 is
still in development upstream). Three layers stop that from reaching users:

1. **One adapter.** Only `src/engine/*.cpp` calls libVLC
   (`tools/check-engine-boundary.sh`). Screens bind to plain Qt properties on
   `Engine`, `Player` and `VideoOutput`, so an API change is fixed in one place.
2. **Contract tests.** `tests/tst_engine.cpp` exercises the exact behaviour
   Pulse depends on: open, play to the end, seek, pause, start time, error
   reporting, picture and equalizer settings. They run against libVLC built from
   the merged tree.
3. **A gated promotion.** The daily sync merges upstream into a staging branch,
   builds libVLC and Pulse from it, runs the tests and a playback smoke test, and
   only then fast-forwards `master`. If anything is red, `master` stays on the
   last good upstream and an issue named *Upstream VLC update blocked* is
   opened with a link to the failing run.

## The daily sync (`.github/workflows/pulse-upstream-sync.yml`)

```
03:17 UTC daily, or "Run workflow"
  merge    master + upstream/master  →  pulse/upstream-sync (merge commit)
  verify   pulse-ci.yml on pulse/upstream-sync: guards, libVLC build, Pulse build, tests, smoke run
  promote  fast-forward master to pulse/upstream-sync      (only if verify is green)
  report   open/update "Upstream VLC update blocked" issue (only if verify is red)
```

If `master` is protected, allow GitHub Actions to push to it, or change
`promote` to open a pull request instead.

## Doing it by hand

```sh
pulse/tools/sync-upstream.sh          # fetches code.videolan.org/videolan/vlc and merges master
pulse/tools/build-libvlc.sh build-libvlc
cmake --build build-pulse && ctest --test-dir build-pulse
git push
```

## When a core change really is unavoidable

Prefer, in order:

1. a libVLC option passed by the engine (`Engine::Options`, `libvlc_new` arguments);
2. a public libVLC API call in the adapter;
3. a meson build option in `tools/build-libvlc.sh`;
4. a change sent upstream to VideoLAN, so it arrives through the normal sync.

Only if all four are impossible, add a small reviewed patch file under
`pulse/patches/` that the build applies to a copy of the sources, so the
checked-in upstream files stay untouched. There are none today.

## Branding without patching

Product name, version, icon and the network user agent are set at runtime
through `libvlc_set_app_id()` and `libvlc_set_user_agent()` in
`src/engine/engine.cpp`. The stock VLC Qt and skins interfaces are switched
off at build time (`-Dqt=disabled -Dskins2=disabled`), not deleted.
