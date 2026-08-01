import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/features/rush/domain/rush_ghost.dart';

void main() {
  test('interpolates whole hatches plus fractional progress to the next', () {
    final ghost = RushGhost([1000, 2000, 4000]);
    expect(ghost.progressAt(0), 0);
    expect(ghost.progressAt(-50), 0);
    // Halfway to the first hatch of three.
    expect(ghost.progressAt(500), closeTo(0.5 / 3, 1e-9));
    expect(ghost.progressAt(1000), closeTo(1 / 3, 1e-9));
    expect(ghost.progressAt(1500), closeTo(1.5 / 3, 1e-9));
    // Second hatch done, halfway through the long third gap.
    expect(ghost.progressAt(3000), closeTo(2.5 / 3, 1e-9));
    expect(ghost.progressAt(4000), 1);
    expect(ghost.progressAt(999999), 1);
  });

  test('totalMs is the finish time new runs must beat', () {
    expect(RushGhost([800, 1600]).totalMs, 1600);
    expect(RushGhost(const []).totalMs, 0);
  });

  test('pace is milliseconds per egg — the length-independent measure', () {
    expect(RushGhost([2000, 4000]).pace, 2000);
    expect(RushGhost([1500, 3000, 4500]).pace, 1500);
    expect(RushGhost(const []).pace, 0);
  });

  test('the ghost stretches to this round\'s length, so equal pace ties '
      'however many eggs are on the table', () {
    // Her best: four eggs, two seconds each.
    final ghost = RushGhost([2000, 4000, 6000, 8000]);

    // Racing an EIGHT-egg round, that pace needs sixteen seconds. At eight
    // seconds she should find the ghost exactly halfway, not already home.
    expect(ghost.progressAtFor(8000, 8), closeTo(0.5, 1e-9));
    expect(ghost.progressAtFor(16000, 8), 1);

    // Racing a SHORTER round it finishes sooner, for the same reason.
    expect(ghost.progressAtFor(4000, 2), 1);

    // Same length is the identity — the old behaviour, unchanged.
    expect(ghost.progressAtFor(4000, 4), closeTo(0.5, 1e-9));
    expect(ghost.progressAtFor(4000, 4), ghost.progressAt(4000));
  });

  test('a stretched ghost never crashes on degenerate input', () {
    expect(RushGhost(const []).progressAtFor(500, 8), 1);
    expect(RushGhost([1000]).progressAtFor(500, 0), 1);
    expect(RushGhost([1000]).progressAtFor(500, -3), 1);
  });

  test('degenerate stored runs never crash and never leave the track', () {
    // An empty run reads as already finished, not as a crash.
    expect(RushGhost(const []).progressAt(5), 1);
    // Two hatches on the same millisecond jump cleanly past both.
    final tied = RushGhost([1000, 1000]);
    expect(tied.progressAt(999), closeTo(0.999 / 2, 1e-9));
    expect(tied.progressAt(1000), 1);
  });
}
