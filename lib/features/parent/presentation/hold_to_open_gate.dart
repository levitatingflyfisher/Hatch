import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

/// The parent-corner gate: press and hold a ring for two seconds; the ring
/// fills as you hold; releasing early rewinds it. No PIN by design — this
/// is a speed bump that filters out casual small-finger taps, not security
/// (DESIGN.md: "hold-to-open gate"; nothing behind it is secret from the
/// household, it is merely not for children).
class HoldToOpenGate extends StatefulWidget {
  const HoldToOpenGate({
    super.key,
    required this.child,
    this.holdDuration = const Duration(seconds: 2),
  });

  /// Shown only after a completed hold.
  final Widget child;

  final Duration holdDuration;

  @override
  State<HoldToOpenGate> createState() => _HoldToOpenGateState();
}

class _HoldToOpenGateState extends State<HoldToOpenGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  var _open = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: widget.holdDuration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              setState(() => _open = true);
            }
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _release() {
    // Early release cancels: rewind quickly to zero, keep the gate shut.
    if (!_open) {
      _controller.animateBack(0, duration: const Duration(milliseconds: 200));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_open) return widget.child;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('For grown-ups', style: textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Press and hold the ring to open', style: textTheme.bodyLarge),
          const SizedBox(height: 32),
          Semantics(
            button: true,
            label: 'Hold to open',
            child: GestureDetector(
              key: const Key('hold-gate-ring'),
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => _controller.forward(),
              onTapUp: (_) => _release(),
              onTapCancel: _release,
              child: SizedBox.square(
                dimension: 120,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    painter: _RingPainter(progress: _controller.value),
                    child: const Center(
                      child: Icon(Icons.touch_app_outlined, size: 36),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 8;
    final track = Paint()
      ..color = AppColors.speckle
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(center, radius, track);
    if (progress > 0) {
      final fill = Paint()
        ..color = AppColors.yolk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi * 2 * progress.clamp(0.0, 1.0),
        false,
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
