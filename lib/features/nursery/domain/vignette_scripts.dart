import 'dart:ui';

import 'package:mastery_core/mastery_core.dart';

import '../../../shared/painters/ghost_cursor.dart';
import '../../../shared/painters/incubator_frame_painter.dart';
import '../../../shared/scene/vignette_step.dart';
import 'construct_plan.dart';

/// The one short label a vignette is allowed (wordless-except-one-label law).
String vignetteLabel(StrategyRoute route) => switch (route) {
  StrategyRoute.skipCount => 'Stack the rows!',
  StrategyRoute.foldDouble => 'Double it!',
  StrategyRoute.addAGroup => 'One more row!',
  StrategyRoute.trimAGroup => 'Trim one row!',
  StrategyRoute.fiveAnchorSplit => 'Split at five!',
  StrategyRoute.nearSquare => 'One more row!',
};

/// ONE template engine, data per route: every vignette is a
/// `GhostCursorScript` built from the plan's frame geometry (scene units:
/// x in columns, y in rows). The ghost demonstrates the gesture the child
/// will make herself — a cursor to imitate, never a hand that performs.
GhostCursorScript ghostScriptFor(ConstructPlan plan) {
  final midX = plan.frameB / 2;
  switch (plan.verb) {
    case ConstructVerb.stack:
      // From the dispenser below, drag a row in; twice, so the repeat reads.
      final rows = plan.frameA;
      final below = Offset(midX, plan.sceneRows + 1.2);
      return GhostCursorScript([
        MoveTo(below),
        const TapAt(),
        DragTo(Offset(midX, 0.5)),
        const Pause(),
        if (rows > 1) ...[
          MoveTo(below),
          const TapAt(),
          DragTo(Offset(midX, 1.5)),
          const Pause(),
        ],
      ], start: Offset(midX, plan.sceneRows + 2.0));
    case ConstructVerb.fold:
      // Grab the seam and fold the mirror copy across it.
      final seamY = (plan.seam as SplitSeam).afterRow.toDouble();
      return GhostCursorScript([
        MoveTo(Offset(midX, seamY)),
        const TapAt(),
        DragTo(Offset(midX, plan.frameA.toDouble())),
        const Pause(),
      ], start: Offset(midX, -1.0));
    case ConstructVerb.slice:
      // Swipe along the five-line.
      final seamY = (plan.seam as SplitSeam).afterRow.toDouble();
      return GhostCursorScript([
        MoveTo(Offset(0.2, seamY)),
        const TapAt(),
        DragTo(Offset(plan.frameB - 0.2, seamY)),
        const Pause(),
      ], start: Offset(-1.0, seamY));
    case ConstructVerb.trim:
      // Swipe the overhang row, then flick it off the edge.
      final seamY = plan.frameA.toDouble();
      return GhostCursorScript([
        MoveTo(Offset(0.2, seamY + 0.5)),
        const TapAt(),
        DragTo(Offset(plan.frameB - 0.2, seamY + 0.5)),
        DragTo(Offset(plan.frameB + 1.2, seamY + 0.8)),
        const Pause(),
      ], start: Offset(-1.0, seamY));
    case ConstructVerb.addRow:
      // Tap the ghost row waiting under the frame.
      final seamY = plan.frameA + 0.5;
      return GhostCursorScript([
        MoveTo(Offset(midX, seamY)),
        const TapAt(),
        const Pause(),
      ], start: Offset(midX, plan.sceneRows + 1.5));
  }
}

/// A family-unlock vignette resolved to its playable pieces: the plan is
/// anchored on the child's OWN mastered fact (the engine picked it), the
/// script is the route template over that plan's geometry.
class NurseryVignette {
  NurseryVignette._(this.plan, this.script, this.label);

  factory NurseryVignette.forSpec(VignetteSpec spec) {
    final plan = _planFor(spec);
    return NurseryVignette._(
      plan,
      ghostScriptFor(plan),
      vignetteLabel(spec.route),
    );
  }

  final ConstructPlan plan;
  final GhostCursorScript script;
  final String label;

  /// The derived tray the vignette builds. The engine's anchor is the
  /// strategy-source component (or, for skip-count families, the family's
  /// simplest owned fact); the route tells us how to read the factors out.
  static ConstructPlan _planFor(VignetteSpec spec) {
    final anchor = spec.anchor;
    switch (spec.route) {
      case StrategyRoute.skipCount:
        final f = _familyFactor(spec.family);
        final other = anchor.a == f ? anchor.b : anchor.a;
        return ConstructPlan.forRoute(
          StrategyRoute.skipCount,
          familyFactor: f,
          other: other,
        );
      case StrategyRoute.nearSquare:
        // Anchor is her best mastered diagonal fact n×n.
        return ConstructPlan.forRoute(
          StrategyRoute.nearSquare,
          familyFactor: anchor.a,
          other: anchor.b,
        );
      case StrategyRoute.foldDouble:
      case StrategyRoute.addAGroup:
      case StrategyRoute.trimAGroup:
      case StrategyRoute.fiveAnchorSplit:
        final f = _familyFactor(spec.family);
        final source = _sourceFactor(f, spec.route);
        final other = anchor.a == source ? anchor.b : anchor.a;
        return ConstructPlan.forRoute(
          spec.route,
          familyFactor: f,
          other: other,
        );
    }
  }

  /// The factor the anchor (component fact) carries for the route, mirroring
  /// MultiplicationPack.componentFact.
  static int _sourceFactor(int familyFactor, StrategyRoute route) =>
      switch (route) {
        StrategyRoute.foldDouble => familyFactor ~/ 2,
        StrategyRoute.addAGroup => familyFactor - 1,
        StrategyRoute.trimAGroup => familyFactor + 1,
        StrategyRoute.fiveAnchorSplit => 5,
        StrategyRoute.skipCount || StrategyRoute.nearSquare => familyFactor,
      };

  static int _familyFactor(Family family) => switch (family) {
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
    // The squares vignette derives its factor from the anchor instead.
    Family.squares => 0,
  };
}
