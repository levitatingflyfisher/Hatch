import 'dart:ui';

import 'package:mastery_core/mastery_core.dart';

import '../scene/seeded.dart';
import '../theme/app_colors.dart';

/// Body silhouette per owning family (RESKIN_SPEC): the species IS the
/// family's face, so a child recognizes "a nines critter" before reading
/// anything. Squares are not a species — they overlay a crown on the owning
/// family's silhouette ([CritterSpec.crowned]).
enum CritterSpecies {
  bubbleGhost, // x0
  pebble, // x1
  bouncyBlob, // x2
  sproutAntenna, // x3
  winged, // x4
  starBellied, // x5
  fuzzyOval, // x6
  zigzag, // x7
  doubleDecker, // x8
  spiky, // x9
  tallStacker, // x10
}

/// Seeded accessory family; twins share the accessory, mirrored.
enum CritterAccessory { spots, stripes, brows, blush }

/// Deterministic visual parameters for a fact's critter. Same fact always
/// hatches the same critter (goldens + child recognition both depend on it).
class CritterSpec {
  const CritterSpec._({
    required this.fact,
    required this.species,
    required this.hue,
    required this.crowned,
    required this.mirrored,
    required this.seed,
    required this.accessory,
  });

  /// [mirrored] selects the twin (the b×a ordering): same body, same hue,
  /// same accessory — flipped, so twins read as siblings facing each other.
  factory CritterSpec.of(Fact fact, {bool mirrored = false}) {
    const pack = MultiplicationPack();
    final owner = pack.ownerOf(fact);
    final ownerFactor = _factorOf(owner);
    final other = fact.a == ownerFactor ? fact.b : fact.a;
    final seed = seedFor(fact.a, fact.b);
    return CritterSpec._(
      fact: fact,
      species: speciesForFamily(owner),
      hue: AppColors.critterPalette[other % AppColors.critterPalette.length],
      crowned: fact.isSquare,
      mirrored: mirrored,
      seed: seed,
      accessory: CritterAccessory
          .values[seededPick(seed, 0, CritterAccessory.values.length)],
    );
  }

  final Fact fact;
  final CritterSpecies species;

  /// Hue from the other (non-owning) factor via the critter palette.
  final Color hue;

  /// Royal overlay for squares (album diagonal).
  final bool crowned;

  /// True = this is the mirrored twin of the folded fact.
  final bool mirrored;

  final int seed;
  final CritterAccessory accessory;

  CritterSpec get twin => CritterSpec._(
    fact: fact,
    species: species,
    hue: hue,
    crowned: crowned,
    mirrored: !mirrored,
    seed: seed,
    accessory: accessory,
  );

  static CritterSpecies speciesForFamily(Family family) => switch (family) {
    Family.x0 => CritterSpecies.bubbleGhost,
    Family.x1 => CritterSpecies.pebble,
    Family.x2 => CritterSpecies.bouncyBlob,
    Family.x3 => CritterSpecies.sproutAntenna,
    Family.x4 => CritterSpecies.winged,
    Family.x5 => CritterSpecies.starBellied,
    Family.x6 => CritterSpecies.fuzzyOval,
    Family.x7 => CritterSpecies.zigzag,
    Family.x8 => CritterSpecies.doubleDecker,
    Family.x9 => CritterSpecies.spiky,
    Family.x10 => CritterSpecies.tallStacker,
    // ownerOf never yields squares (it owns no facts) — a caller passing it
    // has a knowledge-graph bug worth failing loudly on.
    Family.squares => throw ArgumentError('squares family owns no critters'),
  };

  static int _factorOf(Family family) => switch (family) {
    Family.x0 => 0,
    Family.x1 => 1,
    Family.x2 => 2,
    Family.x3 => 3,
    Family.x4 => 4,
    Family.x5 => 5,
    Family.x6 => 6,
    Family.x7 => 7,
    Family.x8 => 8,
    Family.x9 => 9,
    Family.x10 => 10,
    Family.squares => throw ArgumentError('squares family owns no critters'),
  };

  @override
  bool operator ==(Object other) =>
      other is CritterSpec && other.fact == fact && other.mirrored == mirrored;

  @override
  int get hashCode => Object.hash(fact, mirrored);
}
