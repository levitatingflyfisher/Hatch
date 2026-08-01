import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/shared/painters/cell_fill_sweep.dart';

void main() {
  group('SweepTier', () {
    test('tier durations match the sweep audio clips', () {
      expect(SweepTier.slow.duration, const Duration(milliseconds: 1200));
      expect(SweepTier.medium.duration, const Duration(milliseconds: 800));
      expect(SweepTier.fast.duration, const Duration(milliseconds: 480));
    });
  });

  group('CellFillSweep', () {
    test('progressAt maps elapsed over duration, clamped', () {
      final sweep = CellFillSweep.forTier(SweepTier.medium, rows: 4);
      expect(sweep.progressAt(Duration.zero), 0);
      expect(sweep.progressAt(const Duration(milliseconds: 400)), 0.5);
      expect(sweep.progressAt(const Duration(milliseconds: 800)), 1);
      expect(sweep.progressAt(const Duration(seconds: 9)), 1);
    });

    test('rows crack strictly in order', () {
      final sweep = CellFillSweep.forTier(SweepTier.slow, rows: 3);
      // Mid-row-0: row 0 in progress, rows 1-2 untouched.
      expect(sweep.rowProgress(0.15, 0), closeTo(0.45, 1e-9));
      expect(sweep.rowProgress(0.15, 1), 0);
      expect(sweep.rowProgress(0.15, 2), 0);
      // Mid-row-1: row 0 done.
      expect(sweep.rowProgress(0.5, 0), 1);
      expect(sweep.rowProgress(0.5, 1), closeTo(0.5, 1e-9));
      expect(sweep.rowProgress(0.5, 2), 0);
      // Complete.
      expect(sweep.rowProgress(1, 2), 1);
    });

    test('rowPop fires only at the end of a row window', () {
      final sweep = CellFillSweep.forTier(SweepTier.fast, rows: 2);
      expect(sweep.rowPop(0.2, 0), 0); // rowP 0.4, before popStart
      expect(sweep.rowPop(0.45, 0), greaterThan(0)); // rowP 0.9
      expect(sweep.rowPop(0.5, 0), 1);
      expect(sweep.rowPop(0.5, 1), 0);
    });

    test('degenerate rows never divide by zero', () {
      const sweep = CellFillSweep(rows: 0, duration: Duration.zero);
      expect(sweep.progressAt(Duration.zero), 1);
      expect(sweep.rowProgress(0.4, 0), 1);
    });
  });
}
