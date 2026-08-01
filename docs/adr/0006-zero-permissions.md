# 0006 — Zero Android permissions

**Status:** Accepted · 2026-08-06

## Context

OpenHearth's privacy stance is structural: the best guarantee is one with no
code path to violate. Eight fleet apps ship without INTERNET; Hatch can
go further — a children's app is exactly where "no ads, no tracking, no
accounts" must be architecture, not policy, because the user cannot audit a
policy. Notifications were considered (practice reminders) and refused: the
hatchery never nags (fleet family-focus law). Haptics via `HapticFeedback`
require no permission.

## Decision

The manifest declares **no** `<uses-permission>` at all. Fleet conformance C4
pins the empty set in both directions, and C4 v2 checks the release *merged*
manifest so a dependency that injects a permission fails the build. If a
future dependency needs a permission, the dependency is wrong, not the pin.

## Consequences

- Ads, IAP, telemetry, and cloud anything are impossible, checkably.
- Backup/restore is file-based (`.ohbk` via the system file picker); poster
  export rides the system share sheet. Neither needs a permission on
  minSdk 24+.
- The store listing may truthfully say "asks for no permissions," and C4
  verifies the listing against the manifest.
