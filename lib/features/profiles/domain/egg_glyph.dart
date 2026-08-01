import 'dart:math';

/// How many hues the app-local critter palette holds. AppColors.critterPalette
/// must match (locked by a theme test) — this constant lives here so data and
/// domain code never import the theme layer for a number.
const kCritterPaletteSize = 6;

/// The deterministic geometry behind one egg avatar: a seeded speckle field
/// on the shell, the crack rim the critter peeks over, and the face accents.
/// Pure math (no Flutter types) so the painter and the tests share one source
/// of truth.
class EggGlyph {
  /// Speckle centers in shell-local coordinates (0..1 across the egg's
  /// bounding box, x rightward, y downward), length [speckleCount].
  final List<double> speckleX;
  final List<double> speckleY;

  /// Per-speckle radius as a fraction of the egg's width, each within
  /// [minSpeckleRadius]..[maxSpeckleRadius].
  final List<double> speckleR;

  /// Per-tooth jitter (0..1) for the crack rim's zigzag, length
  /// [crackToothCount] — same seed, same crack.
  final List<double> crackJitter;

  /// Whether the peeking critter grows tiny antennae.
  final bool hasAntennae;

  /// Sideways glance of the eye pair, -1..1 (0 = straight ahead).
  final double eyeShift;

  const EggGlyph({
    required this.speckleX,
    required this.speckleY,
    required this.speckleR,
    required this.crackJitter,
    required this.hasAntennae,
    required this.eyeShift,
  });

  static const speckleCount = 9;
  static const crackToothCount = 5;
  static const minSpeckleRadius = 0.020;
  static const maxSpeckleRadius = 0.055;
}

/// Builds the glyph for [seed]. Same seed, same glyph — the avatar is the
/// profile's stable visual identity, so nothing here may read a clock or
/// shared RNG.
EggGlyph eggGlyphFor(int seed) {
  final rng = Random(seed);

  // Speckles sit on the visible shell (below the crack rim, inside the
  // silhouette) so none is wasted where the painter clips it away.
  final sx = List.generate(
    EggGlyph.speckleCount,
    (_) => 0.15 + rng.nextDouble() * 0.70,
  );
  final sy = List.generate(
    EggGlyph.speckleCount,
    (_) => 0.42 + rng.nextDouble() * 0.48,
  );
  final sr = List.generate(
    EggGlyph.speckleCount,
    (_) =>
        EggGlyph.minSpeckleRadius +
        rng.nextDouble() *
            (EggGlyph.maxSpeckleRadius - EggGlyph.minSpeckleRadius),
  );

  return EggGlyph(
    speckleX: sx,
    speckleY: sy,
    speckleR: sr,
    crackJitter: List.generate(
      EggGlyph.crackToothCount,
      (_) => rng.nextDouble(),
    ),
    hasAntennae: rng.nextBool(),
    eyeShift: rng.nextDouble() * 2 - 1,
  );
}
