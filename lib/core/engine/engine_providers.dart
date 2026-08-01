import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../shared/audio/audio.dart';
import '../providers/core_providers.dart';
import 'engine_service.dart';

part 'engine_providers.g.dart';

/// One engine per profile, loaded from its snapshot. keepAlive so switching
/// screens mid-session doesn't reload the engine; profile switch changes the
/// family argument and naturally builds a fresh one.
@Riverpod(keepAlive: true)
Future<EngineService> engineService(Ref ref, int profileId) async {
  final service = EngineService(ref.watch(appDatabaseProvider), profileId);
  await service.load();
  ref.onDispose(service.dispose);
  return service;
}

/// The one AudioService. The mute flag is *listened* to, never read on demand:
/// soundMuted is an auto-dispose stream provider, and a bare `ref.read` from
/// here neither subscribes nor keeps it alive, so every cue rebuilt it, found
/// it still `AsyncLoading`, and fell through to the safe default — muted. The
/// app shipped completely silent and nothing failed, because silence is what
/// a broken audio path is supposed to look like. A subscription lives as long
/// as this (keepAlive) provider, so the flag lands once and stays.
///
/// Cold start still starts silent: until the database answers, a child who
/// muted the app must not be blasted on the next launch.
@Riverpod(keepAlive: true)
AudioService audioService(Ref ref) {
  var muted = true;
  ref.listen(soundMutedProvider, (_, next) {
    final value = next.valueOrNull;
    if (value != null) muted = value;
  }, fireImmediately: true);
  final service = AudioService(isMuted: () => muted);
  service.preload();
  ref.onDispose(service.dispose);
  return service;
}
