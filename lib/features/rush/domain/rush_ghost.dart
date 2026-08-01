/// The ghost caterpillar: the profile's best previous run, as cumulative
/// milliseconds at each hatched egg. The race is only ever against her own
/// past self (never a countdown, never public); elapsed time feeds this
/// interpolation and is NEVER displayed as a clock.
///
/// The stored run need not be the same length as the round being played —
/// bee rounds randomize their size — so the comparable quantity is [pace],
/// and [progressAtFor] stretches the curve onto whatever round is on the
/// table. See [RushBestStore] for why length is not part of a run's identity.
class RushGhost {
  RushGhost(List<int> cumulativeMs)
    : cumulativeMs = List.unmodifiable(cumulativeMs);

  /// Milliseconds from round start to each correct answer, in order.
  final List<int> cumulativeMs;

  /// The run's finish time.
  int get totalMs => cumulativeMs.isEmpty ? 0 : cumulativeMs.last;

  /// Milliseconds per egg — what one run being "quicker" than another
  /// actually means once rounds differ in length. A sixteen-egg round takes
  /// longer than a ten-egg one at identical speed, so totals cannot decide it.
  double get pace => cumulativeMs.isEmpty ? 0 : totalMs / cumulativeMs.length;

  /// Track position 0..1 at [elapsedMs]: whole eggs the ghost had hatched by
  /// then, plus linear progress toward its next hatch. Clamped, monotone in
  /// time for well-formed (non-decreasing) stored runs.
  double progressAt(int elapsedMs) {
    final n = cumulativeMs.length;
    if (n == 0) return 1;
    if (elapsedMs <= 0) return 0;
    var hatched = 0;
    while (hatched < n && cumulativeMs[hatched] <= elapsedMs) {
      hatched++;
    }
    if (hatched >= n) return 1;
    final prev = hatched == 0 ? 0 : cumulativeMs[hatched - 1];
    final next = cumulativeMs[hatched];
    final frac = next > prev
        ? ((elapsedMs - prev) / (next - prev)).clamp(0.0, 1.0)
        : 1.0;
    return ((hatched + frac) / n).clamp(0.0, 1.0);
  }

  /// Track position 0..1 at [elapsedMs] on a round of [events] eggs, matched
  /// on pace: the stored run is stretched (or compressed) onto this round's
  /// length, so the same speed ties whatever the lengths were. Racing raw
  /// [progressAt] instead would penalize the child for drawing a longer
  /// round — she would be "behind" a ghost she was in fact matching.
  double progressAtFor(int elapsedMs, int events) {
    if (cumulativeMs.isEmpty || events <= 0) return 1;
    final scale = events / cumulativeMs.length;
    return progressAt((elapsedMs / scale).round());
  }
}
