# Sound set

All audio is synthesized offline by `tool/sfx/gen.mjs` (jsfxr → ffmpeg →
22 kHz mono OGG). Parameters are frozen in `tool/sfx/params.json` — regenerate
with `node gen.mjs` from `tool/sfx/`; never hand-edit the OGGs. Total ≈ 94 KB.

Three laws (ADR-0003), all tested: sound is never load-bearing (every cue has
a visual twin and the app is fully playable muted); mute is one tap and
honored from cold start; the miss sound is the quietest thing in the set.

| Cue | File | Fires on | Visual twin |
|---|---|---|---|
| plink | plink.ogg | each egg row stacked (pitch rises via the sweep tiers) | row snap + running total |
| snap | snap.ogg | a verb commits (tray placed, seam tapped) | snap squash-and-stretch |
| settle | sew.ogg | correct answer; eggs settle into the tray | cell-fill sweep |
| sweep tiers | sweep_{slow,med,fast}.ogg | the row-by-row crack cascade (1.2 s / 0.8 s / 0.48 s) | CellFillSweep |
| block | block.ogg | round's block completes | stitch flourish + sparks |
| miss | miss.ogg | wrong answer (soft "hm?") | shortfall/overflow teach |
| crack | crack.ogg | hatch moment: shell splits | crack lines |
| hatch | hatch.ogg | hatch moment: critter pops | HatchMoment |
| chirp 1–3 | chirp_{1,2,3}.ogg | a critter says hello | critter micro-animation |
| chime | chime.ogg | family unlock / vignette | unlock shimmer |
| rotate / fold / slice / stamp | *.ogg | their verbs | the verb's choreography |
| rush start | bee_start.ogg | a Hatch Rush begins | caterpillar wakes |

Peak levels: win-family cues sit between −2.9 and −9 dB; miss.ogg peaks at
−13.7 dB. Keep that ordering — the kindness asymmetry is a design law, not a
mixing accident.
