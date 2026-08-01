import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/shared/scene/seeded.dart';

void main() {
  group('mul32', () {
    test('matches exact low-32 multiplication', () {
      expect(mul32(3, 7), 21);
      expect(
        mul32(0xffffffff, 0xffffffff),
        (0xffffffff * 0xffffffff) & 0xffffffff,
      );
      expect(
        mul32(0x9e3779b9, 0x45d9f3b),
        (0x9e3779b9 * 0x45d9f3b) & 0xffffffff,
      );
      expect(
        mul32(0x12345678, 0x87654321),
        (0x12345678 * 0x87654321) & 0xffffffff,
      );
    });
  });

  group('seeded streams', () {
    test('deterministic for the same seed and index', () {
      expect(seededUnit(seedFor(3, 8), 5), seededUnit(seedFor(3, 8), 5));
      expect(seededOffset(42, 2, 1.5), seededOffset(42, 2, 1.5));
    });

    test('different facts get different seeds', () {
      final seeds = <int>{
        for (var a = 0; a <= 10; a++)
          for (var b = a; b <= 10; b++) seedFor(a, b),
      };
      expect(seeds.length, 66);
    });

    test('unit values stay in [0, 1)', () {
      for (var i = 0; i < 200; i++) {
        final v = seededUnit(seedFor(4, 9), i);
        expect(v, greaterThanOrEqualTo(0));
        expect(v, lessThan(1));
      }
    });

    test('range and offset respect bounds', () {
      for (var i = 0; i < 100; i++) {
        final v = seededRange(7, i, -2, 3);
        expect(v, greaterThanOrEqualTo(-2));
        expect(v, lessThan(3));
        final o = seededOffset(7, i, 2);
        expect(o.dx.abs(), lessThanOrEqualTo(2));
        expect(o.dy.abs(), lessThanOrEqualTo(2));
      }
    });

    test('pick covers the whole range', () {
      final seen = <int>{};
      for (var i = 0; i < 100; i++) {
        seen.add(seededPick(11, i, 4));
      }
      expect(seen, {0, 1, 2, 3});
    });

    test('adjacent indices decorrelate', () {
      final a = seededUnit(1, 1);
      final b = seededUnit(1, 2);
      expect((a - b).abs(), greaterThan(1e-6));
    });
  });
}
