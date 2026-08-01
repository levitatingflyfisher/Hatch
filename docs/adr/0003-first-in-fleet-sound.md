# 0003 — Ship sound (first in fleet), under three laws

**Status:** Accepted · 2026-08-06

## Context

No OpenHearth app ships audio. The fleet's silence is principled in its other
apps (no engagement traps), but for a children's game the research is clear:
"juice" — cascading audiovisual feedback on the child's *own action* — is the
ethically clean engagement mechanic, and sound is half of it. The skip-count
plink ladder is also pedagogically load-bearing feedback (counting made
audible), which silence cannot replace. Meanwhile, audio plugins add native
code and (on some platforms) latency, and the fleet's no-permissions posture
must survive the dependency.

## Decision

Ship sound via `audioplayers` (FLOSS, injects no Android permissions —
verified against the merged manifest by C4), with assets synthesized offline
by `tool/sfx/gen.mjs` (jsfxr → ffmpeg → OGG, ~94 KB total, parameters frozen
in `params.json` for reproducibility). Three laws, each enforced:

1. **Never load-bearing.** Every audio cue has a visual twin; the app is fully
   playable silent (tested).
2. **Mute is one tap and survives cold start** (persisted, tested).
3. **Kindness asymmetry.** The miss sound is quieter and softer than the win
   sound. No buzzer exists in the asset set.

Arpeggio sweeps are pre-rendered clips at three tempo tiers — never fired as
individual notes at runtime, which stutters on web trigger latency. Web audio
unlocks on the first user gesture (autoplay policy).

## Consequences

- First-in-fleet precedent: any future fleet app wanting audio starts from
  these three laws and this pipeline.
- The asset pipeline is code (`tool/sfx/`), so sounds are regenerated, never
  hand-edited; `params.json` is the source of truth.

## Postscript — 2026-08-07: law 1 has a cost

The first playtest reported no sound at all. Every cue had been a no-op since
the day audio landed, because `audioServiceProvider` read the mute flag with a
bare `ref.read` on an auto-dispose stream provider: no subscription, nothing
keeping it alive, so each check rebuilt it, found `AsyncLoading`, and fell
through to the safe default — muted.

Law 1 is what made it invisible. A never-load-bearing subsystem that fails
looks exactly like a working one with the volume down: no exception, no log,
no failing test, and a mute default that is *correct* in isolation. Silence
cannot be the only symptom of broken audio, so
`test/core/audio_mute_wiring_test.dart` and `AudioService.muted` exist to make
the state assertable. The law stands; it just needs a witness.
