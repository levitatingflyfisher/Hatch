import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'dotted_trail_painter.dart';

/// Seam variants on the incubator frame (the teaching decompositions).
sealed class FrameSeam {
  const FrameSeam();
}

/// Split after [afterRow] rows; each half is labeled with its partial
/// product (the five-anchor / snap story: 7×8 → 40 | 16).
class SplitSeam extends FrameSeam {
  const SplitSeam(this.afterRow);

  final int afterRow;
}

/// One crossed-out extra row beyond the frame (the ×9 trim story:
/// fill the 10-row tray, trim one row off).
class TrimRowSeam extends FrameSeam {
  const TrimRowSeam();
}

/// One ghost row sliding under the frame (the add-a-group story:
/// ×3 is ×2 and one more row).
class GhostRowSeam extends FrameSeam {
  const GhostRowSeam();
}

/// The incubator slot a tray must fill: a dotted target frame with dimension
/// chips ("a" rows on the left, "b" per row on top), ghosted wells inside,
/// and an optional teaching [seam]. Pure painter.
class IncubatorFramePainter extends CustomPainter {
  const IncubatorFramePainter({
    required this.a,
    required this.b,
    this.seam,
    this.accent = AppColors.yolk,
  });

  final int a;
  final int b;
  final FrameSeam? seam;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final margin = size.shortestSide * 0.05;
    // Trim/ghost variants borrow one extra row of height.
    final extraRow = seam is TrimRowSeam || seam is GhostRowSeam ? 1 : 0;
    final rows = math.max(a, 1);
    final cols = math.max(b, 1);
    final cellH = (size.height - margin * 2) / (rows + extraRow);
    final cellW = (size.width - margin * 2) / cols;
    final frame = Rect.fromLTWH(
      margin,
      margin,
      size.width - margin * 2,
      cellH * rows,
    );

    _ghostWells(canvas, frame, rows, cols);
    final border = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          frame,
          Radius.circular(frame.shortestSide * 0.06),
        ),
      );
    DottedTrailPainter.paintDots(
      canvas,
      border,
      color: accent,
      dotRadius: math.max(frame.shortestSide * 0.018, 1.4),
      spacing: math.max(frame.shortestSide * 0.055, 5),
    );
    _dimensionChips(canvas, frame);

    switch (seam) {
      case SplitSeam(:final afterRow):
        _split(canvas, frame, afterRow, cellH);
      case TrimRowSeam():
        _trimRow(canvas, frame, cellW, cellH);
      case GhostRowSeam():
        _ghostRow(canvas, frame, cellW, cellH);
      case null:
        break;
    }
  }

  void _ghostWells(Canvas canvas, Rect frame, int rows, int cols) {
    final cellW = frame.width / cols;
    final cellH = frame.height / rows;
    final r = math.min(cellW, cellH) * 0.26;
    final paint = Paint()
      ..color = AppColors.speckle.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(r * 0.18, 0.7);
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        canvas.drawCircle(
          Offset(
            frame.left + cellW * (col + 0.5),
            frame.top + cellH * (row + 0.5),
          ),
          r,
          paint,
        );
      }
    }
  }

  void _dimensionChips(Canvas canvas, Rect frame) {
    final h = math.max(frame.shortestSide * 0.16, 12.0).clamp(0.0, 22.0);
    _chip(canvas, Offset(frame.left, frame.center.dy), '$a', h);
    _chip(canvas, Offset(frame.center.dx, frame.top), '$b', h);
  }

  void _split(Canvas canvas, Rect frame, int afterRow, double cellH) {
    final y = frame.top + cellH * afterRow;
    canvas.drawLine(
      Offset(frame.left + frame.width * 0.03, y),
      Offset(frame.right - frame.width * 0.03, y),
      Paint()
        ..color = accent
        ..strokeWidth = math.max(frame.shortestSide * 0.03, 2)
        ..strokeCap = StrokeCap.round,
    );
    final h = math.max(frame.shortestSide * 0.18, 13.0).clamp(0.0, 26.0);
    _chip(
      canvas,
      Offset(frame.center.dx, frame.top + cellH * afterRow / 2),
      '${afterRow * b}',
      h,
    );
    _chip(
      canvas,
      Offset(frame.center.dx, y + (frame.bottom - y) / 2),
      '${(a - afterRow) * b}',
      h,
    );
  }

  void _trimRow(Canvas canvas, Rect frame, double cellW, double cellH) {
    final row = Rect.fromLTWH(frame.left, frame.bottom, frame.width, cellH);
    _rowOutline(canvas, row, cellW, cellH, AppColors.coral);
    // The cross-out: this row is the one you trim away.
    final cross = Paint()
      ..color = AppColors.coral
      ..strokeWidth = math.max(cellH * 0.12, 2.2)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      row.centerLeft + Offset(cellW * 0.1, 0),
      row.centerRight - Offset(cellW * 0.1, 0),
      cross,
    );
  }

  void _ghostRow(Canvas canvas, Rect frame, double cellW, double cellH) {
    final row = Rect.fromLTWH(frame.left, frame.bottom, frame.width, cellH);
    _rowOutline(canvas, row, cellW, cellH, accent);
  }

  void _rowOutline(
    Canvas canvas,
    Rect row,
    double cellW,
    double cellH,
    Color color,
  ) {
    final r = math.min(cellW, cellH) * 0.26;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(r * 0.22, 0.8);
    for (var col = 0; col < b; col++) {
      canvas.drawCircle(
        Offset(row.left + cellW * (col + 0.5), row.center.dy),
        r,
        paint,
      );
    }
  }

  void _chip(Canvas canvas, Offset center, String text, double height) {
    final w = height * (0.6 + 0.5 * text.length);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: w, height: height),
        Radius.circular(height * 0.5),
      ),
      Paint()..color = AppColors.creamCard,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: w, height: height),
        Radius.circular(height * 0.5),
      ),
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(height * 0.06, 0.8),
    );
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w700,
          fontSize: height * 0.62,
          color: AppColors.ink,
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
  bool shouldRepaint(IncubatorFramePainter oldDelegate) =>
      oldDelegate.a != a ||
      oldDelegate.b != b ||
      oldDelegate.seam != seam ||
      oldDelegate.accent != accent;
}
