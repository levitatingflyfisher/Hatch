import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/shared/scene/scene_viewport.dart';

void main() {
  group('SceneViewport', () {
    test('fits scene into hoop with min-dimension scale', () {
      final vp = SceneViewport(
        hoop: const Rect.fromLTWH(0, 0, 320, 480),
        sceneSize: const Size(8, 10),
      );
      // 320/8 = 40, 480/10 = 48 -> 40, inside [28, 72].
      expect(vp.unitPx, 40);
    });

    test('clamps scale to the 28px floor', () {
      final vp = SceneViewport(
        hoop: const Rect.fromLTWH(0, 0, 200, 200),
        sceneSize: const Size(10, 10),
      );
      expect(vp.unitPx, 28);
      expect(vp.overflowsHoop, isTrue);
    });

    test('clamps scale to the 72px ceiling', () {
      final vp = SceneViewport(
        hoop: const Rect.fromLTWH(0, 0, 600, 600),
        sceneSize: const Size(2, 2),
      );
      expect(vp.unitPx, 72);
      expect(vp.overflowsHoop, isFalse);
    });

    test('centers content inside the hoop', () {
      final vp = SceneViewport(
        hoop: const Rect.fromLTWH(10, 20, 320, 480),
        sceneSize: const Size(4, 6),
      );
      // 320/4=80, 480/6=80 -> clamped to 72; content 288x432.
      expect(vp.unitPx, 72);
      expect(
        vp.origin,
        const Offset(10 + (320 - 288) / 2, 20 + (480 - 432) / 2),
      );
      expect(vp.contentRect.center, vp.hoop.center);
    });

    test('toPx and toScene round-trip', () {
      final vp = SceneViewport(
        hoop: const Rect.fromLTWH(0, 0, 360, 500),
        sceneSize: const Size(7, 4),
      );
      const scenePoint = Offset(2.5, 1.25);
      final px = vp.toPx(scenePoint);
      final back = vp.toScene(px);
      expect(back.dx, closeTo(scenePoint.dx, 1e-9));
      expect(back.dy, closeTo(scenePoint.dy, 1e-9));
    });

    test('rectToPx maps a unit cell to unitPx square', () {
      final vp = SceneViewport(
        hoop: const Rect.fromLTWH(0, 0, 360, 360),
        sceneSize: const Size(6, 6),
      );
      final r = vp.rectToPx(const Rect.fromLTWH(1, 2, 1, 1));
      expect(r.width, closeTo(vp.unitPx, 1e-9));
      expect(r.height, closeTo(vp.unitPx, 1e-9));
      expect(r.topLeft, vp.toPx(const Offset(1, 2)));
    });
  });
}
