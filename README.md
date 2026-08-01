# Hatch

**Where times tables hatch.**

> The multiplication table is a hatchery, and every fact is a tray of eggs a
> child fills with her own hands — stacking rows, folding to double, slicing a
> row off ten — until the fact hatches into a critter of its own. Local-first,
> no accounts, no ads, no network: the APK requests **zero permissions**. See
> **[VISION.md](VISION.md)**.

Hatch teaches multiplication the way the research says it sticks — a
mastery ladder from counting, through derived-fact strategies, to fast recall,
scheduled by expanding-interval spaced retrieval — inside a game where the
math *is* the mechanic: an incubator tray of eggs is literally an array,
doubling is literally folding a tray, and commutativity is literally rotating
one into its slot.

- **The Nursery** — build each fact as an egg tray: stack rows (skip-counting
  aloud), fold to double, slice at the five-anchor, rotate to fit. Strategies
  are taught wordlessly, with the child's own mastered trays.
- **Hatch Rush** — sub-minute speed rounds against your own best run. Speed
  is measured invisibly; there is no countdown, no shame, ever.
- **The Album** — the whole 0–10 table as a critter album (an 11×11 grid, 66
  facts once commutativity folds it), visible from minute one. Eggs mature as
  facts do; a sleepy critter shows what wants a visit.
- **Habitats** — hatched critters, homed. The child arranges them herself;
  export a printable poster to show grandma. Earned purely by mastery: no
  streaks, no timers, no teasing.

## Try it

- **Web (PWA)** — <https://levitatingflyfisher.github.io/Hatch/>. Add it to
  your home screen; after the first visit it opens with no network.
- **Android** — [sideload APK](https://github.com/levitatingflyfisher/Hatch/releases/tag/v0-apk).
  Take `Hatch-arm64-v8a.apk` for any phone since ~2017; `Hatch.apk` is the
  universal build.

## Run it

```sh
flutter pub get
flutter run            # Android device/emulator or -d chrome
flutter test           # full suite, including fleet conformance
```

Ships as a web PWA and an Android APK. Requires Flutter 3.38.7.

## Documentation

- **[VISION.md](VISION.md)** — the one idea, the invariants, the honest scorecard.
- **[AGENTS.md](AGENTS.md)** — the map for anyone (human or agent) working in this repo.
- **[docs/](docs/README.md)** — the documentation hub: how the pedagogy works,
  architecture, decisions ([docs/adr/](docs/adr/)), and the strategic case
  ([docs/whitepaper.md](docs/whitepaper.md)).

## License

[MIT](LICENSE). Fonts (Lora, Nunito) under the [SIL OFL](assets/fonts/OFL.txt).
