import 'dart:math' as math;

import 'package:mastery_core/mastery_core.dart';

/// Deterministic LCG; every learner is seeded, nothing draws from an
/// unseeded source.
class Lcg {
  Lcg(this._state);

  int _state;

  int next(int bound) {
    _state =
        (_state * 6364136223846793005 + 1442695040888963407) &
        0x7fffffffffffffff;
    return (_state >> 17) % bound;
  }

  double nextDouble() => next(1 << 20) / (1 << 20);
}

/// Tunable child model for the law-10 shipping gate: per-fact error falls
/// with successful reps, recall latency tightens with practice, motor time
/// is constant per child.
class LearnerParams {
  const LearnerParams({
    this.baseErrorUnknown = 0.45,
    this.errorFloor = 0.03,
    this.errorHalfLifeReps = 3.0,
    this.motorMs = 700,
    this.motorJitterMs = 350,
    this.recallStartMs = 3800,
    this.recallFloorMs = 500,
    this.recallHalfLifeReps = 4.0,
    this.knownFactors = const {},
  });

  final double baseErrorUnknown;
  final double errorFloor;
  final double errorHalfLifeReps;
  final int motorMs;
  final int motorJitterMs;
  final double recallStartMs;
  final double recallFloorMs;
  final double recallHalfLifeReps;

  /// Facts containing any of these factors are already automatic in her
  /// head (fast + almost always correct) before the app ever opens.
  final Set<int> knownFactors;
}

class SimulatedLearner {
  SimulatedLearner({required int seed, this.params = const LearnerParams()})
    : _rng = Lcg(seed);

  final LearnerParams params;
  final Lcg _rng;
  final Map<Fact, int> _reps = {};

  bool _knows(Fact fact) =>
      params.knownFactors.contains(fact.a) ||
      params.knownFactors.contains(fact.b);

  ({bool correct, int? latencyMs}) answer(RoundEventSpec spec) {
    final fact = spec.fact;
    final reps = _reps[fact] ?? 0;
    double pError;
    if (_knows(fact)) {
      // The law-10 gate defines this learner as "fast+correct on their
      // probes": known facts do not slip. Realistic slips live in the
      // unknown-fact curve the median learner exercises.
      pError = 0;
    } else {
      pError =
          params.errorFloor +
          (params.baseErrorUnknown - params.errorFloor) *
              math.exp(-reps / params.errorHalfLifeReps);
      // The quilt scaffolds construction: counting cells beats bare recall.
      if (spec.kind == EventKind.construct) {
        pError *= spec.rung == Rung.labeled ? 0.6 : 0.35;
      }
    }
    final correct = _rng.nextDouble() >= pError;
    if (correct) {
      _reps[fact] = reps + 1;
    }
    // Constructs are untimed manipulations (latencyMs null by contract).
    if (spec.kind == EventKind.construct) {
      return (correct: correct, latencyMs: null);
    }
    final recall = _knows(fact)
        ? 350.0
        : params.recallFloorMs +
              (params.recallStartMs - params.recallFloorMs) *
                  math.exp(-reps / params.recallHalfLifeReps);
    final latency =
        params.motorMs + recall.round() + _rng.next(params.motorJitterMs);
    return (correct: correct, latencyMs: latency);
  }
}

/// Drives one learner through engine-assembled play. Session shape follows
/// the design: ~10-minute doses, two per day, the child stops when the round
/// has no real work left. Returns total *play* time (event durations, not
/// calendar waiting).
class SimulationResult {
  SimulationResult({
    required this.playHours,
    required this.days,
    required this.mastered,
  });

  final double playHours;
  final int days;
  final bool mastered;
}

class LearnerDriver {
  LearnerDriver({
    required int seed,
    LearnerParams params = const LearnerParams(),
    DateTime? start,
  }) : learner = SimulatedLearner(seed: seed, params: params),
       engine = MasteryEngine.fresh(now: start ?? DateTime(2026, 3, 2, 8)),
       _at = start ?? DateTime(2026, 3, 2, 8);

  static const _sessionCapMs = 10 * 60 * 1000;
  static const _vignetteCostMs = 60 * 1000;
  static const _constructOverheadMs = 12000;
  static const _tapOverheadMs = 1500;

  final SimulatedLearner learner;
  final MasteryEngine engine;
  DateTime _at;
  int playMs = 0;

  bool get mastered =>
      engine.stats(now: _at).phaseCounts[Phase.automatic] == 66;

  int _playEvent(RoundEventSpec spec) {
    final answer = learner.answer(spec);
    // Choice buttons below labeled; numpad production from labeled up.
    final production = spec.rung == Rung.labeled || spec.rung == Rung.bare;
    engine.record(
      AnswerEvent(
        fact: spec.fact,
        direction: spec.direction,
        kind: spec.kind,
        rung: spec.rung,
        correct: answer.correct,
        latencyMs: spec.kind == EventKind.construct ? null : answer.latencyMs,
        production: spec.kind == EventKind.construct ? false : production,
        at: _at,
      ),
    );
    final cost = spec.kind == EventKind.construct
        ? _constructOverheadMs + learner._rng.next(8000)
        : _tapOverheadMs + (answer.latencyMs ?? 2000);
    _at = _at.add(Duration(milliseconds: cost));
    return cost;
  }

  /// Law 8 in the sim: requeue debts are re-asked until closed (bounded so a
  /// pathological learner cannot hang the test; the debt then carries over).
  int _closeRequeues() {
    var cost = 0;
    var guard = 0;
    while (engine.pendingRequeues.isNotEmpty && guard++ < 15) {
      final fact = engine.pendingRequeues.first;
      final cell = engine.samplerView(now: _at)[fact]!;
      cost += _playEvent(
        RoundEventSpec(
          fact: fact,
          direction: AskDirection.forward,
          kind: EventKind.review,
          rung: cell.rung,
          choiceDistractors: const [0, 1],
        ),
      );
    }
    return cost;
  }

  /// One ~10-minute session; returns played milliseconds. Every played
  /// event costs at least its overhead, so the loop always terminates.
  int session() {
    var ms = 0;
    while (ms < _sessionCapMs) {
      final stats = engine.stats(now: _at);
      if (!stats.placementActive) {
        final vignette = engine.nextVignette();
        if (vignette != null) {
          engine.markVignetteComplete(vignette.family, now: _at);
          _at = _at.add(const Duration(milliseconds: _vignetteCostMs));
          ms += _vignetteCostMs;
          continue;
        }
      }
      final round = engine.assembleRound(RoundIntent.piecing, now: _at);
      final hasWork =
          round.events.any(
            (e) => e.kind == EventKind.probe || e.kind == EventKind.construct,
          ) ||
          stats.dueCount > 0 ||
          engine.pendingRequeues.isNotEmpty;
      if (round.events.isEmpty || !hasWork) {
        break;
      }
      for (final spec in round.events) {
        ms += _playEvent(spec);
      }
      ms += _closeRequeues();
      // A bee chaser per piecing block once anything is symbolic: this is
      // where lifetime reps (and extra distinct days) accrue. Not during
      // placement — those first sessions belong to the probes.
      if (!stats.placementActive) {
        final bee = engine.assembleRound(RoundIntent.bee, now: _at);
        if (bee.events.isNotEmpty) {
          for (final spec in bee.events) {
            ms += _playEvent(spec);
          }
          ms += _closeRequeues();
        }
      }
    }
    playMs += ms;
    return ms;
  }

  /// Two sessions a day until the whole table is automatic or [maxDays].
  SimulationResult runToMastery({int maxDays = 250}) {
    final startDay = DateTime(_at.year, _at.month, _at.day);
    for (var day = 0; day < maxDays; day++) {
      for (final hour in const [8, 17]) {
        _at = startDay.add(Duration(days: day, hours: hour));
        session();
        if (mastered) {
          return SimulationResult(
            playHours: playMs / 3600000,
            days: day + 1,
            mastered: true,
          );
        }
      }
    }
    return SimulationResult(
      playHours: playMs / 3600000,
      days: maxDays,
      mastered: false,
    );
  }
}
