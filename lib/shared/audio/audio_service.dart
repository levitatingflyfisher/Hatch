import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'sound_cue.dart';

/// One preloaded player slot; seam so the service logic is testable without
/// a real audio backend.
abstract class CuePlayer {
  Future<void> load(String assetPath);

  /// Restart from the beginning (low-latency retrigger).
  Future<void> play();

  Future<void> setVolume(double volume);

  Future<void> dispose();
}

/// The fleet audio laws, enforced structurally:
/// - never load-bearing: [play] is fire-and-forget and NEVER throws — a
///   missing file, a broken backend, a not-yet-preloaded cue all no-op;
/// - mute honored from cold start: the injected [isMuted] getter is read on
///   every play (this layer stays provider-free; features wire the settings
///   flag in);
/// - web autoplay: [unlockOnFirstGesture] primes the audio context inside
///   the first user gesture.
class AudioService {
  AudioService({
    required bool Function() isMuted,
    CuePlayer Function()? playerFactory,
  }) : _isMuted = isMuted,
       _playerFactory = playerFactory ?? _AudioplayersCuePlayer.new;

  final bool Function() _isMuted;
  final CuePlayer Function() _playerFactory;
  final Map<SoundCue, CuePlayer> _players = {};
  bool _unlocked = false;
  bool _disposed = false;

  /// Cues that loaded successfully.
  Set<SoundCue> get loadedCues => Set.unmodifiable(_players.keys);

  /// Whether every cue is currently a no-op. Public because "the app is
  /// silent" has exactly one cause worth asserting on, and silence is
  /// otherwise indistinguishable from working audio in a test.
  bool get muted {
    try {
      return _isMuted();
    } catch (_) {
      return true;
    }
  }

  /// Preloads every cue into a low-latency pool. Missing assets (e.g. cues
  /// whose files ship later) are tolerated: their slot just stays empty.
  Future<void> preload() async {
    for (final cue in SoundCue.values) {
      if (_disposed) return;
      if (_players.containsKey(cue)) continue;
      final player = _playerFactory();
      try {
        await player.load(cue.assetPath);
        if (_disposed) {
          unawaited(player.dispose().then((_) {}, onError: (_) {}));
          return;
        }
        _players[cue] = player;
      } catch (_) {
        unawaited(player.dispose().then((_) {}, onError: (_) {}));
      }
    }
  }

  /// Fire-and-forget playback. Never throws, never blocks, no-ops when
  /// muted or unloaded. Every cue has a visual twin, so silence is safe.
  void play(SoundCue cue) {
    if (_disposed) return;
    try {
      if (_isMuted()) return;
    } catch (_) {
      return;
    }
    final player = _players[cue];
    if (player == null) return;
    try {
      unawaited(player.play().then((_) {}, onError: (_) {}));
    } catch (_) {
      // Non-load-bearing by law.
    }
  }

  /// Call from the app's first pointer-down: primes the (web) audio context
  /// with a silent play so later cues are allowed to sound. Idempotent,
  /// never throws; safe to call on platforms that need no unlock. A gesture
  /// that arrives before any cue finished loading does NOT latch — the next
  /// gesture retries, so a fast first tap can't permanently skip the unlock.
  void unlockOnFirstGesture() {
    if (_unlocked || _disposed) return;
    final player = _players.values.isEmpty ? null : _players.values.first;
    if (player == null) return;
    _unlocked = true;
    unawaited(() async {
      try {
        await player.setVolume(0);
        await player.play();
        await player.setVolume(1);
      } catch (_) {
        // The gesture still resumed the context where it could.
      }
    }());
  }

  Future<void> dispose() async {
    _disposed = true;
    final players = [..._players.values];
    _players.clear();
    for (final p in players) {
      try {
        await p.dispose();
      } catch (_) {
        // Best-effort teardown.
      }
    }
  }
}

/// audioplayers-backed slot: one low-latency player per cue, stop+resume
/// retrigger.
class _AudioplayersCuePlayer implements CuePlayer {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> load(String assetPath) async {
    await _player.setPlayerMode(PlayerMode.lowLatency);
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setSource(AssetSource(assetPath));
  }

  @override
  Future<void> play() async {
    await _player.stop();
    await _player.resume();
  }

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> dispose() => _player.dispose();
}
