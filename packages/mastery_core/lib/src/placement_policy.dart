import 'fact.dart';
import 'item_state.dart';
import 'knowledge_graph.dart';
import 'tuning.dart';

/// Placement (law 1): "the quilt remembers what you already know." Walks the
/// unlock sequence probing each family — a few sentinels first, the whole
/// family once the sentinels land — and stops after two consecutive cold
/// families (a child who does not know x1 will not know x7).
///
/// Activity is derived, never stored, so assembling a round is a pure query.
class PlacementPolicy {
  PlacementPolicy(this._tuning);

  final EngineTuning _tuning;

  /// Fact ids probed, any outcome.
  final Set<String> probed = {};
  final Map<Family, int> coldCounts = {};
  final Map<Family, int> hitCounts = {};
  final Set<Family> coldFamilies = {};

  void onProbe(Family family, Fact fact, {required bool correct}) {
    probed.add(fact.id);
    if (correct) {
      hitCounts[family] = (hitCounts[family] ?? 0) + 1;
    } else {
      final cold = (coldCounts[family] ?? 0) + 1;
      coldCounts[family] = cold;
      // Two wrong probes close the family out: she does not know it yet and
      // further probing would just be a wall of misses.
      if (cold >= 2) {
        coldFamilies.add(family);
      }
    }
  }

  /// Sentinel-first order: middle, first, last, then the rest ascending —
  /// the middle fact is the most diagnostic single probe of a family.
  List<Fact> _probeOrder(MultiplicationPack pack, Family family) {
    final owned = [...pack.ownedBy(family)]
      ..sort((x, y) => x.product.compareTo(y.product));
    if (owned.length <= _tuning.probeSentinels) {
      return owned;
    }
    final sentinels = <Fact>{owned[owned.length ~/ 2], owned.first, owned.last};
    return [...sentinels, ...owned.where((f) => !sentinels.contains(f))];
  }

  /// The placement walk: satisfied families reset the cold streak, cold
  /// families extend it (two in a row end placement), and the first family
  /// still worth probing supplies the batch.
  ({List<Fact> probes, bool active}) _walk(
    int budget,
    MultiplicationPack pack,
    Map<Fact, ItemState> states,
    Set<Family> satisfied,
  ) {
    var coldStreak = 0;
    for (final family in pack.sequence) {
      final owned = pack.ownedBy(family);
      if (owned.isEmpty) {
        continue; // squares is cross-cutting; nothing to probe
      }
      if (satisfied.contains(family)) {
        coldStreak = 0;
        continue;
      }
      if (coldFamilies.contains(family)) {
        coldStreak++;
        if (coldStreak >= _tuning.coldFamilyStopStreak) {
          return (probes: const [], active: false);
        }
        continue;
      }
      final candidates = _probeOrder(
        pack,
        family,
      ).where((f) => !probed.contains(f.id) && !states[f]!.started).toList();
      if (candidates.isEmpty) {
        // Fully probed but neither satisfied nor cold (mixed evidence):
        // normal play will finish it; keep walking, streak unbroken.
        coldStreak = 0;
        continue;
      }
      // Hold at the sentinel gate until their outcomes are in.
      final probedInFamily = owned.where((f) => probed.contains(f.id)).length;
      final pending = probedInFamily < _tuning.probeSentinels
          ? _tuning.probeSentinels - probedInFamily
          : candidates.length;
      final take = pending < budget ? pending : budget;
      return (probes: candidates.take(take).toList(), active: true);
    }
    return (probes: const [], active: false);
  }

  bool isActive(
    MultiplicationPack pack,
    Map<Fact, ItemState> states,
    Set<Family> satisfied,
  ) => _walk(1, pack, states, satisfied).active;

  List<Fact> nextProbes(
    int budget,
    MultiplicationPack pack,
    Map<Fact, ItemState> states,
    Set<Family> satisfied,
  ) => budget <= 0 ? const [] : _walk(budget, pack, states, satisfied).probes;

  Map<String, Object?> toMap() => {
    'probed': probed.toList()..sort(),
    'coldCounts': coldCounts.map((k, v) => MapEntry(k.name, v)),
    'hitCounts': hitCounts.map((k, v) => MapEntry(k.name, v)),
    'coldFamilies': coldFamilies.map((f) => f.name).toList()..sort(),
  };

  void restore(Map<String, Object?> map) {
    probed
      ..clear()
      ..addAll(
        ((map['probed'] as List<Object?>?) ?? const []).map((e) => e as String),
      );
    coldCounts
      ..clear()
      ..addAll(
        ((map['coldCounts'] as Map<String, Object?>?) ?? const {}).map(
          (k, v) => MapEntry(Family.values.byName(k), (v as num).toInt()),
        ),
      );
    hitCounts
      ..clear()
      ..addAll(
        ((map['hitCounts'] as Map<String, Object?>?) ?? const {}).map(
          (k, v) => MapEntry(Family.values.byName(k), (v as num).toInt()),
        ),
      );
    coldFamilies
      ..clear()
      ..addAll(
        ((map['coldFamilies'] as List<Object?>?) ?? const []).map(
          (e) => Family.values.byName(e as String),
        ),
      );
  }
}
