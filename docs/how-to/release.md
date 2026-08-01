# How to release Hatch (PWA + APK)

Pre-release gate, in order — all of it, every time:

1. `dart format lib test packages/mastery_core` then `flutter analyze` —
   zero issues *including infos* (format before analyze; formatting can
   introduce lint findings).
   **Then `git checkout -- test/flutter_test_config.dart`.** That file is a
   canonical fleet template, pinned line-for-line by conformance check C6 so
   goldens render identically across apps; our formatter reflows two of its
   statements and C6 fails on the divergence. It is the one file in the tree
   that must stay un-formatted, and the failure appears only after an APK
   build, long after the format step that caused it.
2. `cd packages/mastery_core && dart test` — the ten laws + the
   simulated-learner shipping gate must be green.
3. `TZ=America/Denver flutter test test/` — full app suite including fleet
   conformance.
4. Golden review: `flutter test --tags golden` locally and *look* at any
   failure images under `test/visual/failures/`.
5. Clean tree, fetched remote.

## PWA

Two steps, and the second is not optional:

```sh
flutter build web --release --base-href "/Hatch/"
dart run tool/patch_service_worker.dart
```

The base-href must be the *published repo name* (`/Hatch/`). The patch fixes
Flutter's generated service worker, which keys its cache off the origin and so
never matches anything under a sub-path — leaving a PWA that installs, looks
healthy, and cannot open offline ([ADR-0008](../adr/0008-service-worker-subpath.md)).
**The fleet script `deploy-pwa.sh` does not patch**; using it alone ships the
defect. Deploy the patched `build/web/` to `gh-pages` (add `.nojekyll`), or run
the script and re-run these two steps over it.

Verify by fetching, not by the build exiting zero:

- the page HTML **and** `main.dart.js` must both return 200 — HTML 200 with
  `main.dart.js` 404 IS the base-href failure mode;
- `flutter_service_worker.js` must contain `const SCOPE_BASE` — its absence is
  the offline failure mode, and it is invisible from the served page.

## APK

Tag `vX.Y.Z` and push; `.github/workflows/release.yml` runs tests, builds
split APKs + AAB, and creates a **draft** release. Remember:

- `/releases/latest/download/...` skips drafts — publish the release or the
  landing-page button 404s.
- versionCode under `--split-per-abi` = ABI offset + pubspec build number
  (arm64 = 2000 + N); the build number must rise or installs-in-place fail;
  add `fastlane/metadata/android/en-US/changelogs/<versionCode>.txt`.
- Verify identity and permissions **from the artifact**:
  `aapt2 dump badging app-arm64-v8a-release.apk` — package
  `com.openhearth.hatch`, and **no** `uses-permission` lines at all.
- After any APK build, re-run `flutter test test/fleet_conformance_test.dart`:
  C4 v2 now sees the merged manifest and pins the true permission surface;
  C3 sees the artifact and enforces `budgets.json`.

## The box rules (small build machine)

One Gradle build *or* one test sweep at a time; stop JVM daemons between
phases (`android/gradlew --stop`); never `flutter clean` (it deletes the
merged manifests C4 reads — use `rm -rf .dart_tool/flutter_build` for the
stale-plugin-registrant disease).
