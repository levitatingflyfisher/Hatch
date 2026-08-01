import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../domain/egg_glyph.dart';

/// The egg avatar: a speckled shell cracked open on a nest, with a critter
/// peeking over the rim — dot eyes, optional antennae, body hue from the
/// critter palette. Entirely painted — no images — and deterministic per
/// (glyphSeed, paletteIndex), so a profile's egg is stable everywhere it
/// appears.
class EggAvatar extends StatelessWidget {
  final int glyphSeed;
  final int paletteIndex;
  final double size;

  const EggAvatar({
    super.key,
    required this.glyphSeed,
    required this.paletteIndex,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _EggAvatarPainter(
        glyphSeed: glyphSeed,
        paletteIndex: paletteIndex,
      ),
    );
  }
}

class _EggAvatarPainter extends CustomPainter {
  final int glyphSeed;
  final int paletteIndex;

  const _EggAvatarPainter({
    required this.glyphSeed,
    required this.paletteIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final glyph = eggGlyphFor(glyphSeed);
    final s = size.width;
    final body = AppColors.critterPalette[paletteIndex % kCritterPaletteSize];

    // Shell bounding box; the crack rim sits at [rimY].
    final eggRect = Rect.fromLTRB(0.19 * s, 0.10 * s, 0.81 * s, 0.86 * s);
    final rimY = 0.44 * s;

    // Nest, back half (the egg settles into it).
    final nestRect = Rect.fromCenter(
      center: Offset(0.5 * s, 0.80 * s),
      width: 0.82 * s,
      height: 0.26 * s,
    );
    canvas.drawOval(nestRect, Paint()..color = AppColors.speckle);

    // Peeking critter: dome first so the shell overlaps its base.
    final domeCenter = Offset(0.5 * s, 0.36 * s);
    final domeRadius = 0.20 * s;
    if (glyph.hasAntennae) {
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.014 * s
        ..strokeCap = StrokeCap.round
        ..color = AppColors.ink;
      for (final dir in [-1, 1]) {
        final root = Offset(0.5 * s + dir * 0.07 * s, 0.20 * s);
        final tip = Offset(0.5 * s + dir * 0.115 * s, 0.105 * s);
        canvas.drawLine(root, tip, stroke);
        canvas.drawCircle(tip, 0.020 * s, Paint()..color = AppColors.ink);
      }
    }
    canvas.drawCircle(domeCenter, domeRadius, Paint()..color = body);

    // Eyes: two ink dots with a seeded sideways glance.
    final eyeY = 0.315 * s;
    final glance = glyph.eyeShift * 0.020 * s;
    final eye = Paint()..color = AppColors.ink;
    canvas.drawCircle(
      Offset(0.5 * s - 0.066 * s + glance, eyeY),
      0.026 * s,
      eye,
    );
    canvas.drawCircle(
      Offset(0.5 * s + 0.066 * s + glance, eyeY),
      0.026 * s,
      eye,
    );

    // Cracked shell: the egg silhouette intersected with everything below the
    // seeded zigzag rim.
    final crack = _crackEdge(glyph, eggRect, rimY, s);
    final below = Path.from(crack)
      ..lineTo(eggRect.right + s, eggRect.bottom + s)
      ..lineTo(eggRect.left - s, eggRect.bottom + s)
      ..close();
    final shell = Path.combine(
      PathOperation.intersect,
      Path()..addOval(eggRect),
      below,
    );
    canvas.drawPath(shell, Paint()..color = AppColors.shell);

    // Speckles, clipped to the shell so none floats off the egg.
    canvas.save();
    canvas.clipPath(shell);
    final speckle = Paint()..color = AppColors.speckle;
    for (var i = 0; i < EggGlyph.speckleCount; i++) {
      canvas.drawCircle(
        Offset(
          eggRect.left + glyph.speckleX[i] * eggRect.width,
          eggRect.top + glyph.speckleY[i] * eggRect.height,
        ),
        glyph.speckleR[i] * eggRect.width,
        speckle,
      );
    }
    canvas.restore();

    // Outline the shell and the crack rim in ink — the shell is nearly the
    // ground color in light mode, so the edge carries the silhouette.
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.016 * s
      ..strokeJoin = StrokeJoin.round
      ..color = AppColors.ink.withValues(alpha: 0.55);
    canvas.drawPath(shell, edge);

    // Nest, front lip over the egg's base.
    final lip = Path.combine(
      PathOperation.intersect,
      Path()..addOval(nestRect),
      Path()..addRect(Rect.fromLTRB(0, nestRect.center.dy, s, s)),
    );
    canvas.drawPath(
      lip,
      Paint()..color = Color.lerp(AppColors.speckle, AppColors.ink, 0.18)!,
    );
  }

  /// The zigzag crack rim, left egg edge to right, teeth jittered by seed.
  Path _crackEdge(EggGlyph glyph, Rect eggRect, double rimY, double s) {
    const teeth = EggGlyph.crackToothCount;
    final path = Path()..moveTo(eggRect.left - 1, rimY);
    for (var i = 0; i < teeth; i++) {
      final t = (i + 1) / (teeth + 1);
      final x = eggRect.left + t * eggRect.width;
      final depth = (0.030 + glyph.crackJitter[i] * 0.035) * s;
      path.lineTo(x, rimY + (i.isEven ? depth : -depth));
    }
    path.lineTo(eggRect.right + 1, rimY);
    return path;
  }

  @override
  bool shouldRepaint(_EggAvatarPainter oldDelegate) =>
      oldDelegate.glyphSeed != glyphSeed ||
      oldDelegate.paletteIndex != paletteIndex;
}
