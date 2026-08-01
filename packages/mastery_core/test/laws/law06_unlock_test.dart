import 'package:mastery_core/mastery_core.dart';
import 'package:test/test.dart';

import '../support/harness.dart';

void main() {
  const pack = MultiplicationPack();

  /// Probes [fast] facts fast+correct, [slow] facts correct-but-slow, and
  /// [wrong] facts incorrect, all on day 0.
  MasteryEngine probedEngine({required int fast, int slow = 0, int wrong = 0}) {
    final engine = MasteryEngine.fresh(now: day0);
    final owned = [...pack.ownedBy(Family.x2)]
      ..sort((x, y) => x.product.compareTo(y.product));
    var minute = 0;
    for (var i = 0; i < owned.length; i++) {
      final int? latency;
      final bool correct;
      if (i < fast) {
        latency = 1400;
        correct = true;
      } else if (i < fast + slow) {
        latency = 5000;
        correct = true;
      } else {
        latency = 5000;
        correct = false;
      }
      engine.record(
        ev(
          owned[i],
          at: onDay(0, minute: minute++),
          kind: EventKind.probe,
          correct: correct,
          latencyMs: latency,
        ),
      );
    }
    return engine;
  }

  group('law 6', () {
    test('law 6: a family unlocks at >=80% automatic with the remainder at '
        'least derived', () {
      // x2 owns 11 facts; ceil(0.8 * 11) = 9 automatic required.
      expect(
        probedEngine(fast: 9, slow: 2).familyStatus(Family.x10),
        isNot(FamilyStatus.locked),
      );
      expect(
        probedEngine(fast: 8, slow: 3).familyStatus(Family.x10),
        FamilyStatus.locked,
        reason: '8/11 automatic is below the bar',
      );
      expect(
        probedEngine(fast: 9, wrong: 2).familyStatus(Family.x10),
        FamilyStatus.locked,
        reason: 'remainder still at counting blocks the gate',
      );
    });

    test('law 6: unlock sequence follows the practitioner order', () {
      expect(pack.sequence.map((f) => f.name).toList(), [
        'x2',
        'x10',
        'x5',
        'x1',
        'x0',
        'squares',
        'x4',
        'x3',
        'x9',
        'x6',
        'x7',
        'x8',
      ]);
      // The chain is enforced by the gates: each family's gate names its
      // sequence predecessor (and strategy sources).
      final chainSatisfied = <Family>{};
      for (final family in pack.sequence) {
        expect(
          pack.gateSatisfied(family, chainSatisfied),
          isTrue,
          reason: 'satisfying the sequence so far must open $family',
        );
        chainSatisfied.add(family);
      }
    });

    test('law 6: x6 unlocks from (x3 OR x5), inside its sequence position', () {
      expect(pack.gateSatisfied(Family.x6, {Family.x9, Family.x3}), isTrue);
      expect(
        pack.gateSatisfied(Family.x6, {Family.x9, Family.x5}),
        isTrue,
        reason: 'x5 alone substitutes for x3: the contract OR',
      );
      expect(pack.gateSatisfied(Family.x6, {Family.x9}), isFalse);
      expect(
        pack.gateSatisfied(Family.x6, {Family.x3, Family.x5}),
        isFalse,
        reason: 'sequence pacing: the x9 step still gates',
      );
    });

    test('law 6: squares unlock after x5, with the nearSquare route, on a '
        'mastered diagonal anchor', () {
      final engine = MasteryEngine.fresh(now: day0);
      probeFamilyKnown(engine, Family.x2);
      probeFamilyKnown(engine, Family.x10);
      expect(engine.familyStatus(Family.squares), FamilyStatus.locked);
      probeFamilyKnown(engine, Family.x5);
      expect(engine.familyStatus(Family.squares), FamilyStatus.vignetteDue);
      probeFamilyKnown(engine, Family.x1);
      probeFamilyKnown(engine, Family.x0);
      final vignette = engine.nextVignette()!;
      expect(vignette.family, Family.squares);
      expect(vignette.route, StrategyRoute.nearSquare);
      expect(vignette.anchor.isSquare, isTrue);
    });

    test('law 6: reviews continue for satisfied families (never blocked)', () {
      final engine = MasteryEngine.fresh(now: day0);
      probeFamilyKnown(engine, Family.x2);
      // Days later, x2 facts come due; they must still be offered even
      // though the family is long satisfied.
      final round = engine.assembleRound(RoundIntent.piecing, now: onDay(3));
      expect(
        round.events.any(
          (e) =>
              pack.ownerOf(e.fact) == Family.x2 && e.kind == EventKind.review,
        ),
        isTrue,
      );
    });
  });
}
