# Working in Hatch — the map

For whoever opens this repo next, person or agent.

> **The grain-of-salt law.** Nearly every line here was written by an AI
> assistant. Treat code and comments as an accurate record of what currently
> exists — not a spec, not guaranteed correct. When docs, comments, tests and
> reality disagree: **reality > tests > code > comments > prose docs.** Verify
> before you rely.

## Read in this order

1. [README.md](README.md) — what this is, how to run it
2. [VISION.md](VISION.md) — the one idea, the invariants, the honest scorecard
3. this file — where things are, how to work
4. [docs/README.md](docs/README.md) — the documentation hub
5. [docs/adr/](docs/adr/) — why the load-bearing decisions were made. Read the
   relevant ADR **before** re-litigating a choice.

## Non-negotiables

- **Zero Android permissions.** Do not add one. If a dependency injects one,
  the merged-manifest conformance check (C4 v2) will fail — that failure is
  correct; remove the dependency, don't record the permission.
- **The refuse-list** (VISION invariant 3) is not a style preference. No
  streaks, timers, energy, teasing, notifications, comparison. A feature that
  needs them is a feature this app doesn't have.
- **`packages/mastery_core` stays pure Dart** — no Flutter imports, time only
  via explicit parameters. Every pedagogical rule in it must be a failing test
  before it is code. The ten engine laws live in
  `packages/mastery_core/test/` with their law numbers in the test names.
- **TDD everywhere else too**: reproduce → failing test → fix → green → commit.
- **Never commit** `CLAUDE.md`, `docs/superpowers/`, `*.g.dart`,
  `test/visual/failures/`. `AGENTS.md` (this file) IS committed.
- Commits use the repo's neutral persona; no AI-authorship trailers, ever.

## Where things are

| You're touching | Go to |
|---|---|
| Pedagogy rules, scheduling, mastery, placement | `packages/mastery_core/` (pure Dart; contract in `docs/explanation/pedagogy.md`) |
| The egg-tray/game screens | `lib/features/nursery/`, `lib/features/rush/` |
| The Album map / parent view | `lib/features/album/` |
| Habitats, poster export | `lib/features/habitats/` |
| Profiles (4 max, egg avatars) | `lib/features/profiles/` |
| Backup (.ohbk), settings, mute | `lib/features/settings/`, `lib/features/sanctuary_backup/` |
| Theme, critter palette, painters shared across features | `lib/shared/` |
| Drift schema (profiles, answer_events, engine_snapshots) | `lib/core/storage/` |
| Sounds (regenerate, don't hand-edit) | `tool/sfx/gen.mjs` → `assets/audio/` |
| Icons (regenerate, don't hand-edit) | `tool/icon_gen/` → `assets/icon/`, `web/icons/` |
| Fleet posture & recorded divergences | `test/fleet_conformance_test.dart` |
| Size budgets | `budgets.json` (ratchet deliberately, never zero) |

## How to work here

- Toolchain: Flutter **3.38.7** exactly (CI pins the literal; C6 checks it).
- Codegen: `dart run build_runner build --delete-conflicting-outputs` after
  touching riverpod/drift annotations. `*.g.dart` is gitignored — never commit it.
- Tests: `flutter test test/` runs everything including fleet conformance.
  Golden tests are tagged `golden` and excluded in CI — run them locally when
  touching any painter, and look at the failures with your eyes.
  Engine tests: `cd packages/mastery_core && dart test`.
- One heavy build at a time on a small box; never `flutter clean` (it deletes
  the merged manifests C4 reads — use `rm -rf .dart_tool/flutter_build` for
  the stale-plugin-registrant disease).
- The web build needs `--base-href "/Hatch/"` for Pages deploys; a wrong
  base-href builds green and serves a blank page. Then always
  `dart run tool/patch_service_worker.dart` — unpatched, the PWA installs,
  looks healthy, and cannot open offline
  ([ADR-0008](docs/adr/0008-service-worker-subpath.md)).

## The shape of the thing

`mastery_core` decides *what to ask and when* (rounds, rungs, scheduling);
the app decides *how it looks and feels* (eggs, critters, juice) and owns
persistence (Drift). The engine is fed `AnswerEvent`s and snapshots back out;
it never touches a database or a widget. If you find pedagogy logic in a
widget or rendering logic in the engine, that's a bug in layering — move it.
