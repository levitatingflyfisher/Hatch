import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mastery_core/mastery_core.dart';

import '../scene/seeded.dart';
import '../theme/app_colors.dart';
import 'egg_art.dart';
import 'tray_painter.dart';

/// Classification of a wrong answer against the true frame.
enum ShortfallOverflowKind { exact, shortfall, overflow }

/// THE teaching moment (engine law): the child's wrong product n is rendered
/// as n eggs against the a×b frame. Shortfall leaves empty wells pulsing and
/// slides a ghost row in ("one more group"); overflow rolls the extra eggs
/// off the tray edge ("one group too many"). At bare rung the tag chip first
/// blooms open into its tray.
class ShortfallOverflow {
  const ShortfallOverflow({
    required this.a,
    required this.b,
    required this.answer,
  });

  final int a;
  final int b;

  /// The child's (wrong) product.
  final int answer;

  static const duration = Duration(milliseconds: 1800);

  int get capacity => a * b;

  ShortfallOverflowKind get kind => answer == capacity
      ? ShortfallOverflowKind.exact
      : answer < capacity
      ? ShortfallOverflowKind.shortfall
      : ShortfallOverflowKind.overflow;

  /// Empty wells left behind (shortfall only).
  int get missing => math.max(0, capacity - answer);

  /// Eggs that don't fit (overflow only).
  int get extra => math.max(0, answer - capacity);

  /// Phase windows over progress 0..1. Non-grid rungs spend the first
  /// window blooming the tray open; at grid rung placing starts immediately.
  static const bloomEnd = 0.18;
  static const placeEnd = 0.55;

  double bloom(double progress, Rung rung) {
    if (rung == Rung.grid) return 1;
    return (progress / bloomEnd).clamp(0.0, 1.0);
  }

  double place(double progress, Rung rung) {
    final start = rung == Rung.grid ? 0.0 : bloomEnd;
    return ((progress - start) / (placeEnd - start)).clamp(0.0, 1.0);
  }

  double teach(double progress) =>
      ((progress - placeEnd) / (1 - placeEnd)).clamp(0.0, 1.0);
}

class ShortfallOverflowPainter extends CustomPainter {
  const ShortfallOverflowPainter({
    required this.choreography,
    required this.rung,
    required this.progress,
    required this.hue,
    required this.seed,
  });

  final ShortfallOverflow choreography;
  final Rung rung;
  final double progress;
  final Color hue;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final c = choreography;
    final bloom = c.bloom(progress, rung);
    if (bloom < 1) {
      // The bare/labeled tag blooms open into its tray.
      final scale = 0.6 + 0.4 * Curves.easeOutBack.transform(bloom);
      canvas.save();
      canvas.translate(size.width / 2, size.height / 2);
      canvas.scale(scale);
      canvas.translate(-size.width / 2, -size.height / 2);
      if (bloom < 0.5) {
        TrayPainter(
          a: c.a,
          b: c.b,
          rung: rung,
          hue: hue,
          seed: seed,
        ).paint(canvas, size);
      } else {
        _paintBoard(canvas, size, place: 0, teach: 0);
      }
      canvas.restore();
      return;
    }
    _paintBoard(
      canvas,
      size,
      place: c.place(progress, rung),
      teach: c.teach(progress),
    );
  }

  void _paintBoard(
    Canvas canvas,
    Size size, {
    required double place,
    required double teach,
  }) {
    final c = choreography;
    final margin = size.shortestSide * 0.03;
    final area =
        Offset(margin, margin) &
        Size(size.width - margin * 2, size.height - margin * 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(area, Radius.circular(area.shortestSide * 0.08)),
      Paint()..color = Color.lerp(hue, Colors.white, 0.30)!,
    );
    final cols = math.max(c.b, 1);
    final rows = math.max(c.a, 1);
    final cellW = area.width / cols;
    final cellH = area.height / rows;
    final wellPaint = Paint()..color = Color.lerp(hue, AppColors.ink, 0.32)!;
    final wellR = Radius.circular(math.min(cellW, cellH) * 0.28);

    Rect cellRect(int i) => Rect.fromLTWH(
      area.left + (i % cols) * cellW,
      area.top + (i ~/ cols) * cellH,
      cellW,
      cellH,
    );
    Rect eggRect(Rect cell, int i) => Rect.fromCenter(
      center: cell.center + seededOffset(seed, i, cellW * 0.03),
      width: cellW * 0.62,
      height: cellH * 0.74,
    );

    // Wells.
    for (var i = 0; i < c.capacity; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(cellRect(i).deflate(cellW * 0.09), wellR),
        wellPaint,
      );
    }

    // The child's n eggs place row-major with a stagger.
    final placed = math.min(c.answer, c.capacity);
    final shown = (place * placed).ceil().clamp(0, placed);
    for (var i = 0; i < shown; i++) {
      EggArt.paintEgg(
        canvas,
        eggRect(cellRect(i), i),
        seed: seededInt(seed, i),
      );
    }

    if (teach <= 0) return;
    switch (c.kind) {
      case ShortfallOverflowKind.exact:
        break;
      case ShortfallOverflowKind.shortfall:
        // Empty wells pulse (two beats), then the ghost row slides in.
        final pulse = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(teach * math.pi * 4));
        final pulsePaint = Paint()
          ..color = AppColors.yolk.withValues(alpha: pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(cellW * 0.05, 1.6);
        for (var i = placed; i < c.capacity; i++) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(cellRect(i).deflate(cellW * 0.09), wellR),
            pulsePaint,
          );
        }
        // The missing group slides in from the right edge, one ghost egg
        // per empty well ("one more group" made visible, never overlapping
        // the eggs she did place).
        final slide = Curves.easeOut.transform(teach);
        final xShift = (1 - slide) * area.width * 0.9;
        final ghostFill = Paint()
          ..color = AppColors.shell.withValues(alpha: 0.75 * slide);
        final ghostEdge = Paint()
          ..color = AppColors.yolk.withValues(alpha: slide)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(cellW * 0.045, 1.4);
        for (var i = placed; i < c.capacity; i++) {
          final egg = EggArt.eggPath(
            eggRect(cellRect(i), i).translate(xShift, 0),
          );
          canvas.drawPath(egg, ghostFill);
          canvas.drawPath(egg, ghostEdge);
        }
      case ShortfallOverflowKind.overflow:
        // Extra eggs start perched on the tray's right rim, then tumble off
        // the edge — "one group too many", each egg kept big and readable.
        final roll = Curves.easeIn.transform(teach);
        for (var j = 0; j < c.extra; j++) {
          final perch = Offset(
            area.right - cellW * 0.15,
            area.top + cellH * ((j % rows) + 0.35),
          );
          final travel = cellW * (0.55 + (j % 3) * 0.3);
          final centerNow =
              perch + Offset(travel * roll, roll * roll * area.height * 0.42);
          canvas.save();
          canvas.translate(centerNow.dx, centerNow.dy);
          canvas.rotate(roll * (1.8 + seededUnit(seed, 200 + j)));
          final r = Rect.fromCenter(
            center: Offset.zero,
            width: cellW * 0.62,
            height: cellH * 0.74,
          );
          final alpha = (1 - roll * 0.3).clamp(0.0, 1.0);
          canvas.saveLayer(
            r.inflate(cellW),
            Paint()..color = Color.fromRGBO(0, 0, 0, alpha),
          );
          EggArt.paintEgg(canvas, r, seed: seededInt(seed, 100 + j));
          canvas.restore();
          canvas.restore();
        }
    }
  }

  @override
  bool shouldRepaint(ShortfallOverflowPainter oldDelegate) =>
      oldDelegate.choreography != choreography ||
      oldDelegate.rung != rung ||
      oldDelegate.progress != progress ||
      oldDelegate.hue != hue ||
      oldDelegate.seed != seed;
}
