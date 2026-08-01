import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/shared/audio/audio.dart';

class FakeCuePlayer implements CuePlayer {
  FakeCuePlayer({
    this.failLoad = false,
    this.throwOnPlaySync = false,
    this.failPlayAsync = false,
  });

  final bool failLoad;
  final bool throwOnPlaySync;
  final bool failPlayAsync;

  String? loadedPath;
  int playCount = 0;
  final List<double> volumes = [];
  bool disposed = false;

  @override
  Future<void> load(String assetPath) async {
    if (failLoad) throw StateError('missing asset: $assetPath');
    loadedPath = assetPath;
  }

  @override
  Future<void> play() {
    if (throwOnPlaySync) throw StateError('backend gone');
    playCount++;
    if (failPlayAsync) return Future.error(StateError('async play failure'));
    return Future.value();
  }

  @override
  Future<void> setVolume(double volume) async {
    volumes.add(volume);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  group('SoundCue', () {
    test('every shipped audio asset is referenced by exactly one cue', () {
      final dir = Directory('assets/audio');
      final shipped = dir
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((name) => name.endsWith('.ogg'))
          .toSet();
      final referenced = SoundCue.values.map((c) => c.fileName).toSet();
      expect(
        referenced.length,
        SoundCue.values.length,
        reason: 'cue file names must be unique',
      );
      for (final file in shipped) {
        expect(
          referenced,
          contains(file),
          reason: '$file shipped but no cue references it',
        );
      }
    });

    test('asset paths sit under audio/', () {
      for (final cue in SoundCue.values) {
        expect(cue.assetPath, 'audio/${cue.fileName}');
      }
    });
  });

  group('AudioService', () {
    test('preload fills a slot per cue and tolerates missing files', () async {
      final players = <FakeCuePlayer>[];
      var calls = 0;
      final service = AudioService(
        isMuted: () => false,
        // Every third cue's asset is "missing".
        playerFactory: () {
          final p = FakeCuePlayer(failLoad: calls++ % 3 == 2);
          players.add(p);
          return p;
        },
      );
      await service.preload();
      expect(players.length, SoundCue.values.length);
      final loaded = players.where((p) => p.loadedPath != null).length;
      expect(loaded, lessThan(SoundCue.values.length));
      expect(service.loadedCues.length, loaded);
      // Failed slots were disposed, loaded ones kept.
      for (final p in players.where((p) => p.loadedPath == null)) {
        expect(p.disposed, isTrue);
      }
    });

    test('play is a no-op when muted, live when unmuted', () async {
      var muted = true;
      final players = <FakeCuePlayer>[];
      final service = AudioService(
        isMuted: () => muted,
        playerFactory: () {
          final p = FakeCuePlayer();
          players.add(p);
          return p;
        },
      );
      await service.preload();
      service.play(SoundCue.plink);
      expect(players.every((p) => p.playCount == 0), isTrue);
      muted = false;
      service.play(SoundCue.plink);
      expect(players.map((p) => p.playCount).reduce((a, b) => a + b), 1);
    });

    test('play before preload never throws', () {
      final service = AudioService(
        isMuted: () => false,
        playerFactory: FakeCuePlayer.new,
      );
      expect(() => service.play(SoundCue.miss), returnsNormally);
    });

    test('play never throws on sync or async backend failure', () async {
      final service = AudioService(
        isMuted: () => false,
        playerFactory: () =>
            FakeCuePlayer(throwOnPlaySync: true, failPlayAsync: true),
      );
      await service.preload();
      expect(() => service.play(SoundCue.snap), returnsNormally);
      // Let any mishandled async error surface as a test failure.
      await Future<void>.delayed(Duration.zero);
    });

    test('play of an unloaded cue is a silent no-op', () async {
      var calls = 0;
      final service = AudioService(
        isMuted: () => false,
        // Only the first cue loads.
        playerFactory: () => FakeCuePlayer(failLoad: calls++ > 0),
      );
      await service.preload();
      final unloaded = SoundCue.values.firstWhere(
        (c) => !service.loadedCues.contains(c),
      );
      expect(() => service.play(unloaded), returnsNormally);
    });

    test('a throwing mute getter fails silent, not loud', () async {
      final service = AudioService(
        isMuted: () => throw StateError('settings not ready'),
        playerFactory: FakeCuePlayer.new,
      );
      await service.preload();
      expect(() => service.play(SoundCue.plink), returnsNormally);
    });

    test('unlockOnFirstGesture primes silently exactly once', () async {
      final players = <FakeCuePlayer>[];
      final service = AudioService(
        isMuted: () => false,
        playerFactory: () {
          final p = FakeCuePlayer();
          players.add(p);
          return p;
        },
      );
      await service.preload();
      service.unlockOnFirstGesture();
      service.unlockOnFirstGesture();
      await Future<void>.delayed(Duration.zero);
      final primed = players.where((p) => p.playCount > 0).toList();
      expect(primed.length, 1);
      expect(primed.single.volumes, [0, 1]);
      expect(primed.single.playCount, 1);
    });

    test(
      'unlock before preload is safe and retries on a later gesture',
      () async {
        final players = <FakeCuePlayer>[];
        final service = AudioService(
          isMuted: () => false,
          playerFactory: () {
            final p = FakeCuePlayer();
            players.add(p);
            return p;
          },
        );
        // A tap that lands before any cue loaded must not latch the unlock.
        expect(service.unlockOnFirstGesture, returnsNormally);
        await service.preload();
        service.unlockOnFirstGesture();
        await Future<void>.delayed(Duration.zero);
        expect(players.where((p) => p.playCount > 0).length, 1);
      },
    );

    test('dispose tears down every player and silences later plays', () async {
      final players = <FakeCuePlayer>[];
      final service = AudioService(
        isMuted: () => false,
        playerFactory: () {
          final p = FakeCuePlayer();
          players.add(p);
          return p;
        },
      );
      await service.preload();
      await service.dispose();
      expect(players.every((p) => p.disposed), isTrue);
      expect(() => service.play(SoundCue.plink), returnsNormally);
      expect(players.every((p) => p.playCount == 0), isTrue);
    });
  });
}
