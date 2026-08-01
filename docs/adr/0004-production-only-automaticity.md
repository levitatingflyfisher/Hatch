# 0004 — Automaticity credit: production-only, calendar-day spacing, invisible latency

**Status:** Accepted · 2026-08-06

## Context

Three research findings collide here. (1) Automaticity — the point of fact
fluency — is *fast correct recall*, which requires measuring speed. (2) The
"timed tests cause math anxiety" claim is far weaker than its reputation
(neither of the two experimental tests concluded it; practice testing
*reduces* test anxiety, g ≈ −0.52; weak skill precedes anxiety, not the
reverse) — but visible countdowns and public comparison are still affectively
corrosive and are refused by fleet law regardless. (3) Recognition among
choices is weaker retrieval than production, and a child can be "automatic"
at picking 56 from {48, 54, 56} yet stall on a cold "7×8 = ?". Separately,
session-counted spacing lets a rainy-Saturday binge collapse an expanding
schedule into one afternoon and certify massed practice as durable memory.

## Decision

- Automaticity evidence comes **only** from production answers (numpad-typed),
  fast under an invisible latency bound (≈2.5 s, normalized by a motor baseline
  learned from the child's own fastest reliable answers).
- The spacing clock counts **calendar days**: intervals 1 → 3 → 7 → 14 → 30
  days (per-fact speed multiplier), and "automatic" requires success on 3+
  distinct days. Being overdue is never penalized — nothing decays.
- No countdown, timer bar, or latency figure is ever rendered. Choice-button
  events (early rungs, pre-readers) advance rungs but can never fire a fact.

## Consequences

- A binge session is fun and useful (it plants and practices) but cannot
  counterfeit durability — the calendar does the certifying.
- The engine must track per-event latency and per-child baselines; both are
  invisible in the UI by construction, so no future "stats screen" may surface
  per-answer speed to the child (parent heatmap shows mastery states only).
- These rules are engine laws 2–3 in `packages/mastery_core/test/`.
