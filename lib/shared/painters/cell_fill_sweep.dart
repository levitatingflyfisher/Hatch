import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../scene/seeded.dart';
import '../theme/app_colors.dart';
import 'egg_art.dart';

/// Sweep speed tiers matched to the pre-rendered sweep_{slow,med,fast}.ogg
/// clips; duration compresses with the child's speed so juice never
/// throttles expert tempo (juice law).
enum SweepTier {
  slow(Duration(milliseconds: 1200)),
  medium(Duration(milliseconds: 800)),
  fast(Duration(milliseconds: 480));

  const SweepTier(this.duration);

  final Duration duration;
}

/// Row-by-row crack-fill timing for a correct answer: rows crack in order,
/// each with a brief star pop at its end.
class CellFillSweep {
  const CellFillSweep({required this.rows, required this.duration});

  CellFillSweep.forTier(SweepTier tier, {required this.rows})
    : duration = tier.duration;

  final int rows;
  final Duration duration;

  /// Overall progress 0..1 at [elapsed].
  double progressAt(Duration elapsed) {
    if (duration.inMicroseconds == 0) return 1;
    return (elapsed.inMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0);
  }

  /// Per-row progress 0..1: row i owns the window [i/rows, (i+1)/rows].
  double rowProgress(double progress, int row) {
    if (rows <= 0) return 1;
    final window = 1 / rows;
    return ((progress - row * window) / window).clamp(0.0, 1.0);
  }

  /// The star-pop window at the end of each row's crack.
  static const popStart = 0.75;

  /// 0..1 pop progress for a row (0 before the pop, 1 when spent).
  double rowPop(double progress, int row) {
    final rp = rowProgress(progress, row);
    if (rp <= popStart) return 0;
    return ((rp - popStart) / (1 - popStart)).clamp(0.0, 1.0);
  }
}

/// Paints the tray mid-sweep: pending eggs intact, the active row cracking
/// with shell fragments and a star pop, done rows opened with hatchling
/// heads peeking.
class CellFillSweepPainter extends CustomPainter {
  const CellFillSweepPainter({
    required this.a,
    required this.b,
    required this.progress,
    required this.hue,
    required this.seed,
  });

  final int a;
  final int b;
  final double progress;
  final Color hue;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final sweep = CellFillSweep(rows: a, duration: SweepTier.slow.duration);
    final margin = size.shortestSide * 0.03;
    final area =
        Offset(margin, margin) &
        Size(size.width - margin * 2, size.height - margin * 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(area, Radius.circular(area.shortestSide * 0.08)),
      Paint()..color = Color.lerp(hue, Colors.white, 0.30)!,
    );
    final cols = math.max(b, 1);
    final rows = math.max(a, 1);
    final cellW = area.width / cols;
    final cellH = area.height / rows;
    final wellPaint = Paint()..color = Color.lerp(hue, AppColors.ink, 0.32)!;
    final wellR = Radius.circular(math.min(cellW, cellH) * 0.28);
    for (var r = 0; r < a; r++) {
      final rowP = sweep.rowProgress(progress, r);
      final pop = sweep.rowPop(progress, r);
      for (var c = 0; c < b; c++) {
        final i = r * b + c;
        final cell = Rect.fromLTWH(
          area.left + c * cellW,
          area.top + r * cellH,
          cellW,
          cellH,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(cell.deflate(cellW * 0.09), wellR),
          wellPaint,
        );
        final eggRect = Rect.fromCenter(
          center: cell.center + seededOffset(seed, i, cellW * 0.03),
          width: cellW * 0.62,
          height: cellH * 0.74,
        );
        final eggSeed = seededInt(seed, i);
        if (rowP >= 1) {
          EggArt.paintHatchedPeek(canvas, eggRect, seed: eggSeed, hue: hue);
        } else if (rowP > 0) {
          EggArt.paintEgg(canvas, eggRect, seed: eggSeed, crack: rowP / 0.9);
          if (pop > 0) _fragments(canvas, eggRect, eggSeed, pop);
        } else {
          EggArt.paintEgg(canvas, eggRect, seed: eggSeed);
        }
      }
      if (pop > 0 && pop < 1) {
        _star(
          canvas,
          Offset(area.center.dx, area.top + cellH * (r + 0.5)),
          math.min(cellH, cellW) * 0.5 * Curves.easeOutBack.transform(pop),
          1 - pop,
        );
      }
    }
  }

  void _fragments(Canvas canvas, Rect egg, int eggSeed, double pop) {
    final paint = Paint()
      ..color = AppColors.shell.withValues(alpha: (1 - pop).clamp(0.0, 1.0));
    for (var f = 0; f < 3; f++) {
      final dir = seededOffset(eggSeed, 30 + f, 1).direction;
      final dist = egg.width * (0.3 + pop * 0.7);
      final c = egg.center + Offset(math.cos(dir), math.sin(dir) - 0.6) * dist;
      final s = egg.width * 0.14 * (1 - pop * 0.5);
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - s)
          ..lineTo(c.dx + s, c.dy + s)
          ..lineTo(c.dx - s, c.dy + s)
          ..close(),
        paint,
      );
    }
  }

  void _star(Canvas canvas, Offset center, double r, double alpha) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final radius = i.isEven ? r : r * 0.42;
      final angle = -math.pi / 2 + i * math.pi / 4;
      final p = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()..color = AppColors.yolk.withValues(alpha: alpha.clamp(0.0, 1.0)),
    );
  }

  @override
  bool shouldRepaint(CellFillSweepPainter oldDelegate) =>
      oldDelegate.a != a ||
      oldDelegate.b != b ||
      oldDelegate.progress != progress ||
      oldDelegate.hue != hue ||
      oldDelegate.seed != seed;
}
