import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:mastery_core/mastery_core.dart';

import '../../../core/engine/engine_service.dart';
import '../../../shared/answer/answer_input.dart';
import '../../../shared/audio/sound_cue.dart';
import '../../../shared/painters/painters.dart';
import '../data/rush_best_store.dart';
import '../domain/rush_copy.dart';
import '../domain/rush_ghost.dart';

/// Where the round is right now. The screen renders per phase; juice phases
/// (sweep/teach) end when the screen's animation completes and it calls
/// [RushController.advance].
enum RushPhase { assembling, prompt, sweep, teach, done, empty }

/// Drives one Hatch Rush round against the real engine. Every answer is
/// recorded (and persisted) through [EngineService] the moment it lands, so
/// killing the app mid-round loses only the current prompt; a fresh launch
/// simply assembles a fresh round (the engine's requeue debts survive in its
/// snapshot and lead the next round, law 8).
///
/// Time flows only through package:clock and is used solely for the ghost
/// race and the stored best run — it is never surfaced as a clock, countdown
/// or visible number anywhere (refuse-list).
class RushController extends ChangeNotifier {
  RushController({
    required EngineService engine,
    required RushBestStore bestStore,
    void Function(SoundCue cue)? playCue,
  }) : _engine = engine,
       _bestStore = bestStore,
       _playCue = playCue ?? _silent;

  static void _silent(SoundCue _) {}

  /// Below this the round would not feel like a rush; the screen shows the
  /// friendly "more eggs" state instead.
  static const minRoundEvents = 6;

  /// The teach moment, compressed for the arcade register: long enough to
  /// read the shortfall/overflow, short enough to keep the round's pulse.
  static const teachDuration = Duration(milliseconds: 1200);

  final EngineService _engine;
  final RushBestStore _bestStore;
  final void Function(SoundCue cue) _playCue;
  final AnswerStopwatch _stopwatch = AnswerStopwatch();

  RushPhase _phase = RushPhase.assembling;
  final List<RoundEventSpec> _queue = [];
  int _index = 0;
  int _target = 0;
  int _hatched = 0;
  final List<int> _cumulativeMs = [];
  DateTime? _startedAt;
  RushGhost? _ghost;
  SweepTier _sweepTier = SweepTier.medium;
  ShortfallOverflow? _teach;
  Rung _teachRung = Rung.bare;
  RushOutcome? _outcome;
  bool _recording = false;
  bool _disposed = false;

  RushPhase get phase => _phase;

  RoundEventSpec? get current => _index < _queue.length ? _queue[_index] : null;

  /// Eggs hatched so far (correct retrievals). Fills the event dots and the
  /// caterpillar — position in the round, NOT a timer.
  int get hatched => _hatched;

  /// Total eggs this round owes: the assembled size, plus any stale requeue
  /// debt swept in at the end (law-8 closure).
  int get target => _target;

  RushGhost? get ghost => _ghost;
  SweepTier get sweepTier => _sweepTier;
  ShortfallOverflow? get teach => _teach;
  Rung get teachRung => _teachRung;
  RushOutcome? get outcome => _outcome;

  /// Recorded per completed event for the best-run store; exposed for tests,
  /// never for display.
  List<int> get cumulativeMs => List.unmodifiable(_cumulativeMs);

  /// Prompt orientation respects the asked direction (a reversed ask shows
  /// b×a — the twin ordering, law 4).
  int get promptA {
    final spec = current;
    if (spec == null) return 0;
    return spec.direction == AskDirection.forward ? spec.fact.a : spec.fact.b;
  }

  int get promptB {
    final spec = current;
    if (spec == null) return 0;
    return spec.direction == AskDirection.forward ? spec.fact.b : spec.fact.a;
  }

  double get selfProgress => _target == 0 ? 0 : _hatched / _target;

  int get elapsedMs {
    final started = _startedAt;
    return started == null ? 0 : clock.now().difference(started).inMilliseconds;
  }

  /// The ghost's live track position, or null on a first run (solo race).
  /// Pace-matched against the CURRENT [_target], so a round that grows
  /// mid-flight (law-8 leftovers swept in at the end) stretches the ghost
  /// with it rather than handing the child a race she cannot lose.
  double? get ghostProgress => _ghost?.progressAtFor(elapsedMs, _target);

  /// Assembles a bee round and opens the race. Also serves as the instant
  /// "again?" restart — it re-reads the best run so the ghost the child just
  /// set immediately races the next round.
  Future<void> begin() async {
    _queue.clear();
    _index = 0;
    _target = 0;
    _hatched = 0;
    _cumulativeMs.clear();
    _ghost = null;
    _teach = null;
    _outcome = null;
    _recording = false;

    final round = _engine.assembleRound(RoundIntent.bee);
    if (round.events.length < minRoundEvents) {
      _phase = RushPhase.empty;
      _notify();
      return;
    }
    _queue.addAll(round.events);
    _target = _queue.length;
    final best = await _bestStore.read(_engine.profileId);
    _ghost = best == null || best.isEmpty ? null : RushGhost(best);
    _startedAt = clock.now();
    _playCue(SoundCue.rushStart);
    _phase = RushPhase.prompt;
    _stopwatch.promptShown();
    _notify();
  }

  /// First numpad key marks latency (prompt→first keypress, engine law 3).
  void onFirstKey() => _stopwatch.keyPressed();

  /// Records the answer against the real engine, then hands the screen a
  /// sweep (correct) or a teach moment (wrong). A miss transfers the egg's
  /// obligation to a re-ask appended to the queue — the round cannot
  /// complete until every miss has been re-retrieved (law 8).
  Future<void> submit(int answer) async {
    if (_phase != RushPhase.prompt || _recording) return;
    final spec = current;
    if (spec == null) return;
    _recording = true;
    final latency = _stopwatch.firstKeyLatencyMs;
    final correct = answer == spec.fact.product;
    await _engine.record(
      AnswerEvent(
        fact: spec.fact,
        direction: spec.direction,
        kind: spec.kind,
        rung: spec.rung,
        correct: correct,
        latencyMs: latency,
        production: true,
        at: clock.now(),
      ),
    );
    _recording = false;
    if (correct) {
      _cumulativeMs.add(elapsedMs);
      _hatched++;
      _sweepTier = _tierFor(latency);
      _phase = RushPhase.sweep;
      _playCue(SoundCue.settle);
      _playCue(switch (_sweepTier) {
        SweepTier.fast => SoundCue.sweepFast,
        SweepTier.medium => SoundCue.sweepMedium,
        SweepTier.slow => SoundCue.sweepSlow,
      });
    } else {
      _teach = ShortfallOverflow(a: promptA, b: promptB, answer: answer);
      _teachRung = spec.rung;
      _queue.add(_reAskSpec(spec.fact, spec.direction));
      _phase = RushPhase.teach;
      _playCue(SoundCue.miss);
    }
    _notify();
  }

  /// Called by the screen when the sweep/teach choreography finishes; moves
  /// to the next prompt or closes the round once no requeue debt remains.
  Future<void> advance() async {
    if (_phase != RushPhase.sweep && _phase != RushPhase.teach) return;
    _teach = null;
    _index++;
    if (_index >= _queue.length) {
      // Defensive closure: debts the assembler could not seat this round
      // (e.g. restored ones beyond the size cap) still re-ask before the
      // round may complete. Their direction is the engine's to know; forward
      // is the honest default for a debt older than this round.
      final leftovers = _engine.engine.pendingRequeues;
      if (leftovers.isEmpty) {
        await _finish();
        return;
      }
      for (final fact in leftovers) {
        _queue.add(_reAskSpec(fact, AskDirection.forward));
      }
      _target += leftovers.length;
    }
    _phase = RushPhase.prompt;
    _stopwatch.promptShown();
    _notify();
  }

  Future<void> again() => begin();

  /// A miss demotes the fact's rung (law 5), so the re-ask presents at the
  /// rung the engine holds NOW, not the one that was missed.
  RoundEventSpec _reAskSpec(Fact fact, AskDirection direction) {
    final cell = _engine.samplerView()[fact];
    return RoundEventSpec(
      fact: fact,
      direction: direction,
      kind: EventKind.bee,
      rung: cell?.rung ?? Rung.labeled,
      choiceDistractors: const [],
    );
  }

  /// Juice never throttles expert tempo: quicker answers earn the shorter
  /// sweep (the tiers match the pre-rendered sweep clips).
  SweepTier _tierFor(int? latencyMs) {
    if (latencyMs == null) return SweepTier.medium;
    if (latencyMs <= 1500) return SweepTier.fast;
    if (latencyMs <= 2600) return SweepTier.medium;
    return SweepTier.slow;
  }

  Future<void> _finish() async {
    final run = RushGhost(_cumulativeMs);
    final best = await _bestStore.read(_engine.profileId);
    final standing = best == null || best.isEmpty ? null : RushGhost(best);
    if (_cumulativeMs.isEmpty) {
      // Nothing was hatched, so there is nothing to store or celebrate; the
      // round still closes warmly rather than dead-ending.
      _outcome = RushOutcome.goodRush;
    } else if (standing == null) {
      _outcome = RushOutcome.firstRush;
      await _bestStore.write(_engine.profileId, _cumulativeMs);
    } else if (run.pace < standing.pace) {
      // Pace, not total: this round may be longer than the stored one, and
      // "quicker" has to mean quicker per egg or every long round loses.
      _outcome = RushOutcome.personalBest;
      await _bestStore.write(_engine.profileId, _cumulativeMs);
    } else {
      // Slower than her best is still a completed round: warm, never
      // negative, and the stored best stays hers to race again.
      _outcome = RushOutcome.goodRush;
    }
    _phase = RushPhase.done;
    _playCue(SoundCue.trayDone);
    if (_outcome != RushOutcome.goodRush) _playCue(SoundCue.chime);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
