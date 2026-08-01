import 'package:mastery_core/src/distractor_model.dart';
import 'package:mastery_core/src/fact.dart';
import 'package:test/test.dart';

void main() {
  const model = DistractorModel();

  group('DistractorModel', () {
    test(
      '7x8 distractors come from neighbor products and classic confusions',
      () {
        // (a+-1)xb: 48, 64; ax(b+-1): 49, 63; classics near 56: 54, 63, 48.
        const plausible = {48, 49, 54, 63, 64};
        for (var seed = 0; seed < 20; seed++) {
          final picks = model.distractorsFor(const Fact(7, 8), seed: seed);
          expect(picks.length, 2);
          expect(picks.toSet().length, 2);
          expect(picks, isNot(contains(56)));
          for (final p in picks) {
            expect(plausible, contains(p), reason: 'seed $seed picked $p');
          }
        }
      },
    );

    test('6x9 distractors include the classic 54/56/63 interference zone', () {
      const plausible = {45, 48, 56, 60, 63};
      for (var seed = 0; seed < 20; seed++) {
        final picks = model.distractorsFor(const Fact(6, 9), seed: seed);
        expect(picks, isNot(contains(54)));
        for (final p in picks) {
          expect(plausible, contains(p));
        }
      }
    });

    test('small facts stay in neighbor products', () {
      const plausible = {3, 4, 8, 9};
      for (var seed = 0; seed < 20; seed++) {
        for (final p in model.distractorsFor(const Fact(2, 3), seed: seed)) {
          expect(plausible, contains(p));
        }
      }
    });

    test('degenerate facts still yield two distinct wrong answers', () {
      for (final fact in const [
        Fact(0, 0),
        Fact(0, 1),
        Fact(1, 1),
        Fact(0, 10),
      ]) {
        final picks = model.distractorsFor(fact, seed: 5);
        expect(picks.length, 2);
        expect(picks.toSet().length, 2);
        expect(picks, isNot(contains(fact.product)));
        for (final p in picks) {
          expect(p, isNonNegative);
        }
      }
    });

    test('deterministic per seed', () {
      expect(
        model.distractorsFor(const Fact(7, 8), seed: 3),
        model.distractorsFor(const Fact(7, 8), seed: 3),
      );
    });
  });
}
