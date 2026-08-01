import 'fact.dart';

/// Matches the app's answer_events Drift table row-for-row; the engine is fed
/// these and never reads a clock of its own.
enum EventKind { probe, construct, vignettePractice, review, bee, remediation }

class AnswerEvent {
  const AnswerEvent({
    required this.fact,
    required this.direction,
    required this.kind,
    required this.rung,
    required this.correct,
    this.latencyMs,
    required this.production,
    required this.at,
  });

  final Fact fact;
  final AskDirection direction;
  final EventKind kind;
  final Rung rung;
  final bool correct;

  /// Prompt-to-first-keypress; null when untimed (construct manipulation).
  final int? latencyMs;

  /// True = numpad/typed production; false = choice buttons. Only production
  /// events may ever earn automaticity credit (law 3).
  final bool production;

  final DateTime at;

  /// Identity for record()'s per-event idempotency (law: replaying the same
  /// persisted event must not double-count).
  String get dedupeKey =>
      '${fact.id}|${direction.index}|${kind.index}|${rung.index}|$correct|'
      '$latencyMs|$production|${at.millisecondsSinceEpoch}';
}

/// What one recorded event changed.
class RecordResult {
  const RecordResult({
    this.rungAdvanced = false,
    this.rungDemoted = false,
    this.factFired = false,
    this.familiesUnlocked = const [],
    this.mirrorPlanted = false,
    this.requeue,
    this.offerStrategySwitch,
    this.prerequisiteProbe,
  });

  static const none = RecordResult();

  final bool rungAdvanced;
  final bool rungDemoted;

  /// The fact's phase became automatic on this event.
  final bool factFired;

  final List<Family> familiesUnlocked;
  final bool mirrorPlanted;

  /// Same fact must re-ask before the round closes (miss law 8).
  final Fact? requeue;

  /// Set on 3rd consecutive miss of the same fact (law 5).
  final StrategyRoute? offerStrategySwitch;

  /// Chronic failure: probe this strategy-source component fact soon (law 5).
  final Fact? prerequisiteProbe;
}
