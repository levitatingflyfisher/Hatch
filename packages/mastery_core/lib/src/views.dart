import 'events.dart';
import 'fact.dart';

enum FamilyStatus { locked, vignetteDue, open }

enum RoundIntent { piecing, bee }

/// One event slot in an assembled round.
class RoundEventSpec {
  const RoundEventSpec({
    required this.fact,
    required this.direction,
    required this.kind,
    required this.rung,
    required this.choiceDistractors,
    this.strategyHint,
  });

  final Fact fact;
  final AskDirection direction;
  final EventKind kind;
  final Rung rung;

  /// Interference-aware, length 2, for choice-button rungs.
  final List<int> choiceDistractors;

  /// For labeled-rung construct events.
  final StrategyRoute? strategyHint;
}

class RoundSpec {
  const RoundSpec({
    required this.events,
    required this.placementActive,
    this.expectedSuccess = 0.85,
  });

  final List<RoundEventSpec> events;
  final bool placementActive;

  /// Engine's own success estimate for this round (law 7's ~85% target);
  /// additive to the contract, for app-side difficulty telemetry.
  final double expectedSuccess;
}

/// Per-fact view for the Sampler painter and parent heatmap.
class SamplerCell {
  const SamplerCell({
    required this.fact,
    required this.family,
    required this.started,
    required this.rung,
    required this.phase,
    required this.dueNow,
    required this.mirrorFilled,
    required this.repaired,
  });

  final Fact fact;

  /// Scheduling owner family (squares render as cornerstones via
  /// [Fact.isSquare], they are owned by their factor family).
  final Family family;
  final bool started;
  final Rung rung;
  final Phase phase;

  /// Due = visibly loose threads; eligible, never punished (law 2).
  final bool dueNow;
  final bool mirrorFilled;
  final bool repaired;
}

class SamplerView {
  const SamplerView({required this.cells});

  final Map<Fact, SamplerCell> cells;

  SamplerCell? operator [](Fact fact) => cells[fact];
}

class VignetteSpec {
  const VignetteSpec({
    required this.family,
    required this.route,
    required this.anchor,
  });

  final Family family;
  final StrategyRoute route;

  /// Replays the scripted gesture on the child's OWN mastered patch.
  final Fact anchor;
}

class EngineStats {
  const EngineStats({
    required this.phaseCounts,
    required this.rungCounts,
    required this.dueCount,
    required this.startedCount,
    required this.automaticCount,
    required this.frontier,
    required this.placementActive,
  });

  final Map<Phase, int> phaseCounts;

  /// Started facts only.
  final Map<Rung, int> rungCounts;
  final int dueCount;
  final int startedCount;
  final int automaticCount;

  /// Earliest family in the unlock sequence not yet satisfied; null when the
  /// whole table is done.
  final Family? frontier;
  final bool placementActive;
}
