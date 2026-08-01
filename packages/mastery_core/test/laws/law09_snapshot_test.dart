import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:mastery_core/mastery_core.dart';
import 'package:test/test.dart';

import '../support/harness.dart';

/// Tiny deterministic LCG so the property test is seeded end-to-end
/// (no unseeded randomness anywhere in this package or its tests).
class _Lcg {
  _Lcg(this._state);

  int _state;

  int next(int bound) {
    _state =
        (_state * 6364136223846793005 + 1442695040888963407) &
        0x7fffffffffffffff;
    return (_state >> 17) % bound;
  }

  bool chance(int percent) => next(100) < percent;
}

const _seeds = [7, 42, 1999];

void main() {
  const pack = MultiplicationPack();
  const deep = DeepCollectionEquality();

  AnswerEvent randomEvent(_Lcg rng, DateTime at, int index) {
    final fact = pack.allFacts[rng.next(66)];
    final kind = index < 80 && rng.chance(30)
        ? EventKind.probe
        : EventKind.values[1 + rng.next(EventKind.values.length - 1)];
    final untimed = kind == EventKind.construct && rng.chance(50);
    return AnswerEvent(
      fact: fact,
      direction: rng.chance(15) ? AskDirection.reversed : AskDirection.forward,
      kind: kind,
      rung: Rung.values[rng.next(4)],
      correct: rng.chance(80),
      latencyMs: untimed ? null : 700 + rng.next(3000),
      production: rng.chance(75),
      at: at,
    );
  }

  String statsOf(MasteryEngine engine, DateTime now) {
    final s = engine.stats(now: now);
    return '${s.phaseCounts}|${s.rungCounts}|${s.dueCount}|${s.startedCount}|'
        '${s.automaticCount}|${s.frontier}|${s.placementActive}';
  }

  group('law 9', () {
    for (final seed in _seeds) {
      test('law 9: snapshot round-trip preserves behavior across a random '
          'history (seed $seed)', () {
        final rng = _Lcg(seed);
        final original = MasteryEngine.fresh(now: day0);
        MasteryEngine? restored;
        var at = day0;

        for (var i = 0; i < 400; i++) {
          at = at.add(Duration(minutes: 1 + rng.next(200)));
          final event = randomEvent(rng, at, i);
          original.record(event);
          restored?.record(event);

          if (i % 25 == 24) {
            final due = original.nextVignette();
            if (due != null) {
              original.markVignetteComplete(due.family, now: at);
              restored?.markVignetteComplete(due.family, now: at);
            }
          }

          if (i % 50 == 49) {
            final snap = original.snapshot();
            // The restored twin from the previous window must have converged
            // to the identical state before we fork a fresh one.
            if (restored != null) {
              expect(
                deep.equals(restored.snapshot(), snap),
                isTrue,
                reason: 'restored engine diverged by event $i',
              );
            }
            // Snapshots survive real JSON encoding (the app persists them).
            final wire = jsonDecode(jsonEncode(snap)) as Map<String, Object?>;
            restored = MasteryEngine.fromSnapshot(wire);
            expect(
              deep.equals(restored.snapshot(), snap),
              isTrue,
              reason: 'snapshot -> fromSnapshot -> snapshot must be exact',
            );
            for (final intent in RoundIntent.values) {
              expect(
                describeRound(restored.assembleRound(intent, now: at)),
                describeRound(original.assembleRound(intent, now: at)),
                reason: 'identical rounds after restore (seed $seed)',
              );
            }
            expect(statsOf(restored, at), statsOf(original, at));
          }
        }
      });
    }
  });
}
