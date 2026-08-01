import 'package:mastery_core/mastery_core.dart';
import 'package:test/test.dart';

import '../support/harness.dart';

void main() {
  const fact = Fact(2, 3);

  MasteryEngine masteredForward() {
    final engine = MasteryEngine.fresh(now: day0);
    climbToBare(engine, fact);
    for (final day in [1, 2, 3]) {
      engine.record(ev(fact, at: onDay(day), latencyMs: 1200));
    }
    return engine;
  }

  group('law 4', () {
    test('law 4: mastering a fact auto-PLANTS its mirror, which never '
        'auto-fires', () {
      final engine = MasteryEngine.fresh(now: day0);
      climbToBare(engine, fact);
      engine.record(ev(fact, at: onDay(1), latencyMs: 1200));
      engine.record(ev(fact, at: onDay(2), latencyMs: 1200));
      final firing = engine.record(ev(fact, at: onDay(3), latencyMs: 1200));
      expect(firing.factFired, isTrue);
      expect(firing.mirrorPlanted, isTrue);
      final cell = engine.samplerView(now: onDay(3))[fact]!;
      expect(cell.phase, Phase.automatic);
      expect(
        cell.mirrorFilled,
        isFalse,
        reason: 'planted enters rotation; it never auto-fires',
      );
    });

    test('law 4: the planted mirror enters rotation at rung labeled', () {
      final engine = masteredForward();
      final round = engine.assembleRound(RoundIntent.bee, now: onDay(4));
      final spec = round.events.firstWhere((e) => e.fact == fact);
      expect(spec.direction, AskDirection.reversed);
      expect(spec.rung, Rung.labeled);
    });

    test('law 4: one confirmed fast production of the mirrored ordering fills '
        'the mirror', () {
      final engine = masteredForward();
      engine.record(
        ev(
          fact,
          at: onDay(4),
          direction: AskDirection.reversed,
          rung: Rung.labeled,
          latencyMs: 1200,
        ),
      );
      expect(engine.samplerView(now: onDay(4))[fact]!.mirrorFilled, isTrue);
      // Confirmed: the bee now asks it at the fact's own rung again.
      final round = engine.assembleRound(RoundIntent.bee, now: onDay(4));
      final spec = round.events.firstWhere((e) => e.fact == fact);
      expect(spec.rung, Rung.bare);
    });

    test('law 4: recognition of the mirrored ordering does not confirm it', () {
      final engine = masteredForward();
      engine.record(
        ev(
          fact,
          at: onDay(4),
          direction: AskDirection.reversed,
          rung: Rung.labeled,
          latencyMs: 900,
          production: false,
        ),
      );
      expect(engine.samplerView(now: onDay(4))[fact]!.mirrorFilled, isFalse);
    });

    test('law 4: squares are their own mirror', () {
      final engine = MasteryEngine.fresh(now: day0);
      const square = Fact(2, 2);
      climbToBare(engine, square);
      RecordResult? r;
      for (final day in [1, 2, 3]) {
        r = engine.record(ev(square, at: onDay(day), latencyMs: 1200));
      }
      expect(r!.factFired, isTrue);
      expect(r.mirrorPlanted, isFalse);
      expect(engine.samplerView(now: onDay(3))[square]!.mirrorFilled, isTrue);
    });
  });
}
