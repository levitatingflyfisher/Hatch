# 0007 — The engine is a pure-Dart in-repo package

**Status:** Accepted · 2026-08-06

## Context

The pedagogy engine is the correctness-critical core: ten semantic laws
(placement, day-clock spacing, production-only credit, downward transitions,
unlock gating…) that must each be a test, plus simulated-learner bounds that
gate shipping. Logic like this dies when it leaks into widgets: it becomes
untestable, time-coupled, and unportable to the next topic pack. The fleet
precedent is eloEngine — pure Dart, extraction-ready.

## Decision

`packages/mastery_core` is its own package inside this repo. It imports no
Flutter (structurally enforced — the package's pubspec has no Flutter
dependency, so a `package:flutter` import cannot resolve), tells time only
through explicit `now`/`event.at` parameters, performs no I/O, and holds no
randomness that isn't seeded. The app feeds it `AnswerEvent`s and persists its
snapshots; Drift and widgets stay on the app side of the seam.

## Consequences

- Every pedagogical rule is unit-testable at Dart speed; simulated learners
  run thousands of sessions in seconds.
- The engine can be extracted to a shared fleet package unchanged when a
  second app (or the division pack) wants it.
- The seam is also the review discipline: pedagogy logic found in a widget, or
  rendering concerns found in the engine, are layering bugs by definition
  (see AGENTS.md).
