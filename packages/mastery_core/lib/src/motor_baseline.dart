import 'tuning.dart';

/// Rolling estimate of the child's motor (keypress) time, learned from her
/// own fastest reliable production answers — no calibration mini-game
/// (law 3). The fast threshold is recall budget + this baseline.
class MotorBaseline {
  MotorBaseline(this._tuning);

  final EngineTuning _tuning;

  /// Last N correct production latencies at symbolic rungs (labeled/bare).
  final List<int> samples = [];

  static const _capacity = 30;

  void addSample(int latencyMs) {
    samples.add(latencyMs);
    if (samples.length > _capacity) {
      samples.removeAt(0);
    }
  }

  /// Median of the 5 fastest samples: "fastest reliable" — a single fluke
  /// tap cannot set the baseline, slow deliberation cannot inflate it.
  int baselineMs() {
    if (samples.length < _tuning.motorMinSamples) {
      return _tuning.defaultMotorMs;
    }
    final sorted = [...samples]..sort();
    final fastest = sorted.take(5).toList();
    final median = fastest[fastest.length ~/ 2];
    return median.clamp(_tuning.motorClampMinMs, _tuning.motorClampMaxMs);
  }

  int fastThresholdMs() => (baselineMs() + _tuning.recallBudgetMs).clamp(
    _tuning.fastThresholdMinMs,
    _tuning.fastThresholdMaxMs,
  );

  Map<String, Object?> toMap() => {'samples': samples};

  void restore(Map<String, Object?> map) {
    samples
      ..clear()
      ..addAll(
        ((map['samples'] as List<Object?>?) ?? const []).map(
          (e) => (e as num).toInt(),
        ),
      );
  }
}
