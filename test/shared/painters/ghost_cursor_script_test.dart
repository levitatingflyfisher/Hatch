import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/shared/painters/ghost_cursor.dart';
import 'package:hatch/shared/scene/vignette_step.dart';

void main() {
  group('GhostCursorScript', () {
    final script = GhostCursorScript(const [
      MoveTo(Offset(4, 2), duration: Duration(milliseconds: 400)),
      TapAt(duration: Duration(milliseconds: 200)),
      DragTo(Offset(4, 6), duration: Duration(milliseconds: 600)),
      Pause(Duration(milliseconds: 300)),
    ], start: const Offset(1, 2));

    test('totalDuration sums the steps', () {
      expect(script.totalDuration, const Duration(milliseconds: 1500));
    });

    test('starts at the start point', () {
      final s = script.stateAt(Duration.zero);
      expect(s.position, const Offset(1, 2));
      expect(s.pressed, isFalse);
      expect(s.done, isFalse);
    });

    test('move eases between waypoints and traces the trail', () {
      final s = script.stateAt(const Duration(milliseconds: 200));
      // easeInOut(0.5) = 0.5 -> midpoint.
      expect(s.position.dx, closeTo(2.5, 1e-6));
      expect(s.position.dy, closeTo(2, 1e-6));
      expect(s.pressed, isFalse);
      expect(s.trail.first, const Offset(1, 2));
      expect(s.trail.last, s.position);
    });

    test('tap holds position, presses briefly, ripples', () {
      final early = script.stateAt(const Duration(milliseconds: 450));
      expect(early.position, const Offset(4, 2));
      expect(early.pressed, isTrue);
      expect(early.ripple, closeTo(0.25, 1e-9));
      final late = script.stateAt(const Duration(milliseconds: 590));
      expect(late.pressed, isFalse);
      expect(late.ripple, closeTo(0.95, 1e-9));
    });

    test('drag presses and moves', () {
      final s = script.stateAt(const Duration(milliseconds: 900));
      expect(s.pressed, isTrue);
      expect(s.position.dx, closeTo(4, 1e-6));
      expect(s.position.dy, closeTo(4, 1e-6)); // easeInOut(0.5) of 2->6
    });

    test('pause holds the drag endpoint unpressed', () {
      final s = script.stateAt(const Duration(milliseconds: 1300));
      expect(s.position, const Offset(4, 6));
      expect(s.pressed, isFalse);
      expect(s.done, isFalse);
    });

    test('past the end reports done with the full trail', () {
      final s = script.stateAt(const Duration(seconds: 5));
      expect(s.done, isTrue);
      expect(s.position, const Offset(4, 6));
      expect(s.trail, const [Offset(1, 2), Offset(4, 2), Offset(4, 6)]);
    });
  });
}
