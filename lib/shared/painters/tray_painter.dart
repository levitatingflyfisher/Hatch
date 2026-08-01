import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mastery_core/mastery_core.dart';

import '../scene/seeded.dart';
import '../theme/app_colors.dart';
import 'egg_art.dart';

/// The tray of a×b eggs at each weaning rung (an incubator tray IS an array):
/// - [Rung.grid]: open tray, every egg visible in a wells grid;
/// - [Rung.bundled]: egg-carton rows, one carton per row with its count;
/// - [Rung.labeled]: closed tray lid with the "a×b" tag;
/// - [Rung.bare]: just the tag chip.
///
/// Pure painter; must read at ~30px (album mini-cell) and at hoop size.
/// [settleProgress] 0→1 drops the eggs into their wells (the settle moment —
/// the retheme of "sews shut"); only the grid rung animates.
class TrayPainter extends CustomPainter {
  const TrayPainter({
    required this.a,
    required this.b,
    required this.rung,
    required this.hue,
    required this.seed,
    this.settleProgress = 1.0,
  });

  /// Rows (group count).
  final int a;

  /// Columns (group size).
  final int b;

  final Rung rung;
  final Color hue;
  final int seed;
  final double settleProgress;

  Color get _trayColor => Color.lerp(hue, Colors.white, 0.30)!;
  Color get _wellColor => Color.lerp(hue, AppColors.ink, 0.32)!;

  @override
  void paint(Canvas canvas, Size size) {
    final margin = size.shortestSide * 0.03;
    final area =
        Offset(margin, margin) &
        Size(size.width - margin * 2, size.height - margin * 2);
    switch (rung) {
      case Rung.grid:
        _paintOpenTray(canvas, area);
      case Rung.bundled:
        _paintCartonRows(canvas, area);
      case Rung.labeled:
        _paintClosedTray(canvas, area);
      case Rung.bare:
        _paintTag(canvas, _tagRect(area));
    }
  }

  void _paintOpenTray(Canvas canvas, Rect area) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(area, Radius.circular(area.shortestSide * 0.08)),
      Paint()..color = _trayColor,
    );
    if (a == 0 || b == 0) {
      // Zero eggs is an honest empty tray (the ×0 toy-joke), never a
      // featureless chip.
      _paintEmptyRecess(canvas, area);
      return;
    }
    final cols = math.max(b, 1);
    final rows = math.max(a, 1);
    final cellW = area.width / cols;
    final cellH = area.height / rows;
    final wellPaint = Paint()..color = _wellColor;
    final wellR = Radius.circular(math.min(cellW, cellH) * 0.28);
    // Eggs drop in with an overshoot settle; a 0-egg tray is honest emptiness.
    final settle = Curves.easeOutBack.transform(settleProgress.clamp(0.0, 1.0));
    final drop = (1 - settle) * cellH * 0.45;
    for (var r = 0; r < a; r++) {
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
        final jitter = seededOffset(seed, i, math.min(cellW, cellH) * 0.03);
        final eggRect = Rect.fromCenter(
          center: cell.center + jitter + Offset(0, -drop),
          width: cellW * 0.62,
          height: cellH * 0.74,
        );
        EggArt.paintEgg(canvas, eggRect, seed: seededInt(seed, i));
      }
    }
  }

  void _paintEmptyRecess(Canvas canvas, Rect area) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        area.deflate(area.shortestSide * 0.14),
        Radius.circular(area.shortestSide * 0.10),
      ),
      Paint()..color = _wellColor.withValues(alpha: 0.45),
    );
  }

  void _paintCartonRows(Canvas canvas, Rect area) {
    if (a == 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          area,
          Radius.circular(area.shortestSide * 0.08),
        ),
        Paint()..color = _trayColor,
      );
      _paintEmptyRecess(canvas, area);
      return;
    }
    final rows = math.max(a, 1);
    final rowH = area.height / rows;
    final cartonH = rowH * 0.82;
    for (var r = 0; r < a; r++) {
      final carton = Rect.fromLTWH(
        area.left,
        area.top + r * rowH + (rowH - cartonH) / 2,
        area.width,
        cartonH,
      );
      // Shell egg tops peek over the carton rim (they must contrast the
      // cream ground, so the carton body carries the full hue).
      final peekR = (area.width / math.max(b, 1) * 0.32).clamp(
        0.0,
        cartonH * 0.42,
      );
      final peek = Paint()..color = AppColors.shell;
      final peekEdge = Paint()
        ..color = AppColors.speckle
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(peekR * 0.14, 0.6);
      for (var c = 0; c < b; c++) {
        final center = Offset(
          carton.left + area.width * (c + 0.5) / b,
          carton.top + cartonH * 0.30,
        );
        canvas.drawCircle(center, peekR, peek);
        canvas.drawCircle(center, peekR, peekEdge);
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            carton.left,
            carton.top + cartonH * 0.34,
            carton.width,
            cartonH * 0.66,
          ),
          Radius.circular(cartonH * 0.20),
        ),
        Paint()..color = hue,
      );
      _chip(
        canvas,
        center: Offset(carton.center.dx, carton.top + cartonH * 0.67),
        text: '$b',
        height: cartonH * 0.5,
      );
    }
  }

  void _paintClosedTray(Canvas canvas, Rect area) {
    final radius = Radius.circular(area.shortestSide * 0.10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(area, radius),
      Paint()..color = _trayColor,
    );
    // Lid rim.
    canvas.drawRRect(
      RRect.fromRectAndRadius(area.deflate(area.shortestSide * 0.055), radius),
      Paint()
        ..color = _wellColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(area.shortestSide * 0.02, 0.7),
    );
    _paintTag(canvas, _tagRect(area));
  }

  Rect _tagRect(Rect area) {
    final w = math.min(area.width * 0.72, area.height * 1.6);
    final h = math.min(area.height * 0.42, w * 0.55);
    return Rect.fromCenter(center: area.center, width: w, height: h);
  }

  void _paintTag(Canvas canvas, Rect tag) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(tag, Radius.circular(tag.height * 0.3)),
      Paint()..color = AppColors.creamCard,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(tag, Radius.circular(tag.height * 0.3)),
      Paint()
        ..color = hue
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(tag.height * 0.06, 0.8),
    );
    // Tie hole.
    canvas.drawCircle(
      Offset(tag.left + tag.height * 0.28, tag.top + tag.height * 0.28),
      tag.height * 0.08,
      Paint()..color = hue,
    );
    _text(
      canvas,
      '$a×$b',
      center: tag.center,
      fontSize: tag.height * 0.5,
      color: AppColors.ink,
    );
  }

  void _chip(
    Canvas canvas, {
    required Offset center,
    required String text,
    required double height,
  }) {
    final w = height * (0.7 + 0.42 * text.length);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: w, height: height),
        Radius.circular(height * 0.5),
      ),
      Paint()..color = AppColors.creamCard,
    );
    _text(
      canvas,
      text,
      center: center,
      fontSize: height * 0.68,
      color: AppColors.ink,
    );
  }

  static void _text(
    Canvas canvas,
    String text, {
    required Offset center,
    required double fontSize,
    required Color color,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(TrayPainter oldDelegate) =>
      oldDelegate.a != a ||
      oldDelegate.b != b ||
      oldDelegate.rung != rung ||
      oldDelegate.hue != hue ||
      oldDelegate.seed != seed ||
      oldDelegate.settleProgress != settleProgress;
}
