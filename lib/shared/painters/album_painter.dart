import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mastery_core/mastery_core.dart';

import '../critters/critter_painter.dart';
import '../critters/critter_spec.dart';
import '../theme/app_colors.dart';
import 'tray_painter.dart';

/// The Critter Album: the full 0–10 table as an 11×11 grid of mini-cells
/// (66 folded facts mirrored across the diagonal). Fully visible from
/// minute one; unstarted facts are honest plain shell — no silhouettes, no
/// locks, no shimmer (refuse-list law).
///
/// Cell states:
/// - unstarted: plain muslin cell;
/// - in progress: mini tray at the fact's rung (mirror side shows the
///   rotated b×a tray — commutativity made visible);
/// - hatched: the critter (mirror side hatches the twin once confirmed;
///   until then an egg sits in the mirror cell, still incubating);
/// - due review: sleepy lids + zzz (the sleepy law: due = wants a visit,
///   never punished);
/// - squares: crowned royals down the diagonal.
///
/// Must read at ~30px cells. Pure painter over [SamplerView].
class AlbumPainter extends CustomPainter {
  const AlbumPainter({required this.view, this.dark = false});

  final SamplerView view;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = math.min(size.width, size.height) / 11;
    final origin = Offset(
      (size.width - cell * 11) / 2,
      (size.height - cell * 11) / 2,
    );
    for (var row = 0; row <= 10; row++) {
      for (var col = 0; col <= 10; col++) {
        final rect = Rect.fromLTWH(
          origin.dx + col * cell,
          origin.dy + row * cell,
          cell,
          cell,
        ).deflate(cell * 0.045);
        _paintCell(canvas, rect, row, col);
      }
    }
  }

  void _paintCell(Canvas canvas, Rect rect, int row, int col) {
    final fact = Fact.folded(row, col);
    final state = view[fact];
    final mirrorSide = row > col;

    if (state == null || !state.started) {
      _muslin(canvas, rect);
      return;
    }

    final hatched = state.phase == Phase.automatic;
    if (!hatched) {
      // Mini tray at rung; the mirror side shows the rotated tray.
      final spec = CritterSpec.of(fact);
      final tray = TrayPainter(
        a: row,
        b: col,
        rung: state.rung,
        hue: spec.hue,
        seed: spec.seed,
      );
      canvas.save();
      canvas.translate(rect.left, rect.top);
      tray.paint(canvas, rect.size);
      canvas.restore();
      return;
    }

    if (mirrorSide && !state.mirrorFilled) {
      // The twin is still incubating: one egg in the mirror cell.
      _twinEgg(canvas, rect, fact);
      return;
    }

    final spec = mirrorSide ? CritterSpec.of(fact).twin : CritterSpec.of(fact);
    canvas.save();
    canvas.translate(rect.left, rect.top);
    CritterPainter(spec, sleepy: state.dueNow).paint(canvas, rect.size);
    canvas.restore();
  }

  void _muslin(Canvas canvas, Rect rect) {
    final radius = Radius.circular(rect.shortestSide * 0.14);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()
        ..color = dark
            ? AppColors.plumCard.withValues(alpha: 0.55)
            : AppColors.shell.withValues(alpha: 0.75),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()
        ..color = AppColors.speckle.withValues(alpha: dark ? 0.35 : 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(rect.shortestSide * 0.03, 0.6),
    );
  }

  void _twinEgg(Canvas canvas, Rect rect, Fact fact) {
    _muslin(canvas, rect);
    final spec = CritterSpec.of(fact);
    final egg = Rect.fromCenter(
      center: rect.center,
      width: rect.width * 0.42,
      height: rect.height * 0.56,
    );
    // Egg tinted faintly with the twin's hue so the pair reads together.
    canvas.drawOval(
      egg.inflate(rect.width * 0.06),
      Paint()..color = spec.hue.withValues(alpha: 0.25),
    );
    canvas.drawPath(_eggOval(egg), Paint()..color = AppColors.shell);
    canvas.drawCircle(
      Offset(egg.center.dx - egg.width * 0.18, egg.center.dy),
      math.max(egg.width * 0.09, 0.5),
      Paint()..color = AppColors.speckle,
    );
    canvas.drawCircle(
      Offset(
        egg.center.dx + egg.width * 0.14,
        egg.center.dy + egg.height * 0.2,
      ),
      math.max(egg.width * 0.07, 0.4),
      Paint()..color = AppColors.speckle,
    );
  }

  static Path _eggOval(Rect r) => Path()
    ..addOval(
      Rect.fromCenter(
        center: r.center + Offset(0, r.height * 0.04),
        width: r.width,
        height: r.height,
      ),
    );

  @override
  bool shouldRepaint(AlbumPainter oldDelegate) =>
      oldDelegate.view != view || oldDelegate.dark != dark;
}
