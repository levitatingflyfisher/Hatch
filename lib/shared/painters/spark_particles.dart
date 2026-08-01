import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../scene/seeded.dart';
import '../theme/app_colors.dart';

/// Combo spark burst: seeded radial particles (dots + 4-point stars), only
/// ever fired on the child's own success actions (juice law).
class SparkBurstPainter extends CustomPainter {
  const SparkBurstPainter({
    required this.progress,
    required this.seed,
    this.color = AppColors.yolk,
    this.count = 10,
  });

  final double progress;
  final int seed;
  final Color color;
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    paintBurst(
      canvas,
      Offset(size.width / 2, size.height / 2),
      radius: size.shortestSide / 2,
      progress: progress,
      seed: seed,
      color: color,
      count: count,
    );
  }

  static void paintBurst(
    Canvas canvas,
    Offset center, {
    required double radius,
    required double progress,
    required int seed,
    Color color = AppColors.yolk,
    int count = 10,
  }) {
    final p = progress.clamp(0.0, 1.0);
    if (p == 0 || p == 1) return;
    final travel = 1 - (1 - p) * (1 - p);
    final alpha = p < 0.6 ? 1.0 : (1 - p) / 0.4;
    final paint = Paint()..color = color.withValues(alpha: alpha);
    for (var i = 0; i < count; i++) {
      final angle =
          i * math.pi * 2 / count + seededRange(seed, i * 3, -0.25, 0.25);
      final speed = seededRange(seed, i * 3 + 1, 0.55, 1.0);
      final pos =
          center +
          Offset(math.cos(angle), math.sin(angle)) * radius * speed * travel;
      final s =
          radius * seededRange(seed, i * 3 + 2, 0.045, 0.09) * (1 - p * 0.4);
      if (i.isEven) {
        canvas.drawCircle(pos, s, paint);
      } else {
        final star = Path()
          ..moveTo(pos.dx, pos.dy - s * 1.7)
          ..lineTo(pos.dx + s * 0.5, pos.dy - s * 0.5)
          ..lineTo(pos.dx + s * 1.7, pos.dy)
          ..lineTo(pos.dx + s * 0.5, pos.dy + s * 0.5)
          ..lineTo(pos.dx, pos.dy + s * 1.7)
          ..lineTo(pos.dx - s * 0.5, pos.dy + s * 0.5)
          ..lineTo(pos.dx - s * 1.7, pos.dy)
          ..lineTo(pos.dx - s * 0.5, pos.dy - s * 0.5)
          ..close();
        canvas.drawPath(star, paint);
      }
    }
  }

  @override
  bool shouldRepaint(SparkBurstPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.seed != seed ||
      oldDelegate.color != color ||
      oldDelegate.count != count;
}
