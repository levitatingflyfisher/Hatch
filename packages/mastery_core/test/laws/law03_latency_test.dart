import 'package:mastery_core/mastery_core.dart';
import 'package:test/test.dart';

import '../support/harness.dart';

void main() {
  const fact = Fact(2, 4);
  const feeder = Fact(2, 3);

  /// Three distinct-day answers at [latencyMs]; returns final phase.
  Phase phaseAfterThreeDays(
    MasteryEngine engine,
    int latencyMs, {
    bool production = true,
  }) {
    for (final day in [1, 2, 3]) {
      engine.record(
        ev(fact, at: onDay(day), latencyMs: latencyMs, production: production),
      );
    }
    return engine.samplerView(now: onDay(3))[fact]!.phase;
  }

  group('law 3', () {
    test('law 3: default automaticity bound is ~2500ms — 2400 is fast, '
        '2600 is not', () {
      final fastEngine = MasteryEngine.fresh(now: day0);
      climbToBare(fastEngine, fact);
      expect(phaseAfterThreeDays(fastEngine, 2400), Phase.automatic);

      final slowEngine = MasteryEngine.fresh(now: day0);
      climbToBare(slowEngine, fact);
      expect(phaseAfterThreeDays(slowEngine, 2600), isNot(Phase.automatic));
    });

    test('law 3: recognition (production=false) never earns automaticity', () {
      final engine = MasteryEngine.fresh(now: day0);
      climbToBare(engine, fact);
      expect(
        phaseAfterThreeDays(engine, 900, production: false),
        isNot(Phase.automatic),
      );
    });

    test('law 3: untimed events (latencyMs null) never earn automaticity', () {
      final engine = MasteryEngine.fresh(now: day0);
      climbToBare(engine, fact);
      for (final day in [1, 2, 3]) {
        engine.record(
          ev(fact, at: onDay(day), kind: EventKind.construct, latencyMs: null),
        );
      }
      expect(
        engine.samplerView(now: onDay(3))[fact]!.phase,
        isNot(Phase.automatic),
      );
    });

    test('law 3: a quick-fingered child tightens the bound — motor baseline '
        '400ms makes 2400ms no longer fast', () {
      final engine = MasteryEngine.fresh(now: day0);
      climbToBare(engine, feeder);
      // 12 reliable 400ms production answers pull the motor baseline down to
      // its clamp floor region; threshold becomes ~400 + recall budget.
      for (var i = 0; i < 12; i++) {
        engine.record(ev(feeder, at: onDay(0, minute: 30 + i), latencyMs: 400));
      }
      climbToBare(engine, fact);
      expect(phaseAfterThreeDays(engine, 2400), isNot(Phase.automatic));
    });

    test('law 3: a slower-motor child relaxes the bound — baseline 1400ms '
        'makes 2600ms fast', () {
      final engine = MasteryEngine.fresh(now: day0);
      climbToBare(engine, feeder);
      for (var i = 0; i < 12; i++) {
        engine.record(
          ev(feeder, at: onDay(0, minute: 30 + i), latencyMs: 1400),
        );
      }
      climbToBare(engine, fact);
      expect(phaseAfterThreeDays(engine, 2600), Phase.automatic);
    });
  });
}
