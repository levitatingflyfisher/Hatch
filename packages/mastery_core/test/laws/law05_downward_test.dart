import 'package:mastery_core/mastery_core.dart';
import 'package:test/test.dart';

import '../support/harness.dart';

void main() {
  const fact = Fact(4, 6); // owned by x4, route foldDouble from x2

  /// Opens families up to x4 via known-child probes plus vignettes, then
  /// climbs 4x6 to bare. Mirrors the real reachable path (no state injection).
  MasteryEngine engineWithX4Open() {
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
    engine.markVignetteComplete(Family.squares, now: onDay(0, minute: 200));
    engine.markVignetteComplete(Family.x4, now: onDay(0, minute: 201));
    expect(engine.familyStatus(Family.x4), FamilyStatus.open);
    climbToBare(engine, fact, day: 1);
    return engine;
  }

  group('law 5', () {
    test('law 5: a miss demotes one rung and floors at grid', () {
      final engine = MasteryEngine.fresh(now: day0);
      climbToBare(engine, fact);
      var r = engine.record(
        ev(fact, at: onDay(1), correct: false, latencyMs: 3000),
      );
      expect(r.rungDemoted, isTrue);
      expect(engine.samplerView(now: onDay(1))[fact]!.rung, Rung.labeled);

      // Grid floor: repeated misses on a grid-rung fact stay at grid.
      final fresh = MasteryEngine.fresh(now: day0);
      fresh.record(
        ev(
          fact,
          at: onDay(0),
          kind: EventKind.construct,
          rung: Rung.grid,
          correct: false,
        ),
      );
      r = fresh.record(
        ev(
          fact,
          at: onDay(0, minute: 1),
          kind: EventKind.construct,
          rung: Rung.grid,
          correct: false,
        ),
      );
      expect(r.rungDemoted, isFalse);
      expect(fresh.samplerView(now: onDay(0))[fact]!.rung, Rung.grid);
    });

    test('law 5: a lapse shortens the spacing interval', () {
      final engine = MasteryEngine.fresh(now: day0);
      climbToBare(engine, fact);
      // Walk the schedule out to the 7d interval (srIndex 3).
      engine.record(ev(fact, at: onDay(1), latencyMs: 4000));
      engine.record(ev(fact, at: onDay(4), latencyMs: 4000));
      // Miss at day 11: interval index drops by 2, next correct schedules 1d.
      engine.record(ev(fact, at: onDay(11), correct: false, latencyMs: 3000));
      engine.record(ev(fact, at: onDay(11, minute: 5), latencyMs: 4000));
      expect(
        engine
            .samplerView(now: onDay(11).add(const Duration(hours: 26)))[fact]!
            .dueNow,
        isTrue,
        reason: 'post-lapse schedule must be back near the short end',
      );
    });

    test('law 5: 3rd consecutive miss offers the strategy switch', () {
      final engine = MasteryEngine.fresh(now: day0);
      climbToBare(engine, fact);
      var r = engine.record(
        ev(fact, at: onDay(1), correct: false, latencyMs: 3000),
      );
      expect(r.offerStrategySwitch, isNull);
      r = engine.record(
        ev(fact, at: onDay(1, minute: 1), correct: false, latencyMs: 3000),
      );
      expect(r.offerStrategySwitch, isNull);
      r = engine.record(
        ev(fact, at: onDay(1, minute: 2), correct: false, latencyMs: 3000),
      );
      expect(r.offerStrategySwitch, StrategyRoute.foldDouble);
    });

    test('law 5: 4 lapses on a derived-family fact re-open the family '
        'vignette', () {
      final engine = engineWithX4Open();
      expect(engine.familyStatus(Family.x4), FamilyStatus.open);
      // Four lapses, broken up so the 3-consecutive switch never fires.
      engine.record(ev(fact, at: onDay(2), correct: false, latencyMs: 3000));
      engine.record(
        ev(fact, at: onDay(2, minute: 1), correct: false, latencyMs: 3000),
      );
      engine.record(
        ev(fact, at: onDay(2, minute: 2), rung: Rung.bundled, latencyMs: 4000),
      );
      engine.record(
        ev(
          fact,
          at: onDay(2, minute: 3),
          rung: Rung.bundled,
          correct: false,
          latencyMs: 3000,
        ),
      );
      final r = engine.record(
        ev(
          fact,
          at: onDay(2, minute: 4),
          rung: Rung.grid,
          correct: false,
          latencyMs: 3000,
        ),
      );
      expect(r.offerStrategySwitch, isNull);
      expect(
        engine.familyStatus(Family.x4),
        FamilyStatus.vignetteDue,
        reason: '4th lapse re-opens the strategy vignette',
      );
    });

    test('law 5: chronic failure (5 consecutive misses) probes the '
        'strategy-source component fact', () {
      final engine = MasteryEngine.fresh(now: day0);
      climbToBare(engine, fact);
      RecordResult? r;
      for (var i = 0; i < 5; i++) {
        r = engine.record(
          ev(fact, at: onDay(1, minute: i), correct: false, latencyMs: 3000),
        );
      }
      expect(
        r!.prerequisiteProbe,
        const Fact(2, 6),
        reason: 'foldDouble on 4x6 rests on 2x6',
      );
    });
  });
}
