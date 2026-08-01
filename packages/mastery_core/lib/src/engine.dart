import 'package:clock/clock.dart';

import 'events.dart';
import 'fact.dart';
import 'item_state.dart';
import 'knowledge_graph.dart';
import 'motor_baseline.dart';
import 'placement_policy.dart';
import 'round_assembler.dart';
import 'tuning.dart';
import 'views.dart';

/// The mastery engine for the multiplication 0-10 pack. All transitions are
/// pure and synchronous; the app owns persistence and feeds events back in.
/// Time flows only from `event.at` / explicit `now` parameters.
class MasteryEngine {
  MasteryEngine.fresh({
    DateTime? now,
    EngineTuning tuning = const EngineTuning(),
  }) : _tuning = tuning,
       _createdAtMs = (now ?? clock.now()).millisecondsSinceEpoch {
    _motor = MotorBaseline(_tuning);
    _placement = PlacementPolicy(_tuning);
    for (final fact in _pack.allFacts) {
      _states[fact] = ItemState();
    }
    for (final family in Family.values) {
      _statuses[family] = FamilyStatus.locked;
    }
    _refreshStatuses();
  }

  MasteryEngine.fromSnapshot(Map<String, Object?> snapshot)
    : _tuning = EngineTuning.fromMap(
        (snapshot['tuning'] as Map<String, Object?>?) ?? const {},
      ),
      _createdAtMs = (snapshot['createdAtMs'] as num?)?.toInt() ?? 0 {
    if (snapshot['version'] != 1 || snapshot['pack'] != _packId) {
      throw FormatException(
        'unsupported mastery_core snapshot: '
        '${snapshot['version']}/${snapshot['pack']}',
      );
    }
    _motor = MotorBaseline(_tuning);
    _placement = PlacementPolicy(_tuning);
    _motor.restore((snapshot['motor'] as Map<String, Object?>?) ?? const {});
    _placement.restore(
      (snapshot['placement'] as Map<String, Object?>?) ?? const {},
    );
    final facts =
        (snapshot['facts'] as Map<String, Object?>?) ??
        const <String, Object?>{};
    for (final fact in _pack.allFacts) {
      final raw = facts[fact.id];
      _states[fact] = raw is Map<String, Object?>
          ? ItemState.fromMap(raw)
          : ItemState();
    }
    final statuses =
        (snapshot['familyStatuses'] as Map<String, Object?>?) ??
        const <String, Object?>{};
    for (final family in Family.values) {
      final raw = statuses[family.name];
      _statuses[family] = raw is String
          ? FamilyStatus.values.byName(raw)
          : FamilyStatus.locked;
    }
    _vignetteCompleted.addAll(
      ((snapshot['vignetteCompleted'] as List<Object?>?) ?? const []).map(
        (e) => Family.values.byName(e as String),
      ),
    );
    _vignetteReDue.addAll(
      ((snapshot['vignetteReDue'] as List<Object?>?) ?? const []).map(
        (e) => Family.values.byName(e as String),
      ),
    );
    for (final raw in (snapshot['requeues'] as List<Object?>?) ?? const []) {
      final map = raw as Map<String, Object?>;
      _requeues.add((
        fact: Fact.parse(map['fact'] as String),
        direction: AskDirection.values.byName(map['direction'] as String),
      ));
    }
    _eventCount = (snapshot['eventCount'] as num?)?.toInt() ?? 0;
    _lastEventKey = snapshot['lastEventKey'] as String?;
  }

  static const _packId = 'multiplication-0-10';
  static const _pack = MultiplicationPack();

  final EngineTuning _tuning;
  final int _createdAtMs;
  late final MotorBaseline _motor;
  late final PlacementPolicy _placement;
  final Map<Fact, ItemState> _states = {};
  final Map<Family, FamilyStatus> _statuses = {};
  final Set<Family> _vignetteCompleted = {};

  /// Families whose vignette was re-owed by lapses (law 5). Sticky: the
  /// satisfaction fixpoint may not auto-open these — only a fresh
  /// markVignetteComplete clears the debt.
  final Set<Family> _vignetteReDue = {};
  final List<({Fact fact, AskDirection direction})> _requeues = [];
  int _eventCount = 0;
  String? _lastEventKey;

  /// Facts that missed and must re-ask before their round closes (law 8);
  /// additive to the contract so consumers can verify closure.
  List<Fact> get pendingRequeues =>
      _requeues.map((r) => r.fact).toList(growable: false);

  // ---- record ---------------------------------------------------------------

  RecordResult record(AnswerEvent event) {
    final key = event.dedupeKey;
    if (key == _lastEventKey) {
      return RecordResult.none; // idempotent per event
    }
    _lastEventKey = key;
    _eventCount++;

    final state = _states[event.fact]!;
    final wasLocked = {
      for (final f in Family.values)
        if (_statuses[f] == FamilyStatus.locked) f,
    };

    // Threshold is computed before this event's latency joins the baseline,
    // so an answer can never loosen the bar it is judged against.
    final fast = _isFast(event);

    var result = _RecordScratch();
    if (event.kind == EventKind.probe && !state.started) {
      _applyProbe(event, state, fast);
    } else {
      if (!state.started) {
        state.started = true;
        state.rung = Rung.grid;
      }
      if (event.correct) {
        _applyCorrect(event, state, fast, result);
      } else {
        _applyMiss(event, state, result);
      }
    }
    _addMotorSample(event);
    _refreshStatuses();

    final unlocked = wasLocked
        .where((f) => _statuses[f] != FamilyStatus.locked)
        .toList(growable: false);
    return RecordResult(
      rungAdvanced: result.rungAdvanced,
      rungDemoted: result.rungDemoted,
      factFired: result.factFired,
      familiesUnlocked: unlocked,
      mirrorPlanted: result.mirrorPlanted,
      requeue: result.requeue,
      offerStrategySwitch: result.offerStrategySwitch,
      prerequisiteProbe: result.prerequisiteProbe,
    );
  }

  bool _isFast(AnswerEvent event) =>
      event.production &&
      event.correct &&
      event.latencyMs != null &&
      event.latencyMs! <= _motor.fastThresholdMs();

  void _applyProbe(AnswerEvent event, ItemState state, bool fast) {
    final family = _pack.ownerOf(event.fact);
    _placement.onProbe(family, event.fact, correct: event.correct);
    if (fast) {
      // Law 1: fast+correct probe instantiates at bare immediately; two
      // spaced confirmations (distinct days) then grant permanent automatic.
      state
        ..started = true
        ..rung = Rung.bare
        ..everDerived = true
        ..probeInstantiated = true
        ..srIndex = 1
        ..dueAtMs = _plusDays(event.at, 1, state.speed);
      state.automaticDays = [_dayKey(event.at)];
    } else if (event.correct) {
      // Correct but slow: she can produce it, it just is not automatic yet.
      // Instantiate at labeled (derived) so placement credit is honest.
      state
        ..started = true
        ..rung = Rung.labeled
        ..everDerived = true
        ..srIndex = 1
        ..dueAtMs = _plusDays(event.at, 1, state.speed);
    } else {
      state.probedCold = true;
    }
  }

  void _applyCorrect(
    AnswerEvent event,
    ItemState state,
    bool fast,
    _RecordScratch result,
  ) {
    state.consecutiveMisses = 0;
    _requeues.removeWhere((r) => r.fact == event.fact);

    // Weaning ladder: evidence counts only at the rung actually presented.
    if (event.rung == state.rung && state.rung != Rung.bare) {
      state.streak++;
      if (state.streak >= _tuning.rungAdvanceStreak) {
        state.rung = Rung.values[state.rung.index + 1];
        state.streak = 0;
        result.rungAdvanced = true;
        if (state.rung.index >= Rung.labeled.index) {
          state.everDerived = true;
        }
      }
    }

    // Spacing (law 2): only a due answer advances the expanding schedule;
    // post-lapse the shortened interval must be re-proven first.
    final due =
        state.dueAtMs == null ||
        event.at.millisecondsSinceEpoch >= state.dueAtMs!;
    if (due) {
      if (state.relearning) {
        state.relearning = false;
      } else {
        state.srIndex = (state.srIndex + 1).clamp(
          0,
          _tuning.intervalsDays.length - 1,
        );
      }
      if (fast) {
        state.speed = (state.speed + _tuning.speedUpStep).clamp(
          _tuning.speedMin,
          _tuning.speedMax,
        );
      }
      state.dueAtMs = _plusDays(
        event.at,
        _tuning.intervalsDays[state.srIndex],
        state.speed,
      );
    }

    // Automaticity (laws 2+3): fast correct *production* at the bare rung.
    if (fast && event.rung == Rung.bare) {
      final day = _dayKey(event.at);
      if (!state.automaticDays.contains(day)) {
        state.automaticDays = [...state.automaticDays, day]..sort();
      }
      if (!state.automatic &&
          state.rung == Rung.bare &&
          state.automaticDays.length >= _tuning.automaticityDays) {
        state.automatic = true;
        result.factFired = true;
        if (state.everAutomatic) {
          state.repaired = true;
        }
        state.everAutomatic = true;
        if (!state.mirrorPlanted && !event.fact.isSquare) {
          state.mirrorPlanted = true;
          result.mirrorPlanted = true;
        }
      }
    }
    if (event.direction == AskDirection.reversed && fast) {
      state.mirrorConfirmed = true;
    }
    if (event.latencyMs != null && event.production) {
      final prev = state.latencyEwmaMs ?? event.latencyMs!.toDouble();
      state.latencyEwmaMs = prev * 0.7 + event.latencyMs! * 0.3;
    }
    state.lastDirectionIndex = event.direction.index;
  }

  void _applyMiss(AnswerEvent event, ItemState state, _RecordScratch result) {
    state.consecutiveMisses++;
    state.streak = 0;
    if (event.kind != EventKind.probe) {
      if (!_requeues.any((r) => r.fact == event.fact)) {
        _requeues.add((fact: event.fact, direction: event.direction));
      }
      result.requeue = event.fact;
    }
    if (state.rung != Rung.grid) {
      state.rung = Rung.values[state.rung.index - 1];
      result.rungDemoted = true;
    }
    state.automatic = false;

    // Lapse: the interval index falls back and must be re-proven (law 5).
    state.srIndex = (state.srIndex - _tuning.lapseSrPenalty).clamp(
      0,
      _tuning.intervalsDays.length - 1,
    );
    state.relearning = true;
    state.dueAtMs = event.at.millisecondsSinceEpoch; // immediately due again
    state.speed = (state.speed - _tuning.speedDownStep).clamp(
      _tuning.speedMin,
      _tuning.speedMax,
    );

    final family = _pack.ownerOf(event.fact);
    final routes = _pack.routesFor(family);
    if (state.everDerived) {
      state.lapses++;
      // Law 5: N lapses on a derived-family fact re-open its vignette.
      if (state.lapses >= _tuning.vignetteReDueLapses &&
          routes.first != StrategyRoute.skipCount &&
          _statuses[family] == FamilyStatus.open) {
        _statuses[family] = FamilyStatus.vignetteDue;
        _vignetteReDue.add(family);
        state.lapses = 0;
      }
    }
    if (state.consecutiveMisses == _tuning.strategySwitchAtMisses) {
      result.offerStrategySwitch = routes.first;
    } else if (state.consecutiveMisses >= _tuning.prerequisiteProbeAtMisses) {
      result.prerequisiteProbe = _pack.componentFact(event.fact);
      state.consecutiveMisses = 0;
    }
    state.lastDirectionIndex = event.direction.index;
  }

  void _addMotorSample(AnswerEvent event) {
    if (event.correct &&
        event.production &&
        event.latencyMs != null &&
        (event.rung == Rung.labeled || event.rung == Rung.bare)) {
      _motor.addSample(event.latencyMs!);
    }
  }

  // ---- families -------------------------------------------------------------

  /// Family satisfaction (law 6): >=80% of owned facts automatic (confirmed
  /// or probe-provisional) and the remainder at least derived. Zero-item
  /// families (squares) are satisfied by their completed vignette.
  bool _familySatisfied(Family family) {
    final owned = _pack.ownedBy(family);
    if (owned.isEmpty) {
      return _vignetteCompleted.contains(family);
    }
    var automaticCount = 0;
    for (final fact in owned) {
      final state = _states[fact]!;
      if (state.automaticForUnlock) {
        automaticCount++;
      } else if (state.phase == Phase.counting) {
        return false; // remainder must be derived-or-better
      }
    }
    return automaticCount >=
        (owned.length * _tuning.unlockAutomaticShare).ceil();
  }

  Set<Family> _satisfiedSet() => {
    for (final f in Family.values)
      if (_familySatisfied(f)) f,
  };

  void _refreshStatuses() {
    // Satisfaction can cascade (a family opening satisfies nothing directly,
    // but vignette completion of a zero-item family can); loop to fixpoint.
    var changed = true;
    while (changed) {
      changed = false;
      final satisfied = _satisfiedSet();
      for (final family in Family.values) {
        final status = _statuses[family]!;
        if (satisfied.contains(family) &&
            status != FamilyStatus.open &&
            !_vignetteReDue.contains(family)) {
          // Probe evidence fast-tracks straight past the vignette (law 1):
          // demonstrated knowledge is never re-taught.
          _statuses[family] = FamilyStatus.open;
          changed = true;
        } else if (status == FamilyStatus.locked &&
            _pack.gateSatisfied(family, satisfied)) {
          _statuses[family] = FamilyStatus.vignetteDue;
          changed = true;
        }
      }
    }
  }

  FamilyStatus familyStatus(Family family) => _statuses[family]!;

  VignetteSpec? nextVignette() {
    for (final family in _pack.sequence) {
      if (_statuses[family] == FamilyStatus.vignetteDue) {
        final route = _routeFor(family);
        return VignetteSpec(
          family: family,
          route: route,
          anchor: _anchorFor(family, route),
        );
      }
    }
    return null;
  }

  /// For x6 (the one OR family) the vignette teaches whichever source family
  /// the child has stronger command of.
  StrategyRoute _routeFor(Family family) {
    final routes = _pack.routesFor(family);
    if (family == Family.x6) {
      final x3Share = _automaticShare(Family.x3);
      final x5Share = _automaticShare(Family.x5);
      return x5Share > x3Share ? StrategyRoute.addAGroup : routes.first;
    }
    return routes.first;
  }

  double _automaticShare(Family family) {
    final owned = _pack.ownedBy(family);
    if (owned.isEmpty) {
      return 0;
    }
    final auto = owned.where((f) => _states[f]!.automaticForUnlock).length;
    return auto / owned.length;
  }

  /// The vignette replays on the child's own mastered patch: for derived
  /// families, the strategy-source component of an owned fact; for
  /// foundational skip-count families, the family's simplest patch; for the
  /// cross-cutting squares stage, her best mastered diagonal patch.
  Fact _anchorFor(Family family, StrategyRoute route) {
    if (family == Family.squares) {
      for (var n = 10; n >= 2; n--) {
        final fact = Fact(n, n);
        if (_states[fact]!.automaticForUnlock) {
          return fact;
        }
      }
      return const Fact(5, 5);
    }
    final owned = [..._pack.ownedBy(family)]
      ..sort((x, y) => x.product.compareTo(y.product));
    if (route == StrategyRoute.skipCount) {
      return owned.firstWhere((f) => f.a > 0, orElse: () => owned.first);
    }
    for (final fact in owned) {
      final component = _pack.componentFact(fact, route: route);
      if (component != null && _states[component]!.automaticForUnlock) {
        return component;
      }
    }
    return _pack.componentFact(owned.first, route: route) ?? owned.first;
  }

  void markVignetteComplete(Family family, {required DateTime now}) {
    if (_statuses[family] == FamilyStatus.locked) {
      throw StateError('vignette for locked family $family');
    }
    _vignetteCompleted.add(family);
    _vignetteReDue.remove(family);
    if (_statuses[family] == FamilyStatus.vignetteDue) {
      _statuses[family] = FamilyStatus.open;
    }
    _refreshStatuses();
  }

  // ---- views ----------------------------------------------------------------

  SamplerView samplerView({required DateTime now}) {
    final cells = <Fact, SamplerCell>{};
    for (final fact in _pack.allFacts) {
      final state = _states[fact]!;
      cells[fact] = SamplerCell(
        fact: fact,
        family: _pack.ownerOf(fact),
        started: state.started,
        rung: state.rung,
        phase: state.phase,
        dueNow: state.dueNow(now),
        mirrorFilled: fact.isSquare
            ? state.automatic
            : state.mirrorPlanted && state.mirrorConfirmed,
        repaired: state.repaired,
      );
    }
    return SamplerView(cells: cells);
  }

  EngineStats stats({required DateTime now}) {
    final phaseCounts = {for (final p in Phase.values) p: 0};
    final rungCounts = {for (final r in Rung.values) r: 0};
    var dueCount = 0;
    var startedCount = 0;
    var automaticCount = 0;
    for (final fact in _pack.allFacts) {
      final state = _states[fact]!;
      phaseCounts[state.phase] = phaseCounts[state.phase]! + 1;
      if (state.started) {
        startedCount++;
        rungCounts[state.rung] = rungCounts[state.rung]! + 1;
        if (state.dueNow(now)) {
          dueCount++;
        }
      }
      if (state.automatic) {
        automaticCount++;
      }
    }
    final satisfied = _satisfiedSet();
    Family? frontier;
    for (final family in _pack.sequence) {
      if (!satisfied.contains(family)) {
        frontier = family;
        break;
      }
    }
    return EngineStats(
      phaseCounts: phaseCounts,
      rungCounts: rungCounts,
      dueCount: dueCount,
      startedCount: startedCount,
      automaticCount: automaticCount,
      frontier: frontier,
      placementActive: _placement.isActive(_pack, _states, satisfied),
    );
  }

  // ---- round assembly (law 7) ----------------------------------------------

  RoundSpec assembleRound(RoundIntent intent, {required DateTime now}) {
    final satisfied = _satisfiedSet();
    final placementActive = _placement.isActive(_pack, _states, satisfied);
    // Deterministic per (state, now): assembling is a pure query, so a
    // snapshot-restored engine assembles the identical round (law 9).
    final seed = _eventCount * 31 + _dayKey(now) % 1009 + intent.index * 7;
    return RoundAssembler(_tuning).assemble(
      intent: intent,
      pack: _pack,
      states: _states,
      statuses: _statuses,
      satisfied: satisfied,
      requeues: _requeues,
      probes: placementActive
          ? _placement.nextProbes(
              _tuning.probeCapPerRound,
              _pack,
              _states,
              satisfied,
            )
          : const [],
      placementActive: placementActive,
      now: now,
      seed: seed,
    );
  }

  // ---- snapshot (law 9) -----------------------------------------------------

  Map<String, Object?> snapshot() => {
    'version': 1,
    'pack': _packId,
    'createdAtMs': _createdAtMs,
    'eventCount': _eventCount,
    'lastEventKey': _lastEventKey,
    'tuning': _tuning.toMap(),
    'motor': _motor.toMap(),
    'placement': _placement.toMap(),
    'vignetteCompleted': _vignetteCompleted.map((f) => f.name).toList()..sort(),
    'vignetteReDue': _vignetteReDue.map((f) => f.name).toList()..sort(),
    'familyStatuses': {
      for (final f in Family.values) f.name: _statuses[f]!.name,
    },
    'requeues': [
      for (final r in _requeues)
        {'fact': r.fact.id, 'direction': r.direction.name},
    ],
    'facts': {
      for (final fact in _pack.allFacts) fact.id: _states[fact]!.toMap(),
    },
  };

  // ---- time helpers ---------------------------------------------------------

  static int _dayKey(DateTime at) => at.year * 10000 + at.month * 100 + at.day;

  static int _plusDays(DateTime at, int days, double speed) =>
      at.millisecondsSinceEpoch +
      (days * speed * Duration.millisecondsPerDay).round();
}

class _RecordScratch {
  bool rungAdvanced = false;
  bool rungDemoted = false;
  bool factFired = false;
  bool mirrorPlanted = false;
  Fact? requeue;
  StrategyRoute? offerStrategySwitch;
  Fact? prerequisiteProbe;
}
