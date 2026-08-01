import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

/// Frame clock for choreographies. Time flows from `package:clock`, never
/// from a Ticker's own elapsed value, so tests step it with `withClock` and
/// explicit [tick] calls — no real ticker, no pumping.
///
/// Production wiring: a Ticker (from the owning widget's vsync) calls [tick]
/// once per frame; painters read [elapsed], which only changes on [tick] so
/// every layer paints one coherent instant per frame.
class ChoreographyClock extends ChangeNotifier {
  ChoreographyClock();

  DateTime? _base;
  Duration _elapsed = Duration.zero;

  bool get isRunning => _base != null;

  /// Elapsed as of the last [tick] (or [stop]); frame-coherent by design.
  Duration get elapsed => _elapsed;

  /// Starts (or resumes) from the current [elapsed]. Idempotent while running.
  void start() {
    _base ??= clock.now().subtract(_elapsed);
  }

  /// Freezes [elapsed] at the current instant.
  void stop() {
    final base = _base;
    if (base == null) return;
    _elapsed = clock.now().difference(base);
    _base = null;
  }

  /// Rewinds to zero; keeps running if running.
  void reset() {
    _elapsed = Duration.zero;
    if (_base != null) _base = clock.now();
    notifyListeners();
  }

  /// Advances [elapsed] to now and notifies. No-op when stopped.
  void tick() {
    final base = _base;
    if (base == null) return;
    _elapsed = clock.now().difference(base);
    notifyListeners();
  }
}
