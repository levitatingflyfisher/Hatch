import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/features/nursery/domain/miss_copy.dart';
import 'package:hatch/shared/painters/shortfall_overflow.dart';

void main() {
  group('the miss choreography says what it is showing', () {
    test('a shortfall names the room the ghost eggs slide in to fill', () {
      expect(missLabel(ShortfallOverflowKind.shortfall), 'Room for more!');
    });

    test('an overflow names the eggs tumbling off the tray edge', () {
      expect(missLabel(ShortfallOverflowKind.overflow), 'Too many to fit!');
    });

    test('an exact count is not a miss, so nothing is said', () {
      expect(missLabel(ShortfallOverflowKind.exact), isNull);
    });
  });
}
