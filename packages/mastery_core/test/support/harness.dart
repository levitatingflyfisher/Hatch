import 'package:mastery_core/mastery_core.dart';

/// Base date for tests; all times derive from it (never DateTime.now()).
final day0 = DateTime(2026, 3, 2, 9);

DateTime onDay(int day, {int minute = 0}) =>
    day0.add(Duration(days: day, minutes: minute));

AnswerEvent ev(
  Fact fact, {
  required DateTime at,
  AskDirection direction = AskDirection.forward,
  EventKind kind = EventKind.review,
  Rung rung = Rung.bare,
  bool correct = true,
  int? latencyMs = 1500,
  bool production = true,
}) => AnswerEvent(
  fact: fact,
  direction: direction,
  kind: kind,
  rung: rung,
  correct: correct,
  latencyMs: latencyMs,
  production: production,
  at: at,
);

/// Climbs a fact grid -> bundled -> labeled -> bare with slow correct answers
/// (slow so the speed multiplier stays at 1.0 and no automaticity accrues).
/// Events are minutes apart within [day]; ends with the fact at rung bare,
/// srIndex 1 (due the next day).
void climbToBare(MasteryEngine engine, Fact fact, {int day = 0}) {
  var minute = 0;
  for (final rung in [Rung.grid, Rung.bundled, Rung.labeled]) {
    for (var i = 0; i < 2; i++) {
      engine.record(
        ev(
          fact,
          at: onDay(day, minute: minute++),
          kind: EventKind.construct,
          rung: rung,
          latencyMs: 4000,
          production: rung == Rung.labeled,
        ),
      );
    }
  }
}

/// Stable text form of a round for equality comparison across engines.
String describeRound(RoundSpec round) => [
  'placement=${round.placementActive}',
  'success=${round.expectedSuccess.toStringAsFixed(3)}',
  for (final e in round.events)
    '${e.fact.id}/${e.direction.name}/${e.kind.name}/${e.rung.name}/'
        '${e.choiceDistractors.join(',')}/${e.strategyHint?.name}',
].join(';');

/// A mid-journey engine: foundational families satisfied via probes, x4/x3
/// probed cold (placement over), squares+x4 vignettes done, two x4 facts
/// climbed to bare on day 1. Frontier is x4; dozens of reviews are due by
/// day 3.
MasteryEngine matureEngine() {
  final engine = MasteryEngine.fresh(now: day0);
  for (final family in [
    Family.x2,
    Family.x10,
    Family.x5,
    Family.x1,
    Family.x0,
  ]) {
    probeFamilyKnown(engine, family);
  }
  var minute = 120;
  for (final fact in const [Fact(4, 7), Fact(4, 9), Fact(3, 8), Fact(3, 9)]) {
    engine.record(
      ev(
        fact,
        at: onDay(0, minute: minute++),
        kind: EventKind.probe,
        correct: false,
        latencyMs: 5000,
      ),
    );
  }
  engine.markVignetteComplete(Family.squares, now: onDay(0, minute: 130));
  engine.markVignetteComplete(Family.x4, now: onDay(0, minute: 131));
  climbToBare(engine, const Fact(3, 4), day: 1);
  climbToBare(engine, const Fact(4, 4), day: 1);
  return engine;
}

/// Probes every fact a family owns as fast+correct bare production (the
/// "she already knows this" placement path).
void probeFamilyKnown(MasteryEngine engine, Family family, {int day = 0}) {
  const pack = MultiplicationPack();
  var minute = 0;
  for (final fact in pack.ownedBy(family)) {
    engine.record(
      ev(
        fact,
        at: onDay(day, minute: minute++),
        kind: EventKind.probe,
        latencyMs: 1400,
      ),
    );
  }
}
