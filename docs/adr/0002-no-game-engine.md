# 0002 — No game engine: Ticker + CustomPainter, not Flame

**Status:** Accepted · 2026-08-06

## Context

Hatch is a game, and the Flutter ecosystem's default answer to "game" is
Flame. No OpenHearth app has ever shipped a game engine; adopting one would be
a first-in-fleet dependency reaching every future build. The design's actual
rendering needs: a few dozen animated rectangles, drag/snap gestures, one-shot
tween choreographies, and a painted 11×11 map.

## Decision

No engine. A `Ticker`-driven deterministic update step over plain Dart scene
state, painted by `CustomPainter` layers; draggable tray widgets ride *above*
the painted scene so Flutter's gesture arena handles small-finger slop and the
tap-tap input mode for free; UI chrome is ordinary widgets.

## Consequences

- Everything Flame would add here (camera transform, easing, sprites) is
  already in Flutter; we pay no dependency, no C3 budget weight, no engine ADR.
- Deterministic scene state keeps painters golden-testable — the fleet's
  existing signature-widget discipline (Sundial's face, Furrow's row) applies
  unchanged.
- If a future feature genuinely needs an ECS or sprite batching (it would be a
  different game), that's a new ADR, not a drift.
