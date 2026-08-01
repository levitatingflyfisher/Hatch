import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../critters/critter_painter.dart';
import '../critters/critter_spec.dart';
import 'egg_art.dart';
import 'spark_particles.dart';

/// The app's signature 1.2s moment: egg rocks (2 wobbles) → crack lines
/// grow → shell splits → the critter pops with a settle bounce. Pure
/// elapsed→frame math; the feature drives [HatchMomentPainter.progress]
/// from a ChoreographyClock.
class HatchMoment {
  HatchMoment._();

  static const duration = Duration(milliseconds: 1200);

  // Phase windows over progress 0..1.
  static const rockEnd = 0.32;
  static const crackEnd = 0.58;
  static const splitEnd = 0.76;

  /// Rock tilt in radians: two damped wobbles.
  static double rockAngle(double progress) {
    if (progress <= 0 || progress >= rockEnd) return 0;
    final t = progress / rockEnd;
    return math.sin(t * math.pi * 4) * 0.14 * (1 - t * 0.55);
  }

  /// Crack growth 0..1.
  static double crack(double progress) {
    if (progress <= rockEnd) return 0;
    return ((progress - rockEnd) / (crackEnd - rockEnd)).clamp(0.0, 1.0);
  }

  /// Shell separation 0..1.
  static double split(double progress) {
    if (progress <= crackEnd) return 0;
    return ((progress - crackEnd) / (splitEnd - crackEnd)).clamp(0.0, 1.0);
  }

  /// Critter pop-and-settle 0..1.
  static double pop(double progress) {
    if (progress <= crackEnd) return 0;
    return ((progress - crackEnd) / (1 - crackEnd)).clamp(0.0, 1.0);
  }
}

class HatchMomentPainter extends CustomPainter {
  const HatchMomentPainter({required this.spec, required this.progress});

  final CritterSpec spec;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.56);
    final eggH = size.height * 0.58;
    final eggRect = Rect.fromCenter(
      center: center,
      width: eggH * 0.78,
      height: eggH,
    );
    final seed = spec.seed;

    final pop = HatchMoment.pop(progress);
    if (pop > 0) {
      // Critter rises behind the cup, overshoots, settles.
      final scale = 0.35 + 0.65 * Curves.easeOutBack.transform(pop);
      final critterSide = size.shortestSide * 0.8;
      final rise = eggRect.height * 0.22 * (1 - pop);
      canvas.save();
      canvas.translate(center.dx, center.dy - critterSide * 0.06 + rise);
      canvas.scale(scale);
      canvas.translate(-critterSide / 2, -critterSide / 2);
      CritterPainter(spec).paint(canvas, Size.square(critterSide));
      canvas.restore();
      SparkBurstPainter.paintBurst(
        canvas,
        center - Offset(0, eggRect.height * 0.35),
        radius: size.shortestSide * 0.42,
        progress: pop,
        seed: seed,
      );
    }

    final split = HatchMoment.split(progress);
    if (split > 0 || pop > 0) {
      // Bottom cup stays in front of the critter's feet.
      final cupDrop = pop * eggRect.height * 0.10;
      canvas.save();
      canvas.translate(0, cupDrop);
      canvas.drawPath(
        EggArt.cupPath(eggRect, seed),
        Paint()..color = _shellColor,
      );
      canvas.restore();
      // Top cap lifts, tilts, and fades away.
      final capLift = Curves.easeOut.transform(math.max(split, pop * 0.9));
      canvas.save();
      canvas.translate(
        center.dx + capLift * eggRect.width * 0.35,
        center.dy - capLift * eggRect.height * 0.85,
      );
      canvas.rotate(capLift * 0.6);
      canvas.translate(-center.dx, -center.dy);
      final alpha = (1 - pop * 0.85).clamp(0.0, 1.0);
      canvas.drawPath(
        EggArt.capPath(eggRect, seed),
        Paint()..color = _shellColor.withValues(alpha: alpha),
      );
      canvas.restore();
      return;
    }

    // Intact egg: rocking, then cracking.
    canvas.save();
    canvas.translate(center.dx, eggRect.bottom);
    canvas.rotate(HatchMoment.rockAngle(progress));
    canvas.translate(-center.dx, -eggRect.bottom);
    EggArt.paintEgg(
      canvas,
      eggRect,
      seed: seed,
      crack: HatchMoment.crack(progress),
    );
    canvas.restore();
  }

  Color get _shellColor => const Color(0xFFFDF1DC);

  @override
  bool shouldRepaint(HatchMomentPainter oldDelegate) =>
      oldDelegate.spec != spec || oldDelegate.progress != progress;
}
