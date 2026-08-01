import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../domain/habitat_layout.dart';

/// Flat scenery for one biome: a handful of big soft shapes in the theme's
/// critter hues. Deliberately calm and empty-feeling — the critters the
/// child places ARE the picture; the background only sets the mood.
/// All geometry is fixed (no randomness), so goldens and repaints are free.
class HabitatBackgroundPainter extends CustomPainter {
  const HabitatBackgroundPainter({required this.biome, this.dark = false});

  final HabitatBiome biome;
  final bool dark;

  /// Washes a hue toward the theme ground so the scenery stays behind the
  /// critters, never competing with them.
  Color _wash(Color hue, double amount) =>
      Color.lerp(hue, dark ? AppColors.plumDark : AppColors.cream, amount)!;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = dark ? AppColors.plumCard : AppColors.creamCard,
    );
    switch (biome) {
      case HabitatBiome.meadow:
        _meadow(canvas, size);
      case HabitatBiome.pond:
        _pond(canvas, size);
      case HabitatBiome.hill:
        _hill(canvas, size);
    }
  }

  void _meadow(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Sun, top-left.
    canvas.drawCircle(
      Offset(w * 0.16, h * 0.14),
      w * 0.09,
      Paint()..color = _wash(AppColors.yolk, 0.25),
    );
    // Two grass bands.
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.42)
        ..quadraticBezierTo(w * 0.5, h * 0.32, w, h * 0.44)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = _wash(AppColors.leaf, 0.72),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.66)
        ..quadraticBezierTo(w * 0.45, h * 0.58, w, h * 0.70)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = _wash(AppColors.leaf, 0.58),
    );
    // A few flower dots along the lower band.
    final petal = Paint()..color = _wash(AppColors.bubblegum, 0.35);
    for (final fx in const [0.12, 0.38, 0.63, 0.88]) {
      canvas.drawCircle(
        Offset(w * fx, h * (0.74 + 0.16 * math.sin(fx * math.pi))),
        w * 0.014,
        petal,
      );
    }
  }

  void _pond(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Shore.
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.30, w, h * 0.70),
      Paint()..color = _wash(AppColors.leaf, 0.76),
    );
    // The pond itself.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.62),
        width: w * 0.86,
        height: h * 0.56,
      ),
      Paint()..color = _wash(AppColors.sky, 0.55),
    );
    // Lily pads.
    final pad = Paint()..color = _wash(AppColors.leaf, 0.42);
    for (final (fx, fy, r) in const [
      (0.30, 0.52, 0.045),
      (0.68, 0.72, 0.055),
      (0.52, 0.44, 0.035),
    ]) {
      canvas.drawCircle(Offset(w * fx, h * fy), w * r, pad);
    }
    // Reeds on the near shore.
    final reed = Paint()
      ..color = _wash(AppColors.leaf, 0.30)
      ..strokeWidth = math.max(w * 0.008, 2)
      ..strokeCap = StrokeCap.round;
    for (final fx in const [0.08, 0.11, 0.90, 0.93]) {
      canvas.drawLine(Offset(w * fx, h * 0.96), Offset(w * fx, h * 0.84), reed);
    }
  }

  void _hill(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Sun, top-right.
    canvas.drawCircle(
      Offset(w * 0.84, h * 0.12),
      w * 0.08,
      Paint()..color = _wash(AppColors.yolk, 0.25),
    );
    // Far hill, near hill.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.24, h * 0.86),
        width: w * 1.1,
        height: h * 0.9,
      ),
      Paint()..color = _wash(AppColors.tangerine, 0.70),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.74, h * 1.02),
        width: w * 1.3,
        height: h * 1.05,
      ),
      Paint()..color = _wash(AppColors.leaf, 0.62),
    );
    // One little cloud.
    final cloud = Paint()
      ..color = (dark ? AppColors.plumCard : Colors.white).withValues(
        alpha: 0.85,
      );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.30, h * 0.16),
        width: w * 0.22,
        height: h * 0.07,
      ),
      cloud,
    );
  }

  @override
  bool shouldRepaint(HabitatBackgroundPainter oldDelegate) =>
      oldDelegate.biome != biome || oldDelegate.dark != dark;
}
