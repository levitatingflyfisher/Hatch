import 'dart:math' as math;
import 'dart:ui';

import '../scene/seeded.dart';
import '../theme/app_colors.dart';

/// Shared egg drawing for tray / sweep / hatch / album painters — one egg
/// language everywhere. All speckle and crack geometry is seeded.
class EggArt {
  EggArt._();

  /// Egg outline: round bottom, tapered top.
  static Path eggPath(Rect r) {
    final w = r.width;
    final h = r.height;
    final cx = r.center.dx;
    return Path()
      ..moveTo(cx, r.top)
      ..cubicTo(
        cx + w * 0.30,
        r.top + h * 0.02,
        cx + w * 0.50,
        r.top + h * 0.42,
        cx + w * 0.50,
        r.top + h * 0.64,
      )
      ..cubicTo(
        cx + w * 0.50,
        r.top + h * 0.90,
        cx + w * 0.26,
        r.top + h,
        cx,
        r.top + h,
      )
      ..cubicTo(
        cx - w * 0.26,
        r.top + h,
        cx - w * 0.50,
        r.top + h * 0.90,
        cx - w * 0.50,
        r.top + h * 0.64,
      )
      ..cubicTo(
        cx - w * 0.50,
        r.top + h * 0.42,
        cx - w * 0.30,
        r.top + h * 0.02,
        cx,
        r.top,
      )
      ..close();
  }

  /// Zigzag crack polyline across the egg at ~52% height.
  static Path crackPath(Rect r, int seed) {
    const teeth = 5;
    final y = r.top + r.height * 0.52;
    final path = Path()..moveTo(r.left + r.width * 0.06, y);
    for (var i = 1; i <= teeth; i++) {
      final x = r.left + r.width * (0.06 + (0.88 / teeth) * i);
      final dy =
          (i.isEven ? 1 : -1) *
          (r.height * 0.07 + seededRange(seed, 60 + i, 0, r.height * 0.05));
      path.lineTo(x, y + dy);
    }
    return path;
  }

  /// Paints an egg; [crack] 0..1 grows the crack line across the shell.
  static void paintEgg(
    Canvas canvas,
    Rect rect, {
    required int seed,
    double crack = 0,
    Color shell = AppColors.shell,
    Color speckle = AppColors.speckle,
    Color ink = AppColors.ink,
  }) {
    final egg = eggPath(rect);
    canvas.drawPath(egg, Paint()..color = shell);
    canvas.save();
    canvas.clipPath(egg);
    final n = 4 + seededPick(seed, 90, 3);
    final speckPaint = Paint()..color = speckle;
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(
        Offset(
          rect.left + rect.width * seededRange(seed, 70 + i * 2, 0.15, 0.85),
          rect.top + rect.height * seededRange(seed, 71 + i * 2, 0.15, 0.85),
        ),
        rect.shortestSide * (0.05 + seededUnit(seed, 80 + i) * 0.03),
        speckPaint,
      );
    }
    if (crack > 0) {
      final full = crackPath(rect, seed);
      final metric = full.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * crack.clamp(0.0, 1.0)),
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(rect.width * 0.045, 0.8)
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
  }

  /// The lower shell cup left behind after hatching (zigzag rim).
  static Path cupPath(Rect r, int seed) {
    final egg = eggPath(r);
    final rim = Path()..addPath(crackPath(r, seed), Offset.zero);
    final region = rim
      ..lineTo(r.right + r.width, r.top + r.height * 0.6)
      ..lineTo(r.right + r.width, r.bottom + r.height)
      ..lineTo(r.left - r.width, r.bottom + r.height)
      ..lineTo(r.left - r.width, r.top + r.height * 0.6)
      ..close();
    return Path.combine(PathOperation.intersect, egg, region);
  }

  /// The top shell cap (complement of [cupPath]).
  static Path capPath(Rect r, int seed) {
    final egg = eggPath(r);
    return Path.combine(PathOperation.difference, egg, cupPath(r, seed));
  }

  /// An opened egg: shell cup + a hue-colored hatchling head peeking with
  /// ink dot eyes. The "filled cell" state of the Rush sweep.
  static void paintHatchedPeek(
    Canvas canvas,
    Rect rect, {
    required int seed,
    required Color hue,
    Color shell = AppColors.shell,
    Color ink = AppColors.ink,
  }) {
    final headR = rect.width * 0.34;
    final headC = Offset(rect.center.dx, rect.top + rect.height * 0.42);
    canvas.drawCircle(headC, headR, Paint()..color = hue);
    final eyeR = math.max(headR * 0.16, 0.6);
    final inkPaint = Paint()..color = ink;
    canvas.drawCircle(
      headC + Offset(-headR * 0.4, -headR * 0.1),
      eyeR,
      inkPaint,
    );
    canvas.drawCircle(
      headC + Offset(headR * 0.4, -headR * 0.1),
      eyeR,
      inkPaint,
    );
    canvas.drawPath(cupPath(rect, seed), Paint()..color = shell);
  }
}
