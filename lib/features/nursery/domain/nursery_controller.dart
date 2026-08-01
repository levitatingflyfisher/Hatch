import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:mastery_core/mastery_core.dart';

import '../../../core/engine/engine_service.dart';
import '../../../shared/answer/answer_input.dart';
import '../../../shared/audio/sound_cue.dart';
import '../../../shared/painters/cell_fill_sweep.dart';
import '../../../shared/painters/shortfall_overflow.dart';
import '../../../shared/scene/seeded.dart';

/// Where the round is right now. Per event the flow is
/// building? → answering → feedback → next; a 3rd consecutive miss detours
/// through strategyOffer → strategyPlaying → a remediation re-ask.
enum NurseryPhase {
  idle,
  vignette,
  building,
  answering,
  feedbackCorrect,
  feedbackMiss,
  strategyOffer,
  strategyPlaying,
  celebrating,
  hatching,
  done,
}

/// The 3rd-miss strategy choice: the engine's offered route, the family's
/// alternate when it has one, and always the free "show me" reveal.
class StrategyOffer {
  const StrategyOffer({
    required this.fact,
    required this.direction,
    required this.offered,
    required this.alternate,
  });

  final Fact fact;
  final AskDirection direction;
  final StrategyRoute offered;
  final StrategyRoute? alternate;
}

/// The Nursery round state machine over one EngineService. The engine
/// decides what to ask (RoundSpec) and what each answer changed
/// (RecordResult); this controller sequences the child's path through it:
/// vignette → 3 forced practices → events → requeue continuations →
/// celebration → hatch moments. All time flows through package:clock.
class NurseryController extends ChangeNotifier {
  NurseryController(this._service, {void Function(SoundCue cue)? playCue})
    : _playCue = playCue ?? _silent;

  static void _silent(SoundCue cue) {}

  static const _pack = MultiplicationPack();
  static const practiceCount = 3;

  final EngineService _service;
  final void Function(SoundCue cue) _playCue;

  /// Read-only reach into the engine (requeue debts, sampler, stats).
  EngineService get service => _service;

  /// Prompt→first-key latency for the current ask (engine law 3).
  final AnswerStopwatch stopwatch = AnswerStopwatch();

  NurseryPhase _phase = NurseryPhase.idle;
  final List<RoundEventSpec> _events = [];
  int _eventIndex = 0;
  VignetteSpec? _vignette;
  StrategyOffer? _strategyOffer;
  StrategyRoute? _playingRoute;
  bool _showMeReveal = false;
  final List<Fact> _hatchQueue = [];
  int _hatchIndex = 0;
  SweepTier _sweepTier = SweepTier.slow;
  ShortfallOverflow? _shortfall;
  bool _submitting = false;

  NurseryPhase get phase => _phase;
  List<RoundEventSpec> get events => List.unmodifiable(_events);
  int get eventIndex => _eventIndex;
  int get completedCount => math.min(_eventIndex, _events.length);
  RoundEventSpec? get current =>
      _eventIndex < _events.length ? _events[_eventIndex] : null;
  VignetteSpec? get vignette => _vignette;
  StrategyOffer? get strategyOffer => _strategyOffer;

  /// The route now playing as a mini-vignette; null while phase is
  /// strategyPlaying means the "show me" reveal instead.
  StrategyRoute? get playingRoute => _playingRoute;
  bool get showMeReveal => _showMeReveal;

  List<Fact> get hatchQueue => List.unmodifiable(_hatchQueue);
  int get hatchIndex => _hatchIndex;
  Fact? get currentHatch =>
      _phase == NurseryPhase.hatching && _hatchIndex < _hatchQueue.length
      ? _hatchQueue[_hatchIndex]
      : null;
  SweepTier get sweepTier => _sweepTier;
  ShortfallOverflow? get shortfall => _shortfall;

  /// Display order respects the asked direction (reversed shows b×a).
  (int, int) displayFactors(RoundEventSpec spec) =>
      spec.direction == AskDirection.forward
      ? (spec.fact.a, spec.fact.b)
      : (spec.fact.b, spec.fact.a);

  /// Recognition (choice buttons) only for review asks still on picture
  /// rungs; everything else is production on the numpad.
  bool isChoice(RoundEventSpec spec) =>
      spec.kind == EventKind.review &&
      (spec.rung == Rung.grid || spec.rung == Rung.bundled);

  bool needsConstruction(RoundEventSpec spec) =>
      spec.kind == EventKind.construct ||
      spec.kind == EventKind.vignettePractice;

  /// Distractors + the true product in a seeded shuffle (stable per event,
  /// no wall-clock randomness).
  List<int> choiceOptions(RoundEventSpec spec) {
    final options = [...spec.choiceDistractors, spec.fact.product];
    final seed = seededInt(seedFor(spec.fact.a, spec.fact.b), _eventIndex);
    for (var i = options.length - 1; i > 0; i--) {
      final j = seededPick(seed, i, i + 1);
      final swap = options[i];
      options[i] = options[j];
      options[j] = swap;
    }
    return options;
  }

  /// Starts (or restarts) a round. If the engine owes a strategy vignette it
  /// plays first; completion is only recorded when the child finishes it, so
  /// an interrupted vignette simply replays next time.
  void startRound() {
    _events.clear();
    _eventIndex = 0;
    _hatchQueue.clear();
    _hatchIndex = 0;
    _strategyOffer = null;
    _playingRoute = null;
    _showMeReveal = false;
    _shortfall = null;
    _vignette = _service.engine.nextVignette();
    if (_vignette != null) {
      _phase = NurseryPhase.vignette;
      notifyListeners();
      return;
    }
    _beginEvents(_assembled());
  }

  List<RoundEventSpec> _assembled() =>
      _service.assembleRound(RoundIntent.piecing).events;

  /// The child finished watching the vignette: record it, then lead the
  /// round with 3 forced practices before the engine's own events.
  Future<void> vignetteFinished() async {
    final spec = _vignette;
    if (spec == null || _phase != NurseryPhase.vignette) return;
    await _service.completeVignette(spec.family);
    _playCue(SoundCue.chime);
    _vignette = null;
    _beginEvents([..._practicesFor(spec), ..._assembled()]);
  }

  void _beginEvents(List<RoundEventSpec> specs) {
    _events
      ..clear()
      ..addAll(specs);
    _eventIndex = 0;
    if (_events.isEmpty) {
      _completeRound();
      return;
    }
    _enterEvent();
  }

  void _enterEvent() {
    final spec = _events[_eventIndex];
    if (needsConstruction(spec)) {
      _phase = NurseryPhase.building;
    } else {
      _phase = NurseryPhase.answering;
      stopwatch.promptShown();
    }
    notifyListeners();
  }

  /// The construct surface finished its manipulation; the answer step begins
  /// now, so latency measures recall of the just-built tray.
  void constructionComplete() {
    if (_phase != NurseryPhase.building) return;
    _phase = NurseryPhase.answering;
    stopwatch.promptShown();
    notifyListeners();
  }

  void answerKeyPressed() => stopwatch.keyPressed();

  Future<void> submitAnswer(int value, {required bool production}) async {
    if (_phase != NurseryPhase.answering || _submitting) return;
    final spec = _events[_eventIndex];
    _submitting = true;
    final correct = value == spec.fact.product;
    final result = await _service.record(
      AnswerEvent(
        fact: spec.fact,
        direction: spec.direction,
        kind: spec.kind,
        rung: spec.rung,
        correct: correct,
        latencyMs: stopwatch.firstKeyLatencyMs,
        production: production,
        at: clock.now(),
      ),
    );
    _submitting = false;
    if (result.factFired) _hatchQueue.add(spec.fact);
    if (result.familiesUnlocked.isNotEmpty) _playCue(SoundCue.chime);
    if (correct) {
      _shortfall = null;
      _sweepTier = _tierFor(stopwatch.firstKeyLatencyMs);
      _phase = NurseryPhase.feedbackCorrect;
      _playCue(SoundCue.settle);
    } else {
      final (a, b) = displayFactors(spec);
      _shortfall = ShortfallOverflow(a: a, b: b, answer: value);
      _strategyOffer = result.offerStrategySwitch == null
          ? null
          : _offerFor(spec, result.offerStrategySwitch!);
      _phase = NurseryPhase.feedbackMiss;
      _playCue(SoundCue.miss);
    }
    notifyListeners();
  }

  static SweepTier _tierFor(int? latencyMs) {
    if (latencyMs == null) return SweepTier.slow;
    if (latencyMs <= 1600) return SweepTier.fast;
    if (latencyMs <= 3000) return SweepTier.medium;
    return SweepTier.slow;
  }

  StrategyOffer _offerFor(RoundEventSpec spec, StrategyRoute offered) {
    final routes = _pack.routesFor(_pack.ownerOf(spec.fact));
    StrategyRoute? alternate;
    for (final route in routes) {
      if (route != offered) {
        alternate = route;
        break;
      }
    }
    return StrategyOffer(
      fact: spec.fact,
      direction: spec.direction,
      offered: offered,
      alternate: alternate,
    );
  }

  /// The feedback choreography finished. A miss that tripped the 3rd-miss
  /// threshold pauses into the strategy offer; otherwise the round moves on
  /// (the engine holds the requeue — the re-ask returns later, never a
  /// reveal-then-move-on).
  void feedbackDone() {
    if (_phase == NurseryPhase.feedbackCorrect) {
      _advance();
      return;
    }
    if (_phase != NurseryPhase.feedbackMiss) return;
    _shortfall = null;
    if (_strategyOffer != null) {
      _phase = NurseryPhase.strategyOffer;
      notifyListeners();
      return;
    }
    _advance();
  }

  void chooseStrategy(StrategyRoute route) {
    if (_phase != NurseryPhase.strategyOffer) return;
    _playingRoute = route;
    _showMeReveal = false;
    _phase = NurseryPhase.strategyPlaying;
    notifyListeners();
  }

  /// The flash-count reveal: free, never shames, still followed by the
  /// re-ask (closure requires re-retrieval, not observation).
  void chooseShowMe() {
    if (_phase != NurseryPhase.strategyOffer) return;
    _playingRoute = null;
    _showMeReveal = true;
    _phase = NurseryPhase.strategyPlaying;
    notifyListeners();
  }

  /// The chosen route (or reveal) finished playing: re-ask the same fact
  /// immediately, unfolded to labeled.
  void strategyPlayed() {
    if (_phase != NurseryPhase.strategyPlaying) return;
    final offer = _strategyOffer!;
    final route = _playingRoute;
    _strategyOffer = null;
    _playingRoute = null;
    _showMeReveal = false;
    _events.insert(
      _eventIndex + 1,
      RoundEventSpec(
        fact: offer.fact,
        direction: offer.direction,
        kind: EventKind.remediation,
        rung: Rung.labeled,
        choiceDistractors: const [],
        strategyHint: route,
      ),
    );
    _advance();
  }

  void _advance() {
    _eventIndex++;
    if (_eventIndex < _events.length) {
      _enterEvent();
      return;
    }
    // The round only closes once every miss has been re-retrieved (law 8):
    // assemble a continuation and take just the leading re-asks.
    final pending = _service.engine.pendingRequeues;
    if (pending.isNotEmpty) {
      final continuation = _assembled();
      final take = math.min(pending.length, continuation.length);
      if (take > 0) {
        _events.addAll(continuation.take(take));
        _enterEvent();
        return;
      }
    }
    _completeRound();
  }

  void _completeRound() {
    _phase = NurseryPhase.celebrating;
    _playCue(SoundCue.trayDone);
    notifyListeners();
  }

  void celebrationDone() {
    if (_phase != NurseryPhase.celebrating) return;
    _hatchIndex = 0;
    _phase = _hatchQueue.isEmpty ? NurseryPhase.done : NurseryPhase.hatching;
    notifyListeners();
  }

  void advanceHatch() {
    if (_phase != NurseryPhase.hatching) return;
    _hatchIndex++;
    if (_hatchIndex >= _hatchQueue.length) {
      _phase = NurseryPhase.done;
    }
    notifyListeners();
  }

  /// Three forced practices on the freshly-taught family: construct-lite
  /// (the seam arrives pre-highlighted) for seam routes, plain STACK for
  /// skip-count families.
  List<RoundEventSpec> _practicesFor(VignetteSpec spec) {
    final route = spec.route;
    List<Fact> facts;
    if (spec.family == Family.squares) {
      final sampler = _service.samplerView();
      facts = [
        for (var n = 2; n <= 10; n++)
          if (sampler[Fact(n, n)]?.phase != Phase.automatic) Fact(n, n),
      ];
      if (facts.isEmpty) {
        facts = [for (var n = 2; n <= 4; n++) Fact(n, n)];
      }
    } else {
      facts = [..._pack.ownedBy(spec.family).where((f) => f.a > 0)]
        ..sort((x, y) => x.product.compareTo(y.product));
      if (facts.isEmpty) facts = _pack.ownedBy(spec.family);
    }
    final skipCount = route == StrategyRoute.skipCount;
    return [
      for (final fact in facts.take(practiceCount))
        RoundEventSpec(
          fact: fact,
          direction: AskDirection.forward,
          kind: EventKind.vignettePractice,
          rung: skipCount ? Rung.grid : Rung.labeled,
          choiceDistractors: const [],
          strategyHint: skipCount ? null : route,
        ),
    ];
  }
}
