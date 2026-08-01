import 'package:flutter/rendering.dart';

import '../theme/app_colors.dart';

/// Dots along any path — trails, borders, the ghost cursor's wake. The
/// dotted trail is the retheme of the running stitch; [progress] draws only
/// the leading fraction so trails can grow.
class DottedTrailPainter extends CustomPainter {
  const DottedTrailPainter({
    required this.path,
    this.color = AppColors.yolk,
    this.dotRadius = 2.4,
    this.spacing = 9,
    this.progress = 1.0,
  });

  final Path path;
  final Color color;
  final double dotRadius;
  final double spacing;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    paintDots(
      canvas,
      path,
      color: color,
      dotRadius: dotRadius,
      spacing: spacing,
      progress: progress,
    );
  }

  /// Static entry so other painters (frame, ghost cursor) share the idiom.
  static void paintDots(
    Canvas canvas,
    Path path, {
    Color color = AppColors.yolk,
    double dotRadius = 2.4,
    double spacing = 9,
    double progress = 1.0,
  }) {
    final paint = Paint()..color = color;
    for (final metric in path.computeMetrics()) {
      final end = metric.length * progress.clamp(0.0, 1.0);
      for (var d = 0.0; d <= end; d += spacing) {
        final tangent = metric.getTangentForOffset(d);
        if (tangent != null) {
          canvas.drawCircle(tangent.position, dotRadius, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(DottedTrailPainter oldDelegate) =>
      oldDelegate.path != path ||
      oldDelegate.color != color ||
      oldDelegate.dotRadius != dotRadius ||
      oldDelegate.spacing != spacing ||
      oldDelegate.progress != progress;
}
