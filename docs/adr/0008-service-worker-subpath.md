# 0008 — Patch the generated service worker for sub-path deploys

**Status:** Accepted · 2026-08-07

## Context

The PWA ships to a GitHub Pages *project* site, so it is served from a
sub-path: `https://levitatingflyfisher.github.io/Hatch/`, built with
`--base-href "/Hatch/"`.

Flutter's generated `flutter_service_worker.js` computes each cache key by
slicing the request URL against **`self.location.origin`**, while the
`RESOURCES` manifest it looks the key up in is keyed **relative to the
worker's own directory**. At an origin root the two are the same string and
the mismatch is invisible. Under a sub-path they diverge: a request for
`/Hatch/main.dart.js` produces the key `Hatch/main.dart.js`, `RESOURCES[key]`
is `undefined`, and the fetch handler takes its "not ours — let the browser
take over" early return. For every request. Including the navigation, which
therefore never reaches the `onlineFirst` branch and is never cached at all.

The failure is silent and flattering: the PWA installs, `navigator.serviceWorker
.controller` is set, the five CORE files really are in `caches`, Lighthouse is
happy. It simply cannot open with the network gone — verified by serving the
build locally, letting the worker take control, killing the server, and
reloading (`ERR_CONNECTION_REFUSED`, no cached response). That is precisely the
case a local-first app for a child in a car exists to handle.

Waiting for upstream was rejected: the app is being playtested now, and the
defect costs the app its core promise.

## Decision

`tool/patch_service_worker.dart` post-processes the built worker: prepend a
`SCOPE_BASE` derived from `self.location.href` (the worker's own directory) and
rebase every origin-keyed lookup on it. At the origin root `SCOPE_BASE` equals
the origin, so this is a strict generalisation of upstream's behaviour rather
than a fork of it.

It runs after **every** `flutter build web`, and three things keep that honest:

- The patch is idempotent (re-running is a no-op), so it is safe in any script.
- It **throws** if Flutter's generator stops matching its anchors, rather than
  no-opping — a shape change must stop a deploy, because the failure it guards
  against only shows up in a dead zone.
- `test/web_service_worker_test.dart` fails when `build/web/` exists and is
  unpatched. Artifact-conditional like the C3 size ratchet: a plain
  `flutter test` with no web build still passes.

## Consequences

- The PWA opens offline after one online visit — re-verified with the same
  kill-the-server harness that found the bug.
- The deploy is two commands, not one; `docs/how-to/release.md` carries both.
  The fleet script `deploy-pwa.sh` does **not** patch, so deploying Hatch
  through it alone reintroduces the defect.
- Every other Flutter PWA in the fleet served from a Pages project sub-path has
  the same defect (confirmed by fetching their live workers). Propagating the
  fix is out of scope for this repo and left as a fleet decision.
- A Flutter upgrade can require re-reading the generated worker. That cost is
  accepted; the alternative is an app that lies about being local-first.
