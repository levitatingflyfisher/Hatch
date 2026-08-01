# mastery_core — the engine contract

`packages/mastery_core` is the pure-Dart pedagogy engine. The app feeds it
`AnswerEvent`s and persists its snapshots; it decides what to ask and when.
No Flutter imports, no I/O, no wall-clock reads — time arrives only as
`event.at` / explicit `now` parameters. Every rule below is enforced by a
test in `packages/mastery_core/test/` (the law number appears in the test
name); the tuned defaults live in `EngineTuning` with doc comments.

## Types

- `Fact` — canonical folded fact, `0 ≤ a ≤ b ≤ 10` (66 facts). `product`,
  `id` (`'3x8'`), `folded`, `parse`, `isSquare`.
- `AskDirection` — `forward` (shown a×b) / `reversed` (shown b×a).
- `Phase` — `counting → derived → automatic` (derived from evidence, never
  stored).
- `Rung` — CPA weaning ladder: `grid → bundled → labeled → bare`.
- `Family` — `x0…x10, squares`. `MultiplicationPack` exposes the sequence,
  `ownerOf(fact)`, `gateFor(family)`, `routesFor(family)`, `componentFact`.
- `StrategyRoute` — `skipCount, foldDouble, addAGroup, trimAGroup,
  fiveAnchorSplit, nearSquare`.
- `AnswerEvent` — fact, direction, kind (`probe | construct |
  vignettePractice | review | bee | remediation`), rung, `correct`,
  `latencyMs?`, `production` (only production events can earn automaticity
  credit), `at`.
- `RoundSpec` / `RoundEventSpec` — assembled rounds; choice distractors are
  interference-aware (neighbor products + classic confusions).
- `RecordResult` — rung moves, `factFired`, `familiesUnlocked`,
  `mirrorPlanted`, `requeue`, `offerStrategySwitch`, `prerequisiteProbe`.
- `SamplerView` / `SamplerCell` — per-fact display state for the Album.
- `VignetteSpec` — which strategy lesson is due, anchored on a fact the
  child already owns.

## MasteryEngine

```dart
MasteryEngine.fresh({DateTime? now, EngineTuning tuning});
MasteryEngine.fromSnapshot(Map<String, Object?> snapshot);
Map<String, Object?> snapshot();          // versioned JSON round-trip (law 9)
RoundSpec assembleRound(RoundIntent intent, {required DateTime now});
RecordResult record(AnswerEvent event);   // pure, idempotent per event
SamplerView samplerView({required DateTime now});
FamilyStatus familyStatus(Family family); // locked / vignetteDue / open
VignetteSpec? nextVignette();
void markVignetteComplete(Family family, {required DateTime now});
EngineStats stats({required DateTime now});
List<Fact> get pendingRequeues;           // law-8 closure debt
```

## The ten laws (summaries — the tests are the authority)

1. Placement: fresh engines interleave bare production probes; fast+correct
   instantiates at `bare`, 2 spaced confirmations (distinct days) grant
   `automatic`; probe evidence unlocks families (frontier in session one).
2. The spacing clock is calendar days: same-session → 1 → 3 → 7 → 14 → 30,
   per-fact speed multiplier; overdue is never penalized.
3. Fast = latency within the automaticity bound (~2.5 s) normalized by a
   per-child motor baseline; recognition never contributes.
4. Mastering a×b auto-plants b×a at `labeled`; one confirmed fast production
   of the mirrored direction fills the mirror. Squares are their own mirror.
5. Downward transitions: miss demotes a rung; 3 consecutive misses offer a
   strategy switch; 4 lapses re-open the family vignette; 5 probe the
   strategy-source component fact.
6. Unlock: sequence predecessor AND strategy source(s) at ≥80% automatic
   with the remainder ≥ derived; ×6 accepts (×3 OR ×5).
7. Piecing rounds mix ~60% due review (family-interleaved) / ~25% frontier /
   ~15% recent-miss at ~85% expected success; bee rounds are 10–16 fast
   events, bare-dominant, alternating directions.
8. A miss opens a requeue debt closed only by successful re-retrieval.
9. Snapshot round-trip preserves behavior (property-tested over seeded
   histories through real JSON).
10. Shipping gate: median simulated learner masters all 66 facts in
    4.3–5.8 play-hours (< 25 h bound) across 42–65 calendar days; a child
    who knows ×0/×1/×2/×5/×10 reaches the ×4 frontier in one session.

## Resolved ambiguities worth knowing

- The `squares` family owns no scheduled facts — each n×n belongs to family
  ×n (`isSquare` drives the Album's crowned rendering); `squares` is the
  nearSquare strategy stage, gated on ×5.
- Correct-but-slow probes instantiate at `labeled` (she produced it, just
  not automatically); only incorrect probes count toward placement coldness.
- Probe-satisfied families skip their vignette; lapse-re-owed vignettes are
  sticky.
- `markVignetteComplete` on a locked family throws `StateError`.
