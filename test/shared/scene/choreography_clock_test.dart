import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/shared/scene/choreography_clock.dart';

void main() {
  group('ChoreographyClock', () {
    test('elapsed only advances on tick', () {
      var now = DateTime(2026, 8, 6, 9);
      withClock(Clock(() => now), () {
        final c = ChoreographyClock();
        c.start();
        now = now.add(const Duration(milliseconds: 500));
        expect(c.elapsed, Duration.zero);
        c.tick();
        expect(c.elapsed, const Duration(milliseconds: 500));
      });
    });

    test('stop freezes elapsed; start resumes from it', () {
      var now = DateTime(2026, 8, 6, 9);
      withClock(Clock(() => now), () {
        final c = ChoreographyClock();
        c.start();
        now = now.add(const Duration(seconds: 1));
        c.stop();
        expect(c.elapsed, const Duration(seconds: 1));
        expect(c.isRunning, isFalse);

        now = now.add(const Duration(minutes: 5));
        c.tick();
        expect(c.elapsed, const Duration(seconds: 1));

        c.start();
        now = now.add(const Duration(milliseconds: 250));
        c.tick();
        expect(c.elapsed, const Duration(milliseconds: 1250));
      });
    });

    test('start while running is idempotent', () {
      var now = DateTime(2026, 8, 6, 9);
      withClock(Clock(() => now), () {
        final c = ChoreographyClock();
        c.start();
        now = now.add(const Duration(seconds: 2));
        c.start();
        c.tick();
        expect(c.elapsed, const Duration(seconds: 2));
      });
    });

    test('reset rewinds to zero and keeps running state', () {
      var now = DateTime(2026, 8, 6, 9);
      withClock(Clock(() => now), () {
        final c = ChoreographyClock();
        c.start();
        now = now.add(const Duration(seconds: 3));
        c.tick();
        c.reset();
        expect(c.elapsed, Duration.zero);
        expect(c.isRunning, isTrue);
        now = now.add(const Duration(milliseconds: 100));
        c.tick();
        expect(c.elapsed, const Duration(milliseconds: 100));
      });
    });

    test('tick notifies listeners; tick while stopped does not', () {
      var now = DateTime(2026, 8, 6, 9);
      withClock(Clock(() => now), () {
        final c = ChoreographyClock();
        var notified = 0;
        c.addListener(() => notified++);
        c.tick();
        expect(notified, 0);
        c.start();
        now = now.add(const Duration(milliseconds: 16));
        c.tick();
        expect(notified, 1);
      });
    });
  });
}
