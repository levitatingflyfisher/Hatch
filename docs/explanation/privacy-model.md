# The privacy model — and how to check it yourself

Hatch's privacy is structural, not promised: **the app has no way to send
anything anywhere.**

## The guarantees

- **Zero Android permissions.** Not just "no INTERNET" — the manifest declares
  no `<uses-permission>` at all. Ads, analytics, tracking, and accounts are
  not policies we refuse; they are code paths that do not exist.
- **All data lives on the device**: a local SQLite database (profiles, the
  answer ledger, engine snapshots) and nothing else.
- **Backups are files you hold**: an encrypted `.ohbk` file exported through
  the system file picker, restored the same way. No relay, no cloud.
- **The poster export** renders on-device and hands a file to the system
  share sheet — where it goes is the parent's choice, made in the OS.
- **No notifications.** The nest never nags. The app cannot wake itself up;
  it has no permission to.

## Check it, don't trust it

```sh
# 1. The manifest declares no permissions:
grep -c "uses-permission" android/app/src/main/AndroidManifest.xml   # → 0

# 2. The shipped APK asks for none (from the artifact, not the source):
aapt2 dump badging Hatch.apk | grep uses-permission                  # → nothing

# 3. No network code in the app:
grep -rE "http|socket" lib/ --include='*.dart' -l                    # → nothing

# 4. And the fleet conformance suite pins all of this as tests:
flutter test test/fleet_conformance_test.dart
```

The conformance check (C4 v2) compares the *merged* release manifest — what
plugins inject, not just what we wrote — against the pinned empty set, so a
future dependency that smuggles in a permission fails the build.

## What the parent view shows — and refuses to

The parent corner shows mastery states (which facts are automatic, growing,
or waiting) — the same picture the child sees. It deliberately never shows
response times or per-answer records (see ADR-0004): speed is an internal
signal for scheduling, not a performance to surveil.
