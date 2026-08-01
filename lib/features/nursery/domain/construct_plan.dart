import 'package:mastery_core/mastery_core.dart';

import '../../../shared/painters/incubator_frame_painter.dart';

/// The manipulation each construct event asks for. STACK is the fully
/// interactive verb (the child places every row herself); the rest are
/// guided one-tap seam moves — the seam glows, one tap plays the
/// choreographed decomposition. Polished moves, not free physics.
enum ConstructVerb { stack, fold, slice, trim, addRow }

/// Everything a construct surface needs, derived once from the event spec:
/// frame orientation (the owning-family factor is always the row count, so
/// "×4" reads as 4 groups), the teaching seam, the partial products that
/// stay visible as the addition scaffold, and which rows start pre-filled.
class ConstructPlan {
  const ConstructPlan._({
    required this.verb,
    required this.frameA,
    required this.frameB,
    required this.seam,
    required this.partialProducts,
    required this.prefilledRows,
    required this.product,
  });

  /// Plan for an assembled round event: STACK at grid/bundled rungs (no
  /// hint), the hinted seam move at labeled.
  factory ConstructPlan.forSpec(RoundEventSpec spec) {
    final route = spec.strategyHint;
    if (route == null || route == StrategyRoute.skipCount) {
      final (a, b) = spec.direction == AskDirection.forward
          ? (spec.fact.a, spec.fact.b)
          : (spec.fact.b, spec.fact.a);
      return ConstructPlan._(
        verb: ConstructVerb.stack,
        frameA: a,
        frameB: b,
        seam: null,
        partialProducts: const [],
        prefilledRows: 0,
        product: spec.fact.product,
      );
    }
    return ConstructPlan.forFactRoute(spec.fact, route);
  }

  /// Plan for [fact] taught through [route] (strategy switch, vignette
  /// practice). The route decides which factor plays "the family factor".
  factory ConstructPlan.forFactRoute(Fact fact, StrategyRoute route) {
    final f = _teachFactor(fact, route);
    final other = fact.a == f ? fact.b : fact.a;
    return ConstructPlan.forRoute(route, familyFactor: f, other: other);
  }

  factory ConstructPlan.forRoute(
    StrategyRoute route, {
    required int familyFactor,
    required int other,
  }) {
    switch (route) {
      case StrategyRoute.skipCount:
        return ConstructPlan._(
          verb: ConstructVerb.stack,
          frameA: familyFactor,
          frameB: other,
          seam: null,
          partialProducts: const [],
          prefilledRows: 0,
          product: familyFactor * other,
        );
      case StrategyRoute.foldDouble:
        final half = familyFactor ~/ 2;
        return ConstructPlan._(
          verb: ConstructVerb.fold,
          frameA: familyFactor,
          frameB: other,
          seam: SplitSeam(half),
          partialProducts: [half * other, (familyFactor - half) * other],
          prefilledRows: half,
          product: familyFactor * other,
        );
      case StrategyRoute.fiveAnchorSplit:
        return ConstructPlan._(
          verb: ConstructVerb.slice,
          frameA: familyFactor,
          frameB: other,
          seam: const SplitSeam(5),
          partialProducts: [5 * other, (familyFactor - 5) * other],
          prefilledRows: familyFactor,
          product: familyFactor * other,
        );
      case StrategyRoute.trimAGroup:
        return ConstructPlan._(
          verb: ConstructVerb.trim,
          frameA: familyFactor,
          frameB: other,
          seam: const TrimRowSeam(),
          partialProducts: [(familyFactor + 1) * other, other],
          prefilledRows: familyFactor,
          product: familyFactor * other,
        );
      case StrategyRoute.addAGroup:
      case StrategyRoute.nearSquare:
        return ConstructPlan._(
          verb: ConstructVerb.addRow,
          frameA: familyFactor - 1,
          frameB: other,
          seam: const GhostRowSeam(),
          partialProducts: [(familyFactor - 1) * other, other],
          prefilledRows: familyFactor - 1,
          product: familyFactor * other,
        );
    }
  }

  final ConstructVerb verb;

  /// Frame rows (the group count as taught).
  final int frameA;

  /// Frame columns (the group size).
  final int frameB;

  final FrameSeam? seam;

  /// The stacked addition scaffold (subtraction for trim), e.g. [14, 14].
  final List<int> partialProducts;

  /// Rows already holding eggs before the move plays.
  final int prefilledRows;

  final int product;

  /// Mirror of IncubatorFramePainter: trim/ghost seams borrow one extra row.
  int get extraRows => seam is TrimRowSeam || seam is GhostRowSeam ? 1 : 0;

  /// Scene rows including the seam's borrowed row.
  int get sceneRows => frameA + extraRows;

  /// The visible addition scaffold, e.g. '14+14' or '70−7'. Empty for STACK
  /// (its scaffold is the running skip-count while stacking).
  String get scaffoldText {
    if (partialProducts.isEmpty) return '';
    final joiner = verb == ConstructVerb.trim ? '−' : '+';
    return partialProducts.join(joiner);
  }

  /// Which factor the route decomposes. nearSquare has no owning family
  /// (squares owns no facts), so the square's own side is the factor.
  static int _teachFactor(Fact fact, StrategyRoute route) {
    if (route == StrategyRoute.nearSquare) return fact.a;
    const pack = MultiplicationPack();
    return switch (pack.ownerOf(fact)) {
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
  }
}
