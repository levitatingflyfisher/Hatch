import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/shared/painters/shortfall_overflow.dart';
import 'package:mastery_core/mastery_core.dart';

void main() {
  group('ShortfallOverflow', () {
    test('classifies the canonical 4×7 teaching cases', () {
      // 24 in a 4×7 tray: one more 4 needed.
      const short = ShortfallOverflow(a: 4, b: 7, answer: 24);
      expect(short.kind, ShortfallOverflowKind.shortfall);
      expect(short.missing, 4);
      expect(short.extra, 0);
      // 32: one 4 too many.
      const over = ShortfallOverflow(a: 4, b: 7, answer: 32);
      expect(over.kind, ShortfallOverflowKind.overflow);
      expect(over.extra, 4);
      expect(over.missing, 0);
      const exact = ShortfallOverflow(a: 4, b: 7, answer: 28);
      expect(exact.kind, ShortfallOverflowKind.exact);
    });

    test('bloom phase runs only for non-grid rungs', () {
      const c = ShortfallOverflow(a: 3, b: 5, answer: 12);
      expect(c.bloom(0.05, Rung.grid), 1);
      expect(c.bloom(0.09, Rung.bare), closeTo(0.5, 1e-9));
      expect(c.bloom(ShortfallOverflow.bloomEnd, Rung.bare), 1);
      expect(c.bloom(0.9, Rung.labeled), 1);
    });

    test(
      'place phase starts immediately at grid rung, after bloom otherwise',
      () {
        const c = ShortfallOverflow(a: 3, b: 5, answer: 12);
        expect(c.place(0, Rung.grid), 0);
        expect(c.place(ShortfallOverflow.placeEnd, Rung.grid), 1);
        expect(c.place(ShortfallOverflow.bloomEnd, Rung.bare), 0);
        expect(c.place(ShortfallOverflow.placeEnd, Rung.bare), 1);
        expect(c.place(1, Rung.bare), 1);
      },
    );

    test('teach phase owns the tail of the timeline', () {
      const c = ShortfallOverflow(a: 3, b: 5, answer: 12);
      expect(c.teach(ShortfallOverflow.placeEnd), 0);
      expect(c.teach(1), 1);
      expect(c.teach(0.2), 0);
    });
  });
}
