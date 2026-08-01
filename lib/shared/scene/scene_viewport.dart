import 'dart:ui';

/// Maps scene units (1 cell = 1u) to logical pixels inside a hoop rect.
///
/// Spec law: `scale = min(hoopW / neededW, hoopH / neededH)` clamped to
/// [28, 72] logical px per unit; content centers in the hoop (offsets may go
/// negative when the 28px floor forces overflow — the owning screen decides
/// how to handle that, the transform never lies about it).
class SceneViewport {
  SceneViewport({
    required this.hoop,
    required this.sceneSize,
    double minUnitPx = kMinUnitPx,
    double maxUnitPx = kMaxUnitPx,
  }) : assert(sceneSize.width > 0 && sceneSize.height > 0),
       unitPx = _fit(hoop.size, sceneSize, minUnitPx, maxUnitPx) {
    origin =
        hoop.topLeft +
        Offset(
          (hoop.width - sceneSize.width * unitPx) / 2,
          (hoop.height - sceneSize.height * unitPx) / 2,
        );
  }

  static const double kMinUnitPx = 28;
  static const double kMaxUnitPx = 72;

  static double _fit(Size hoop, Size scene, double min, double max) {
    final fit = _min(hoop.width / scene.width, hoop.height / scene.height);
    return fit.clamp(min, max);
  }

  static double _min(double a, double b) => a < b ? a : b;

  /// The work area in logical px.
  final Rect hoop;

  /// Scene extent in units.
  final Size sceneSize;

  /// Logical px per scene unit.
  final double unitPx;

  /// Px position of scene origin (0, 0).
  late final Offset origin;

  Offset toPx(Offset scene) => origin + scene * unitPx;

  Offset toScene(Offset px) => (px - origin) / unitPx;

  double lengthToPx(double units) => units * unitPx;

  Rect rectToPx(Rect scene) =>
      Rect.fromPoints(toPx(scene.topLeft), toPx(scene.bottomRight));

  Size get contentSize => sceneSize * unitPx;

  Rect get contentRect => origin & contentSize;

  /// True when the 28px floor made the content larger than the hoop.
  bool get overflowsHoop =>
      contentSize.width > hoop.width + 0.5 ||
      contentSize.height > hoop.height + 0.5;
}
