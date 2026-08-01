# Vision — Hatch

## The one idea

**The times table is a hatchery. Every fact is a tray of eggs the child fills
with her own hands until the fact hatches on its own.**

An incubator tray of eggs *is* an array — the metaphor adds zero
representational distance to the mathematics. So the game's verbs are the
mathematics: stacking rows is skip-counting, folding a tray is doubling,
slicing at a seam is decomposition, rotating a tray into its slot is
commutativity. A child cannot play without doing the math, and the math she
does is the strategy set researchers actually recommend (Kling &
Bay-Williams derived-fact sequence, Baroody's counting → deriving →
automaticity arc, Concrete–Pictorial–Abstract weaning).
The engine underneath is a mastery scheduler: prerequisite-gated families,
expanding-interval spaced retrieval on a calendar-day clock, interleaved review,
and an automaticity criterion of *correct and fast* — with speed measured
invisibly. There is no countdown, no streak, no shame anywhere in the app.

The name: when a fact turns automatic it *hatches* — the tray the child built
cracks open into a critter she keeps, and the Album fills with everything she
has raised.

## Invariants (each one is a test, or it is a wish)

1. **Zero Android permissions.** No INTERNET above all: ads, tracking, and
   accounts are architecturally impossible, not policy-refused. Pinned both
   directions by fleet conformance (C4), source and merged manifest.
2. **Production-only automaticity.** A fact is "automatic" only on fast,
   *typed* recall, sustained across 3+ distinct calendar days — never from
   recognition among choices, never from a binge session (engine laws 1–3, 10).
3. **The refuse-list is structural.** No streaks, daily rewards, energy,
   appointment mechanics, decay, locked-content teasing, notifications, or
   public comparison. The Album shows everything from minute one.
4. **Misses teach.** A wrong answer renders as shortfall/overflow against the
   true array, then the same fact must be re-retrieved before the round closes.
   The miss sound is quieter than the win sound.
5. **Interruption is the normal case.** Every gesture commits; killing the app
   mid-tray loses nothing.
6. **The engine is pure.** `packages/mastery_core` imports no Flutter and tells
   time only through explicit parameters — every pedagogical law is a unit test,
   and simulated learners gate shipping.

## The honest scorecard

**Real, tested, load-bearing:**
- The mastery engine: placement probes, calendar-day expanding spaced retrieval,
  interleaved round assembly, rung ladder with downward transitions, strategy
  re-teach on chronic misses, commutativity fold with mirror confirmation —
  each of the ten engine laws has a dedicated test, and simulated learners
  verify time-to-mastery bounds before any release.
- Zero-permission APK; local-only data; `.ohbk` encrypted backup/restore.
- The full multiplication 0–10 curriculum in the Kling & Bay-Williams order,
  with all six derived-fact strategy routes taught explicitly.

**True but modest — say it plainly:**
- The evidence ceiling: spacing helps math (meta-analytic g ≈ 0.28); intrinsic
  integration beats bolted-on quizzing (d ≈ 0.74 in the best experiment; kids
  chose the integrated game 7× longer in free play); but the closest
  large-scale exemplar (ST Math, 16k students) moved achievement < 0.1 SD.
  Expect a *well-taught fact course*, not a miracle.
- The retrieval-practice literature specific to math is thinner than its
  reputation (g ≈ 0.18, CI crossing zero) — this design leans on spacing,
  mastery gating, and intrinsic integration, which are better supported.
- The engagement claim is "the ten-minute dose she never resists and sometimes
  picks up unprompted" — not "beats Subway Surfers." A no-dark-patterns app
  refuses the weapons that claim would need.

**Aspirational — documented, not shipped:**
- Weaning thresholds, gesture feel, and juice tuning are unvalidated until real
  children play; simulated learners are the pre-child gate, not a substitute.
- Other topic packs (division is nearly free; addition/subtraction for younger
  siblings) — the engine is topic-generic for *fact fluency*; fractions would
  need a different mastery criterion and is deliberately not claimed.
- iOS; 11s/12s; localization beyond numerals.

## Roadmap (problems, not dates)

- **The week-6 problem:** does variety-within-sameness (rung mix, direction
  flips, ghost races, critter palette) carry a child through the ×6/×7/×8
  residue, or does the long tail need round modifiers? Only real play answers.
- **The sibling problem:** two children, one device, different frontiers —
  placement handles entry, but does the shared Album stay shame-free?
- **The division inversion:** the same trays asked backwards ("56 eggs,
  8 rows — how wide?") as the first extension pack, exercising the engine's
  topic-generality for real.
- **The addition valley:** number-bond strips for a pre-reader sibling — same
  ladder, same scheduler, simpler toy.
