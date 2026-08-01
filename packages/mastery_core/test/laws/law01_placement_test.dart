import 'package:mastery_core/mastery_core.dart';
import 'package:test/test.dart';

import '../support/harness.dart';

void main() {
  group('law 1', () {
    test('law 1: fresh engine starts in placement mode and interleaves bare '
        'production probes', () {
      final engine = MasteryEngine.fresh(now: day0);
      expect(engine.stats(now: day0).placementActive, isTrue);
      final round = engine.assembleRound(RoundIntent.piecing, now: day0);
      expect(round.placementActive, isTrue);
      final probes = round.events
          .where((e) => e.kind == EventKind.probe)
          .toList();
      expect(probes, isNotEmpty);
      for (final probe in probes) {
        expect(probe.rung, Rung.bare);
        expect(
          const MultiplicationPack().ownerOf(probe.fact),
          Family.x2,
          reason: 'placement walks the sequence, x2 first',
        );
      }
    });

    test('law 1: fast+correct probe instantiates at bare immediately; 2 spaced '
        'confirmations on distinct days grant automatic', () {
      final engine = MasteryEngine.fresh(now: day0);
      const fact = Fact(2, 6);
      engine.record(
        ev(fact, at: onDay(0), kind: EventKind.probe, latencyMs: 1400),
      );
      var cell = engine.samplerView(now: onDay(0))[fact]!;
      expect(cell.started, isTrue);
      expect(cell.rung, Rung.bare);
      expect(
        cell.phase,
        Phase.derived,
        reason: 'provisional, not yet automatic',
      );

      var r = engine.record(ev(fact, at: onDay(1), latencyMs: 1400));
      expect(r.factFired, isFalse);
      r = engine.record(ev(fact, at: onDay(2), latencyMs: 1400));
      expect(r.factFired, isTrue);
      cell = engine.samplerView(now: onDay(2))[fact]!;
      expect(cell.phase, Phase.automatic);
    });

    test('law 1: probe evidence unlocks families', () {
      final engine = MasteryEngine.fresh(now: day0);
      final unlocked = <Family>{};
      const pack = MultiplicationPack();
      var minute = 0;
      for (final fact in pack.ownedBy(Family.x2)) {
        final r = engine.record(
          ev(
            fact,
            at: onDay(0, minute: minute++),
            kind: EventKind.probe,
            latencyMs: 1400,
          ),
        );
        unlocked.addAll(r.familiesUnlocked);
      }
      expect(
        engine.familyStatus(Family.x2),
        FamilyStatus.open,
        reason: 'demonstrated knowledge is never re-taught',
      );
      expect(unlocked, contains(Family.x10));
    });

    test('law 1: a child fast-correct on the foundational probes reaches '
        'frontier x4 in session 1', () {
      final engine = MasteryEngine.fresh(now: day0);
      final families = [Family.x2, Family.x10, Family.x5, Family.x1, Family.x0];
      for (var i = 0; i < families.length; i++) {
        probeFamilyKnown(engine, families[i]);
      }
      expect(engine.stats(now: onDay(0)).frontier, Family.squares);
      engine.markVignetteComplete(Family.squares, now: onDay(0, minute: 90));
      expect(engine.stats(now: onDay(0)).frontier, Family.x4);
      expect(engine.familyStatus(Family.x4), FamilyStatus.vignetteDue);
    });

    test('law 1: two consecutive cold families end placement', () {
      final engine = MasteryEngine.fresh(now: day0);
      var minute = 0;
      for (var round = 0; round < 4; round++) {
        final spec = engine.assembleRound(
          RoundIntent.piecing,
          now: onDay(0, minute: minute),
        );
        final probes = spec.events.where((e) => e.kind == EventKind.probe);
        if (probes.isEmpty) {
          break;
        }
        for (final probe in probes) {
          engine.record(
            ev(
              probe.fact,
              at: onDay(0, minute: minute++),
              kind: EventKind.probe,
              correct: false,
              latencyMs: 5000,
            ),
          );
        }
      }
      expect(
        engine.stats(now: onDay(0, minute: minute)).placementActive,
        isFalse,
      );
      final after = engine.assembleRound(
        RoundIntent.piecing,
        now: onDay(0, minute: minute),
      );
      expect(after.events.where((e) => e.kind == EventKind.probe), isEmpty);
    });
  });
}
