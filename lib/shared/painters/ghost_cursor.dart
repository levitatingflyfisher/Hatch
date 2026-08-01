import 'package:flutter/material.dart';

import '../scene/scene_viewport.dart';
import '../scene/vignette_step.dart';
import '../theme/app_colors.dart';
import 'dotted_trail_painter.dart';

/// Snapshot of the ghost cursor at one instant of a vignette replay.
/// Positions are scene units.
class GhostCursorState {
  const GhostCursorState({
    required this.position,
    required this.pressed,
    required this.trail,
    this.ripple,
    this.done = false,
  });

  final Offset position;

  /// True mid-drag (and during the tap's press dip).
  final bool pressed;

  /// The path traced so far: step waypoints + the current position.
  final List<Offset> trail;

  /// Tap ripple 0..1, null when no ripple is live.
  final double? ripple;

  final bool done;
}

/// Replays a `List<VignetteStep>` script as pure elapsed→state math. The
/// vignette engine is data, not bespoke code per family (spec law); the
/// same script type drives every strategy vignette.
class GhostCursorScript {
  GhostCursorScript(this.steps, {this.start = Offset.zero});

  final List<VignetteStep> steps;
  final Offset start;

  Duration get totalDuration =>
      steps.fold(Duration.zero, (sum, s) => sum + s.duration);

  GhostCursorState stateAt(Duration elapsed) {
    var position = start;
    final trail = <Offset>[start];
    var remaining = elapsed;
    for (final step in steps) {
      if (remaining >= step.duration) {
        remaining -= step.duration;
        position = _endOf(step, position);
        if (step is MoveTo || step is DragTo) trail.add(position);
        continue;
      }
      final t = step.duration.inMicroseconds == 0
          ? 1.0
          : remaining.inMicroseconds / step.duration.inMicroseconds;
      switch (step) {
        case MoveTo(:final to):
          final p = Offset.lerp(position, to, Curves.easeInOut.transform(t))!;
          return GhostCursorState(
            position: p,
            pressed: false,
            trail: [...trail, p],
          );
        case DragTo(:final to):
          final p = Offset.lerp(position, to, Curves.easeInOut.transform(t))!;
          return GhostCursorState(
            position: p,
            pressed: true,
            trail: [...trail, p],
          );
        case TapAt():
          return GhostCursorState(
            position: position,
            pressed: t < 0.4,
            trail: trail,
            ripple: t,
          );
        case Pause():
          return GhostCursorState(
            position: position,
            pressed: false,
            trail: trail,
          );
      }
    }
    return GhostCursorState(
      position: position,
      pressed: false,
      trail: trail,
      done: true,
    );
  }

  static Offset _endOf(VignetteStep step, Offset from) => switch (step) {
    MoveTo(:final to) => to,
    DragTo(:final to) => to,
    TapAt() || Pause() => from,
  };
}

/// The glowing dot + dotted wake + tap ripple — never a hand (spec law:
/// a cursor a child imitates, not an adult hand that demonstrates).
class GhostCursorPainter extends CustomPainter {
  const GhostCursorPainter({
    required this.state,
    required this.viewport,
    this.color = AppColors.yolk,
  });

  final GhostCursorState state;
  final SceneViewport viewport;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (state.trail.length > 1) {
      final path = Path();
      final first = viewport.toPx(state.trail.first);
      path.moveTo(first.dx, first.dy);
      for (final p in state.trail.skip(1)) {
        final px = viewport.toPx(p);
        path.lineTo(px.dx, px.dy);
      }
      DottedTrailPainter.paintDots(
        canvas,
        path,
        color: color.withValues(alpha: 0.65),
        dotRadius: 2.6,
        spacing: 10,
      );
    }

    final center = viewport.toPx(state.position);
    final ripple = state.ripple;
    if (ripple != null && ripple > 0) {
      canvas.drawCircle(
        center,
        10 + ripple * 24,
        Paint()
          ..color = color.withValues(alpha: (1 - ripple) * 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
    final dip = state.pressed ? 0.8 : 1.0;
    canvas.drawCircle(
      center,
      16 * dip,
      Paint()..color = color.withValues(alpha: 0.25),
    );
    canvas.drawCircle(
      center,
      10 * dip,
      Paint()..color = color.withValues(alpha: 0.55),
    );
    canvas.drawCircle(
      center,
      5.5 * dip,
      Paint()..color = Color.lerp(color, Colors.white, 0.55)!,
    );
  }

  @override
  bool shouldRepaint(GhostCursorPainter oldDelegate) =>
      oldDelegate.state != state ||
      oldDelegate.viewport != viewport ||
      oldDelegate.color != color;
}
