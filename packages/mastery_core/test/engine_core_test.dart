import 'package:mastery_core/mastery_core.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

void main() {
  const f34 = Fact(3, 4);

  group('MasteryEngine.fresh', () {
    test('starts in placement mode with all 66 facts unstarted', () {
      final engine = MasteryEngine.fresh(now: day0);
      expect(engine.stats(now: day0).placementActive, isTrue);
      final view = engine.samplerView(now: day0);
      expect(view.cells.length, 66);
      for (final cell in view.cells.values) {
        expect(cell.started, isFalse);
        expect(cell.phase, Phase.counting);
        expect(cell.rung, Rung.grid);
        expect(cell.dueNow, isFalse);
      }
    });

    test('x2 is the first family offered; the rest start locked', () {
      final engine = MasteryEngine.fresh(now: day0);
      expect(engine.familyStatus(Family.x2), FamilyStatus.vignetteDue);
      expect(engine.familyStatus(Family.x10), FamilyStatus.locked);
      expect(engine.familyStatus(Family.x8), FamilyStatus.locked);
      final vignette = engine.nextVignette();
      expect(vignette, isNotNull);
      expect(vignette!.family, Family.x2);
      expect(vignette.route, StrategyRoute.skipCount);
      engine.markVignetteComplete(Family.x2, now: day0);
      expect(engine.familyStatus(Family.x2), FamilyStatus.open);
    });
  });

  group('weaning ladder', () {
    test('two consecutive correct at the current rung advance one rung', () {
      final engine = MasteryEngine.fresh(now: day0);
      var r = engine.record(
        ev(f34, at: onDay(0), kind: EventKind.construct, rung: Rung.grid),
      );
      expect(r.rungAdvanced, isFalse);
      r = engine.record(
        ev(
          f34,
          at: onDay(0, minute: 1),
          kind: EventKind.construct,
          rung: Rung.grid,
        ),
      );
      expect(r.rungAdvanced, isTrue);
      expect(engine.samplerView(now: day0)[f34]!.rung, Rung.bundled);
    });

    test('a miss resets the advance streak', () {
      final engine = MasteryEngine.fresh(now: day0);
      engine.record(
        ev(f34, at: onDay(0), kind: EventKind.construct, rung: Rung.grid),
      );
      engine.record(
        ev(
          f34,
          at: onDay(0, minute: 1),
          kind: EventKind.construct,
          rung: Rung.grid,
          correct: false,
        ),
      );
      final r = engine.record(
        ev(
          f34,
          at: onDay(0, minute: 2),
          kind: EventKind.construct,
          rung: Rung.grid,
        ),
      );
      expect(r.rungAdvanced, isFalse);
      expect(engine.samplerView(now: day0)[f34]!.rung, Rung.grid);
    });

    test('climb helper takes a fact to bare', () {
      final engine = MasteryEngine.fresh(now: day0);
      climbToBare(engine, f34);
      expect(engine.samplerView(now: onDay(0))[f34]!.rung, Rung.bare);
    });
  });

  group('record', () {
    test(
      'is idempotent per event: an exact consecutive duplicate is a no-op',
      () {
        final engine = MasteryEngine.fresh(now: day0);
        final event = ev(f34, at: onDay(0), rung: Rung.grid, correct: false);
        engine.record(event);
        final before = engine.snapshot();
        final r = engine.record(event);
        expect(engine.snapshot(), equals(before));
        expect(r.rungAdvanced, isFalse);
        expect(r.rungDemoted, isFalse);
        expect(r.requeue, isNull);
      },
    );
  });
}
