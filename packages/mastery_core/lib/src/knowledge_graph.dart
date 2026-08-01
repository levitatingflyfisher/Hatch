import 'fact.dart';

/// The multiplication 0-10 topic pack: fact ownership, unlock gates, and
/// strategy routes. This is the knowledge graph the engine schedules over.
///
/// Contract resolutions encoded here (see MASTERY_CORE_CONTRACT.md law 6):
/// - `squares` is cross-cutting: it owns no scheduling items (each diagonal
///   fact n*n is owned by family xN and tagged via [Fact.isSquare]); the
///   squares *family* exists as the nearSquare strategy stage gated on x5.
///   This keeps the child's frontier honest: a learner placed past the
///   foundational families reaches x4 in session one instead of being walled
///   behind six unlearned diagonal facts (law 1 / law 10 gate).
/// - Unlock gates are ANDed OR-groups: the family's sequence predecessor AND
///   its strategy source(s). The contract's "x6 unlocks from (x3 OR x5)" is
///   the OR-group; the sequence chain supplies George-Fan pacing.
class MultiplicationPack {
  const MultiplicationPack();

  /// Kling & Bay-Williams / practitioner unlock order (research brief 2b).
  List<Family> get sequence => const [
    Family.x2,
    Family.x10,
    Family.x5,
    Family.x1,
    Family.x0,
    Family.squares,
    Family.x4,
    Family.x3,
    Family.x9,
    Family.x6,
    Family.x7,
    Family.x8,
  ];

  int sequenceIndex(Family family) => sequence.indexOf(family);

  /// All 66 folded facts. Memoized: the satisfaction fixpoint consults the
  /// graph on every recorded event.
  static final List<Fact> _allFacts = List.unmodifiable([
    for (var a = 0; a <= 10; a++)
      for (var b = a; b <= 10; b++) Fact(a, b),
  ]);

  List<Fact> get allFacts => _allFacts;

  static Family _factorFamily(int n) => switch (n) {
    0 => Family.x0,
    1 => Family.x1,
    2 => Family.x2,
    3 => Family.x3,
    4 => Family.x4,
    5 => Family.x5,
    6 => Family.x6,
    7 => Family.x7,
    8 => Family.x8,
    9 => Family.x9,
    10 => Family.x10,
    _ => throw RangeError('factor out of range: $n'),
  };

  /// The single scheduling owner: the factor family that unlocks earliest.
  /// Diagonal facts belong to their own factor family (squares owns none).
  Family ownerOf(Fact fact) {
    final fa = _factorFamily(fact.a);
    final fb = _factorFamily(fact.b);
    return sequenceIndex(fa) <= sequenceIndex(fb) ? fa : fb;
  }

  static final Map<Family, List<Fact>> _ownedBy = {
    for (final family in Family.values)
      family: List.unmodifiable(
        _allFacts.where((f) => const MultiplicationPack().ownerOf(f) == family),
      ),
  };

  List<Fact> ownedBy(Family family) => _ownedBy[family]!;

  /// Strategy routes per family; x6 lists both contract routes in preference
  /// order (foldDouble from x3, addAGroup from x5).
  List<StrategyRoute> routesFor(Family family) => switch (family) {
    Family.x0 ||
    Family.x1 ||
    Family.x2 ||
    Family.x5 ||
    Family.x10 => const [StrategyRoute.skipCount],
    Family.x3 => const [StrategyRoute.addAGroup],
    Family.x4 || Family.x8 => const [StrategyRoute.foldDouble],
    Family.x6 => const [StrategyRoute.foldDouble, StrategyRoute.addAGroup],
    Family.x7 => const [StrategyRoute.fiveAnchorSplit],
    Family.x9 => const [StrategyRoute.trimAGroup],
    Family.squares => const [StrategyRoute.nearSquare],
  };

  /// Unlock gate as ANDed OR-groups over *satisfied* families.
  List<List<Family>> gateFor(Family family) => switch (family) {
    Family.x2 => const [],
    Family.x10 => const [
      [Family.x2],
    ],
    Family.x5 => const [
      [Family.x10],
    ],
    // x1/x0 are one sequence step ("one-vignette toy-jokes"): both on x5.
    Family.x1 || Family.x0 => const [
      [Family.x5],
    ],
    // Contract: "squares unlock after x5 with nearSquare route".
    Family.squares => const [
      [Family.x5],
    ],
    Family.x4 => const [
      [Family.squares],
      [Family.x2],
    ],
    Family.x3 => const [
      [Family.x4],
      [Family.x2],
    ],
    Family.x9 => const [
      [Family.x3],
      [Family.x10],
    ],
    // The contract's one true OR: strategy source is x3 OR x5.
    Family.x6 => const [
      [Family.x9],
      [Family.x3, Family.x5],
    ],
    Family.x7 => const [
      [Family.x6],
      [Family.x5],
      [Family.x2],
    ],
    Family.x8 => const [
      [Family.x7],
      [Family.x4],
    ],
  };

  bool gateSatisfied(Family family, Set<Family> satisfied) =>
      gateFor(family).every((group) => group.any(satisfied.contains));

  /// The strategy-source component fact probed on chronic failure (law 5):
  /// the fact the derivation route rests on.
  Fact? componentFact(Fact fact, {StrategyRoute? route}) {
    final owner = ownerOf(fact);
    final effectiveRoute = route ?? routesFor(owner).first;
    // The "strategy factor" is the factor that names the owning family; the
    // other factor rides along unchanged through the derivation.
    final familyFactor = switch (owner) {
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
      Family.squares => fact.a,
    };
    final other = fact.a == familyFactor ? fact.b : fact.a;
    return switch (effectiveRoute) {
      StrategyRoute.skipCount => null,
      StrategyRoute.foldDouble => Fact.folded(familyFactor ~/ 2, other),
      StrategyRoute.addAGroup => Fact.folded(familyFactor - 1, other),
      StrategyRoute.trimAGroup => Fact.folded(familyFactor + 1, other),
      StrategyRoute.fiveAnchorSplit => Fact.folded(5, other),
      StrategyRoute.nearSquare => Fact.folded(familyFactor - 1, other),
    };
  }
}
