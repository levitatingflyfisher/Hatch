import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/painters/egg_art.dart';
import '../../../shared/painters/ghost_cursor.dart';
import '../../../shared/painters/incubator_frame_painter.dart';
import '../../../shared/scene/scene_viewport.dart';
import '../../../shared/scene/seeded.dart';
import '../../../shared/theme/app_colors.dart';
import '../domain/construct_plan.dart';

/// Sizes a scene of [cols]×[rows] unit cells inside the available space:
/// square cells, unit clamped to the viewport law's [28, 72] px, and a
/// FittedBox so the 28px floor can never overflow the hoop. The margin term
/// solves the frame painter's 5%-of-shortest-side inset exactly, so painted
/// cells stay square and ghost-cursor scene units line up with them.
class UnitCanvas extends StatelessWidget {
  const UnitCanvas({
    super.key,
    required this.cols,
    required this.rows,
    required this.builder,
  });

  final int cols;
  final int rows;
  final Widget Function(Size size) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final c = math.max(cols, 1).toDouble();
        final r = math.max(rows, 1).toDouble();
        final avail = constraints.biggest;
        final unit = (math.min(avail.width / c, avail.height / r) * 0.88).clamp(
          SceneViewport.kMinUnitPx,
          SceneViewport.kMaxUnitPx,
        );
        // m = 0.05 * (min(c, r) * unit + 2m)  ⇒  the painter's margin lands
        // on exactly m and every cell stays unit×unit.
        final m = 0.05 * math.min(c, r) * unit / 0.9;
        final size = Size(c * unit + 2 * m, r * unit + 2 * m);
        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox.fromSize(size: size, child: builder(size)),
          ),
        );
      },
    );
  }
}

/// The construct scene: incubator frame + the eggs the move places + an
/// optional ghost cursor replaying a script in the same units.
class GuidedScene extends StatelessWidget {
  const GuidedScene({
    super.key,
    required this.plan,
    required this.hue,
    required this.seed,
    this.stackRows = 0,
    this.moveProgress = 0,
    this.ghost,
    this.accent = AppColors.yolk,
  });

  final ConstructPlan plan;
  final Color hue;
  final int seed;

  /// Rows the child has stacked (STACK only).
  final int stackRows;

  /// The guided seam move's choreography, 0..1.
  final double moveProgress;

  final GhostCursorState? ghost;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return UnitCanvas(
      cols: plan.frameB,
      rows: plan.sceneRows,
      builder: (size) {
        final margin = size.shortestSide * 0.05;
        final viewport = SceneViewport(
          hoop: Rect.fromLTWH(
            margin,
            margin,
            size.width - margin * 2,
            size.height - margin * 2,
          ),
          sceneSize: Size(
            math.max(plan.frameB, 1).toDouble(),
            math.max(plan.sceneRows, 1).toDouble(),
          ),
          minUnitPx: 1,
          maxUnitPx: double.maxFinite,
        );
        final ghostState = ghost;
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: IncubatorFramePainter(
                a: plan.frameA,
                b: plan.frameB,
                seam: plan.seam,
                accent: accent,
              ),
            ),
            CustomPaint(
              painter: ConstructOverlayPainter(
                plan: plan,
                stackRows: stackRows,
                moveProgress: moveProgress,
                hue: hue,
                seed: seed,
              ),
            ),
            if (ghostState != null)
              CustomPaint(
                painter: GhostCursorPainter(
                  state: ghostState,
                  viewport: viewport,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Eggs over the incubator frame. Mirrors IncubatorFramePainter's geometry
/// (5% margin, seam variants borrow one extra row of height) so eggs land in
/// its ghost wells.
class ConstructOverlayPainter extends CustomPainter {
  const ConstructOverlayPainter({
    required this.plan,
    required this.stackRows,
    required this.moveProgress,
    required this.hue,
    required this.seed,
  });

  final ConstructPlan plan;
  final int stackRows;
  final double moveProgress;
  final Color hue;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final margin = size.shortestSide * 0.05;
    final rows = math.max(plan.frameA, 1);
    final cols = math.max(plan.frameB, 1);
    final cellH = (size.height - margin * 2) / (rows + plan.extraRows);
    final cellW = (size.width - margin * 2) / cols;

    Offset center(int r, int c) =>
        Offset(margin + cellW * (c + 0.5), margin + cellH * (r + 0.5));

    void egg(int r, int c, {Offset at = Offset.zero, double alpha = 1}) {
      final i = r * cols + c;
      final base = at == Offset.zero ? center(r, c) : at;
      final rect = Rect.fromCenter(
        center: base + seededOffset(seed, i, math.min(cellW, cellH) * 0.03),
        width: cellW * 0.62,
        height: cellH * 0.74,
      );
      final a = alpha.clamp(0.0, 1.0);
      EggArt.paintEgg(
        canvas,
        rect,
        seed: seededInt(seed, i),
        shell: AppColors.shell.withValues(alpha: a),
        speckle: AppColors.speckle.withValues(alpha: a),
        ink: AppColors.ink.withValues(alpha: a),
      );
    }

    void rowOfEggs(int r, {Offset shift = Offset.zero, double alpha = 1}) {
      for (var c = 0; c < plan.frameB; c++) {
        egg(r, c, at: center(r, c) + shift, alpha: alpha);
      }
    }

    final p = moveProgress.clamp(0.0, 1.0);
    switch (plan.verb) {
      case ConstructVerb.stack:
        for (var r = 0; r < math.min(stackRows, plan.frameA); r++) {
          rowOfEggs(r);
        }
      case ConstructVerb.fold:
        final half = plan.prefilledRows;
        for (var r = 0; r < half; r++) {
          rowOfEggs(r);
        }
        if (p > 0) {
          // The mirror copy sweeps from the source rows across the seam.
          final ease = Curves.easeInOut.transform(p);
          for (var r = half; r < plan.frameA; r++) {
            final mirror = math.max(2 * half - 1 - r, 0);
            for (var c = 0; c < plan.frameB; c++) {
              egg(
                r,
                c,
                at: Offset.lerp(center(mirror, c), center(r, c), ease)!,
                alpha: 0.35 + 0.65 * p,
              );
            }
          }
        }
      case ConstructVerb.slice:
        final seamRow = (plan.seam as SplitSeam).afterRow;
        final gap = p * cellH * 0.16;
        for (var r = 0; r < plan.frameA; r++) {
          rowOfEggs(r, shift: r >= seamRow ? Offset(0, gap) : Offset.zero);
        }
      case ConstructVerb.trim:
        for (var r = 0; r < plan.frameA; r++) {
          rowOfEggs(r);
        }
        // The overhang row of the ×10 bolt rolls off the edge.
        final roll = Curves.easeIn.transform(p);
        rowOfEggs(
          plan.frameA,
          shift: Offset(roll * size.width * 0.55, roll * cellH * 0.5),
          alpha: 1 - roll * 0.85,
        );
      case ConstructVerb.addRow:
        for (var r = 0; r < plan.frameA; r++) {
          rowOfEggs(r);
        }
        if (p > 0) {
          // The added group drops into the ghost row.
          final drop = Curves.easeOutBack.transform(p);
          rowOfEggs(
            plan.frameA,
            shift: Offset(0, -(1 - drop) * cellH * 0.8),
            alpha: p,
          );
        }
    }
  }

  @override
  bool shouldRepaint(ConstructOverlayPainter oldDelegate) =>
      oldDelegate.plan != plan ||
      oldDelegate.stackRows != stackRows ||
      oldDelegate.moveProgress != moveProgress ||
      oldDelegate.hue != hue ||
      oldDelegate.seed != seed;
}

/// One dispenser row-strip: a carton bar holding [count] eggs, the thing the
/// child drags (or tap-taps) into the frame.
class RowStripPainter extends CustomPainter {
  const RowStripPainter({
    required this.count,
    required this.hue,
    required this.seed,
  });

  final int count;
  final Color hue;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final bar = Rect.fromLTWH(
      0,
      size.height * 0.30,
      size.width,
      size.height * 0.70,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bar, Radius.circular(size.height * 0.22)),
      Paint()..color = hue,
    );
    final n = math.max(count, 1);
    final cellW = size.width / n;
    for (var c = 0; c < count; c++) {
      final rect = Rect.fromCenter(
        center: Offset(cellW * (c + 0.5), size.height * 0.42),
        width: math.min(cellW * 0.62, size.height * 0.6),
        height: size.height * 0.72,
      );
      EggArt.paintEgg(canvas, rect, seed: seededInt(seed, 500 + c));
    }
  }

  @override
  bool shouldRepaint(RowStripPainter oldDelegate) =>
      oldDelegate.count != count ||
      oldDelegate.hue != hue ||
      oldDelegate.seed != seed;
}
