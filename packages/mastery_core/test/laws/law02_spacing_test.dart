import 'package:mastery_core/mastery_core.dart';
import 'package:test/test.dart';

import '../support/harness.dart';

void main() {
  const fact = Fact(2, 4);

  bool dueAt(MasteryEngine engine, DateTime now) =>
      engine.samplerView(now: now)[fact]!.dueNow;

  group('law 2', () {
    test('law 2: spacing clock is calendar days — same-session then '
        '1d, 3d, 7d, 14d, 30d at multiplier 1.0', () {
      final engine = MasteryEngine.fresh(now: day0);
      // The intro's first correct answer moves the fact off the same-session
      // rung (index 0) and schedules it a calendar day out.
      engine.record(
        ev(
          fact,
          at: onDay(0),
          kind: EventKind.construct,
          rung: Rung.grid,
          production: false,
          latencyMs: null,
        ),
      );
      climbToBare(engine, fact); // ends day 0, srIndex 1 (due +1d)

      expect(dueAt(engine, onDay(0, minute: 30)), isFalse);
      expect(dueAt(engine, day0.add(const Duration(hours: 26))), isTrue);

      // Slow-but-correct answers keep the speed multiplier at 1.0, so the
      // schedule walks the nominal ladder exactly: 1d -> 3d -> 7d -> 14d -> 30d.
      final reviewDays = [1, 4, 11, 25];
      final nextGapDays = [3, 7, 14, 30];
      for (var i = 0; i < reviewDays.length; i++) {
        final at = onDay(reviewDays[i]);
        expect(dueAt(engine, at), isTrue, reason: 'review $i should be due');
        engine.record(ev(fact, at: at, latencyMs: 4000));
        expect(dueAt(engine, onDay(reviewDays[i], minute: 5)), isFalse);
        final justBefore = at.add(Duration(hours: nextGapDays[i] * 24 - 2));
        final justAfter = at.add(Duration(hours: nextGapDays[i] * 24 + 2));
        expect(
          dueAt(engine, justBefore),
          isFalse,
          reason: 'gap $i should not be due before ${nextGapDays[i]}d',
        );
        expect(
          dueAt(engine, justAfter),
          isTrue,
          reason: 'gap $i should be due after ${nextGapDays[i]}d',
        );
      }
    });

    test(
      'law 2: fast correct due reviews lengthen the schedule (speed x1.15)',
      () {
        final engine = MasteryEngine.fresh(now: day0);
        climbToBare(engine, fact);
        engine.record(ev(fact, at: onDay(1), latencyMs: 4000)); // -> 3d nominal
        // Fast correct due review: multiplier grows, so the next gap (7d
        // nominal) stretches beyond 7d.
        engine.record(ev(fact, at: onDay(4), latencyMs: 1200));
        expect(
          dueAt(engine, onDay(4).add(const Duration(hours: 7 * 24 + 2))),
          isFalse,
          reason: 'nominal 7d gap must be stretched',
        );
        expect(dueAt(engine, onDay(4).add(const Duration(hours: 194))), isTrue);
      },
    );

    test('law 2: automatic requires correct+fast production on 3+ distinct '
        'calendar days', () {
      final engine = MasteryEngine.fresh(now: day0);
      climbToBare(engine, fact);
      var r = engine.record(ev(fact, at: onDay(1), latencyMs: 1200));
      expect(r.factFired, isFalse);
      // Second fast answer on the SAME day must not count as a new day.
      r = engine.record(ev(fact, at: onDay(1, minute: 10), latencyMs: 1200));
      expect(r.factFired, isFalse);
      r = engine.record(ev(fact, at: onDay(2), latencyMs: 1200));
      expect(r.factFired, isFalse);
      expect(
        engine.samplerView(now: onDay(2))[fact]!.phase,
        isNot(Phase.automatic),
      );
      r = engine.record(ev(fact, at: onDay(3), latencyMs: 1200));
      expect(r.factFired, isTrue);
      expect(engine.samplerView(now: onDay(3))[fact]!.phase, Phase.automatic);
    });

    test('law 2: overdue is never penalized — no decay from time alone', () {
      final engine = MasteryEngine.fresh(now: day0);
      climbToBare(engine, fact);
      for (final day in [1, 2, 3]) {
        engine.record(ev(fact, at: onDay(day), latencyMs: 1200));
      }
      final before = engine.samplerView(now: onDay(3))[fact]!;
      expect(before.phase, Phase.automatic);

      final yearLater = onDay(400);
      final after = engine.samplerView(now: yearLater)[fact]!;
      expect(after.phase, Phase.automatic);
      expect(after.rung, before.rung);
      expect(
        after.dueNow,
        isTrue,
        reason: 'due, but only eligible, not punished',
      );
      // Answering after a year still advances the schedule normally.
      final r = engine.record(ev(fact, at: yearLater, latencyMs: 1200));
      expect(r.rungDemoted, isFalse);
    });
  });
}
