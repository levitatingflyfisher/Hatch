import 'package:mastery_core/mastery_core.dart';
import 'package:test/test.dart';

import '../support/harness.dart';

void main() {
  group('law 8', () {
    test('law 8: a miss opens a requeue debt the engine tracks until '
        're-retrieval succeeds', () {
      final engine = matureEngine();
      const missed = Fact(2, 8);
      final r = engine.record(
        ev(missed, at: onDay(3), correct: false, latencyMs: 3000),
      );
      expect(r.requeue, missed);
      expect(engine.pendingRequeues, [missed]);

      // Both round intents lead with the debt.
      final piecing = engine.assembleRound(
        RoundIntent.piecing,
        now: onDay(3, minute: 1),
      );
      expect(piecing.events.first.fact, missed);
      final bee = engine.assembleRound(
        RoundIntent.bee,
        now: onDay(3, minute: 1),
      );
      expect(bee.events.first.fact, missed);

      // Another wrong answer keeps the debt open.
      engine.record(
        ev(missed, at: onDay(3, minute: 2), correct: false, latencyMs: 3000),
      );
      expect(engine.pendingRequeues, [missed]);

      // Only successful re-retrieval closes it.
      engine.record(ev(missed, at: onDay(3, minute: 3), latencyMs: 2000));
      expect(engine.pendingRequeues, isEmpty);
    });

    test('law 8: probe misses do not requeue (placement is diagnosis)', () {
      final engine = MasteryEngine.fresh(now: day0);
      final r = engine.record(
        ev(
          const Fact(2, 9),
          at: onDay(0),
          kind: EventKind.probe,
          correct: false,
          latencyMs: 5000,
        ),
      );
      expect(r.requeue, isNull);
      expect(engine.pendingRequeues, isEmpty);
    });

    test('law 8: the requeued ask re-presents the missed direction', () {
      final engine = matureEngine();
      const missed = Fact(2, 8);
      engine.record(
        ev(
          missed,
          at: onDay(3),
          direction: AskDirection.reversed,
          correct: false,
          latencyMs: 3000,
        ),
      );
      final round = engine.assembleRound(
        RoundIntent.piecing,
        now: onDay(3, minute: 1),
      );
      expect(round.events.first.fact, missed);
      expect(round.events.first.direction, AskDirection.reversed);
    });
  });
}
