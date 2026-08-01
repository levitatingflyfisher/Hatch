import 'dart:ui';

import 'package:flutter/foundation.dart';

/// The three painted biomes a child can pick for her habitat. Flat scenery,
/// zero mechanics — a backdrop, not a level.
enum HabitatBiome { meadow, pond, hill }

/// How many critters a habitat holds. Fixed and unannounced: there is no
/// "7 of 9 placed" anywhere, because a shelf is not a checklist
/// (refuse-list: no completion nags, nothing to finish).
const int kHabitatSlotCount = 9;

/// Where the slots sit in the scene, as fractions of the scene rect.
/// Staggered rows, bottom-weighted, so placed critters read as standing in
/// the scenery rather than filling a spreadsheet.
const List<Offset> kHabitatSlotAnchors = [
  Offset(0.22, 0.30),
  Offset(0.52, 0.26),
  Offset(0.80, 0.33),
  Offset(0.16, 0.56),
  Offset(0.46, 0.52),
  Offset(0.76, 0.58),
  Offset(0.28, 0.80),
  Offset(0.56, 0.78),
  Offset(0.84, 0.82),
];

/// One profile's habitat arrangement: the chosen biome + which hatched
/// critter (by fact id, e.g. '3x8') stands in which slot. Pure value type;
/// persistence lives in HabitatStore.
@immutable
class HabitatLayout {
  const HabitatLayout({
    this.biome = HabitatBiome.meadow,
    this.slots = const {},
  });

  final HabitatBiome biome;

  /// Slot index (0..[kHabitatSlotCount]-1) → fact id of the critter there.
  final Map<int, String> slots;

  HabitatLayout withBiome(HabitatBiome biome) =>
      HabitatLayout(biome: biome, slots: slots);

  /// Places [factId] at [slot], vacating any other slot it occupied (one
  /// critter cannot stand in two places).
  HabitatLayout place(int slot, String factId) {
    final next = Map<int, String>.from(slots)
      ..removeWhere((_, id) => id == factId)
      ..[slot] = factId;
    return HabitatLayout(biome: biome, slots: next);
  }

  /// Sends whatever stands at [slot] back to the roster.
  HabitatLayout clearSlot(int slot) {
    final next = Map<int, String>.from(slots)..remove(slot);
    return HabitatLayout(biome: biome, slots: next);
  }

  Map<String, Object?> toJson() => {
    'v': 1,
    'biome': biome.name,
    'slots': slots.map((slot, id) => MapEntry('$slot', id)),
  };

  /// Tolerant decode: an unknown biome, a bad slot key, or an out-of-range
  /// index degrades to defaults rather than bricking the shelf — the
  /// habitat is decoration, never data worth an error screen.
  factory HabitatLayout.fromJson(Map<String, Object?> json) {
    final biome =
        HabitatBiome.values.asNameMap()[json['biome']] ?? HabitatBiome.meadow;
    final slots = <int, String>{};
    final raw = json['slots'];
    if (raw is Map) {
      raw.forEach((key, value) {
        final slot = int.tryParse('$key');
        if (slot != null &&
            slot >= 0 &&
            slot < kHabitatSlotCount &&
            value is String) {
          slots[slot] = value;
        }
      });
    }
    return HabitatLayout(biome: biome, slots: slots);
  }

  @override
  bool operator ==(Object other) =>
      other is HabitatLayout &&
      other.biome == biome &&
      mapEquals(other.slots, slots);

  @override
  int get hashCode => Object.hash(
    biome,
    Object.hashAllUnordered(
      slots.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}
