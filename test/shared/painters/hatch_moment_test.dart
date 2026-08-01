import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/shared/painters/hatch_moment.dart';

void main() {
  group('HatchMoment', () {
    test('signature duration is 1.2s', () {
      expect(HatchMoment.duration, const Duration(milliseconds: 1200));
    });

    test('rock wobbles twice then stills before the crack', () {
      expect(HatchMoment.rockAngle(0), 0);
      expect(HatchMoment.rockAngle(HatchMoment.rockEnd), 0);
      expect(HatchMoment.rockAngle(0.9), 0);
      // Two full sine periods inside the rock window -> two wobbles: the
      // angle changes sign across the window.
      final quarter = HatchMoment.rockAngle(HatchMoment.rockEnd * 0.13);
      final threeQuarter = HatchMoment.rockAngle(HatchMoment.rockEnd * 0.37);
      expect(quarter, greaterThan(0));
      expect(threeQuarter, lessThan(0));
    });

    test('crack grows only inside its window', () {
      expect(HatchMoment.crack(HatchMoment.rockEnd), 0);
      expect(
        HatchMoment.crack((HatchMoment.rockEnd + HatchMoment.crackEnd) / 2),
        closeTo(0.5, 1e-9),
      );
      expect(HatchMoment.crack(HatchMoment.crackEnd), 1);
      expect(HatchMoment.crack(1), 1);
    });

    test('split and pop own the tail', () {
      expect(HatchMoment.split(HatchMoment.crackEnd), 0);
      expect(HatchMoment.split(HatchMoment.splitEnd), 1);
      expect(HatchMoment.pop(HatchMoment.crackEnd), 0);
      expect(HatchMoment.pop(1), 1);
      expect(HatchMoment.pop(0.2), 0);
    });

    test('phases are ordered', () {
      expect(HatchMoment.rockEnd, lessThan(HatchMoment.crackEnd));
      expect(HatchMoment.crackEnd, lessThan(HatchMoment.splitEnd));
      expect(HatchMoment.splitEnd, lessThan(1));
    });
  });
}
