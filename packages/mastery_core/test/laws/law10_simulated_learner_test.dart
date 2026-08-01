import 'package:mastery_core/mastery_core.dart';
import 'package:test/test.dart';

import '../support/simulated_learner.dart';

void main() {
  const pack = MultiplicationPack();

  group('law 10', () {
    test('law 10: median simulated learner reaches full-table automaticity in '
        'under 25 hours of play at default parameters', () {
      final results = [
        for (final seed in const [11, 23, 37, 59, 101])
          LearnerDriver(seed: seed).runToMastery(),
      ];
      for (final r in results) {
        expect(
          r.mastered,
          isTrue,
          reason: 'every seeded learner must finish the table',
        );
      }
      final hours = results.map((r) => r.playHours).toList()..sort();
      final medianHours = hours[hours.length ~/ 2];
      expect(
        medianHours,
        lessThan(25),
        reason:
            'shipping gate: median play-time to full-table '
            'automaticity (got ${medianHours.toStringAsFixed(1)}h)',
      );
    }, timeout: const Timeout(Duration(minutes: 4)));

    test('law 10: a learner who already knows x0/x1/x2/x5/x10 reaches frontier '
        'family x4-or-beyond within her first session', () {
      final driver = LearnerDriver(
        seed: 7,
        params: const LearnerParams(knownFactors: {0, 1, 2, 5, 10}),
      );
      driver.session();
      final frontier = driver.engine
          .stats(now: DateTime(2026, 3, 2, 9))
          .frontier;
      expect(frontier, isNotNull);
      expect(
        pack.sequenceIndex(frontier!),
        greaterThanOrEqualTo(pack.sequenceIndex(Family.x4)),
        reason:
            'placement must carry her past the families she knows '
            '(frontier came back $frontier)',
      );
      expect(
        driver.playMs,
        lessThanOrEqualTo(12 * 60 * 1000),
        reason: 'one session, not a marathon',
      );
    });
  });
}
