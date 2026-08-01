# 0009 — A miss waits for the child; a correct answer settles

**Status:** Accepted · 2026-08-07

## Context

The first playtest surfaced one complaint in three forms: *"the animations
sometimes get cut a little short… it's kind of sudden to go from stacking eggs
to suddenly just a blank screen except 2×10… and the failure animation is also
cut short."*

Three separate hard cuts were behind it, all of the same shape — a choreography
that ends and, in the same frame, the screen becomes something else:

1. **The filled tray.** `_placeRow` called `constructionComplete()`
   *synchronously* on the last row. The plink, the snap, the phase flip and the
   numpad all landed in one frame, so the tray a child had just built was taken
   away inside the gesture that finished it.
2. **The miss.** `ShortfallOverflow` spends its last 45 % — 810 ms — on the
   actual lesson: the empty wells pulsing, the ghost row sliding in to say *one
   more group*. Then the round advanced on its own. The teaching moment was
   over before a seven-year-old had finished looking at it, and nothing ever
   said what the fact was.
3. **Everything else.** `_stage()` swapped stages with no transition at all, so
   every phase change read as the screen blinking out.

VISION invariant 4 says *misses teach*. A lesson that auto-dismisses in under a
second does not teach; it flickers.

## Decision

**A miss stops the round.** The choreography holds at its last frame, a
`_TruthPanel` states the fact in numerals — `2×10=`**`20`**, the product in
yolk — and the round advances only when the child taps. Nothing is on a timer.

**A correct answer settles.** The sweep runs at its tempo tier, then holds for
`FeedbackStage.correctHold` (420 ms) before advancing. Correct answers still
flow; they are just not snatched away.

**The filled tray gets a beat.** `ConstructStage.settleDuration` (520 ms) sits
between the last row landing and the numpad arriving. The running total swells
once during it — *that is the whole thing* — and the spent dispenser gives way
to a spacer so the tray above does not jump.

**Stages cross-fade.** One `AnimatedSwitcher` at 220 ms, keyed off each stage's
own key. Construct deliberately keeps a single key across building→answering:
the tray lives in that widget's state, and a key change would empty the frame
mid-round.

Two things the explainer is deliberately **not**:

- **Not prose.** The app has never asked a child to read (VISION lists
  localization beyond numerals as unshipped). `2×10=20` and a tap chevron.
- **Not her wrong answer, restated.** The shortfall choreography already showed
  her count against the true frame. Printing the miss back at her buys nothing
  and costs the no-shame rule.

## Consequences

- A frustrated child controls the pace of her own correction. This is the case
  the design has to survive, and the one where an auto-advance is worst.
- Rounds are slower by roughly a tap per miss. Accepted: the miss *is* the
  lesson, and the engine already requires re-retrieval before the round closes.
- Hatch Rush is untouched. Its `teach` phase auto-advances at 1200 ms because
  it is a race against your own ghost; a wait-for-tap there would break the
  one mode whose point is tempo.
- Tests that drove the old flow now settle instead of pumping a single frame,
  and two new ones pin the behaviour: a miss survives ten seconds of a child
  staring at it, and a correct sweep is still on screen when its own duration
  has elapsed.
