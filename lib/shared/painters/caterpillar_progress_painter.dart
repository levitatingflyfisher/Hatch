import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../scene/seeded.dart';
import '../theme/app_colors.dart';

/// The Hatch Rush racing line: a segmented caterpillar whose body fills the
/// track as the child progresses, with the ghost's best run as a translucent
/// marker. Always fills, never drains (no clock-that-drains law).
class CaterpillarProgressPainter extends CustomPainter {
  const CaterpillarProgressPainter({
    required this.progress,
    this.ghostProgress,
    required this.hue,
    this.seed = 0,
  });

  /// 0..1 fraction of the round the child has finished.
  final double progress;

  /// 0..1 the ghost's position; null = no ghost yet (first run).
  final double? ghostProgress;

  final Color hue;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final segR = math.min(size.height * 0.30, 11.0);
    final headR = segR * 1.35;
    final trackPad = headR;
    final track = size.width - trackPad * 2;

    // The remaining track: small speckle dots.
    final trackPaint = Paint()
      ..color = AppColors.speckle.withValues(alpha: 0.8);
    for (var x = trackPad; x <= size.width - trackPad; x += segR * 2.2) {
      canvas.drawCircle(Offset(x, y), segR * 0.18, trackPaint);
    }

    final ghost = ghostProgress;
    if (ghost != null) {
      final gx = trackPad + track * ghost.clamp(0.0, 1.0);
      final ghostPaint = Paint()..color = AppColors.ink.withValues(alpha: 0.30);
      canvas.drawCircle(Offset(gx, y), segR * 0.9, ghostPaint);
      canvas.drawCircle(
        Offset(gx - segR * 0.28, y - segR * 0.2),
        segR * 0.16,
        Paint()..color = AppColors.creamCard,
      );
      canvas.drawCircle(
        Offset(gx + segR * 0.28, y - segR * 0.2),
        segR * 0.16,
        Paint()..color = AppColors.creamCard,
      );
    }

    final p = progress.clamp(0.0, 1.0);
    final headX = trackPad + track * p;
    final spacing = segR * 1.5;
    final bodyPaint = Paint()..color = hue;
    final bodyAlt = Paint()..color = Color.lerp(hue, Colors.white, 0.28)!;
    // Body segments fill back from the head to the start.
    final segCount = math.max(((headX - trackPad) / spacing).floor(), 0);
    for (var i = segCount; i >= 1; i--) {
      final x = headX - i * spacing;
      final bob =
          math.sin(i * 1.3 + seededRange(seed, 5, 0, math.pi)) * segR * 0.22;
      canvas.drawCircle(
        Offset(x, y + bob),
        segR,
        i.isEven ? bodyPaint : bodyAlt,
      );
    }
    // Head: bigger, with face and antennae.
    final head = Offset(headX, y - segR * 0.12);
    final antenna = Paint()
      ..color = AppColors.ink
      ..strokeWidth = math.max(segR * 0.14, 1)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      head + Offset(-headR * 0.3, -headR * 0.7),
      head + Offset(-headR * 0.55, -headR * 1.25),
      antenna,
    );
    canvas.drawLine(
      head + Offset(headR * 0.3, -headR * 0.7),
      head + Offset(headR * 0.55, -headR * 1.25),
      antenna,
    );
    final dotPaint = Paint()..color = AppColors.ink;
    canvas.drawCircle(
      head + Offset(-headR * 0.55, -headR * 1.32),
      segR * 0.2,
      dotPaint,
    );
    canvas.drawCircle(
      head + Offset(headR * 0.55, -headR * 1.32),
      segR * 0.2,
      dotPaint,
    );
    canvas.drawCircle(head, headR, bodyPaint);
    final eyeR = math.max(headR * 0.17, 1.2);
    canvas.drawCircle(
      head + Offset(headR * 0.30, -headR * 0.12),
      eyeR,
      dotPaint,
    );
    canvas.drawCircle(
      head + Offset(-headR * 0.18, -headR * 0.12),
      eyeR,
      dotPaint,
    );
    final glint = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawCircle(
      head + Offset(headR * 0.24, -headR * 0.18),
      eyeR * 0.4,
      glint,
    );
    canvas.drawCircle(
      head + Offset(-headR * 0.24, -headR * 0.18),
      eyeR * 0.4,
      glint,
    );
  }

  @override
  bool shouldRepaint(CaterpillarProgressPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.ghostProgress != ghostProgress ||
      oldDelegate.hue != hue ||
      oldDelegate.seed != seed;
}
