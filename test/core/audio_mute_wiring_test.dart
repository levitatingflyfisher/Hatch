import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/core/engine/engine_providers.dart';
import 'package:hatch/core/providers/core_providers.dart';
import 'package:hatch/core/storage/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The mute flag is the one thing standing between every cue and silence, and
/// its safe default is "silent" — so if the wiring that delivers the real
/// value from the database ever breaks, the app does not crash or warn. It
/// just plays nothing, forever, and looks fine. That is what shipped, and it
/// is why this file exists.
Future<(ProviderContainer, AppDatabase)> makeContainer() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase(NativeDatabase.memory());
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appDatabaseProvider.overrideWithValue(db),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(db.close);
  return (container, db);
}

void main() {
  test('sound is audible once the settings stream has answered', () async {
    final (container, _) = await makeContainer();
    final audio = container.read(audioServiceProvider);

    // The flag lives in the database, so it arrives a turn later. Nothing in
    // the app awaits it — cues just start firing — so the only requirement is
    // that it lands and *stays* landed.
    await pumpEventQueue();

    expect(
      audio.muted,
      isFalse,
      reason:
          'sound defaults to on; a muted service here means the real '
          'value never reached AudioService and every cue is a no-op',
    );
  });

  test('the flag stays landed across repeated reads', () async {
    final (container, _) = await makeContainer();
    final audio = container.read(audioServiceProvider);
    await pumpEventQueue();

    // Every play() re-checks. A subscription that lapses between cues reads
    // as "still loading", which falls back to muted — silent again.
    for (var i = 0; i < 5; i++) {
      expect(audio.muted, isFalse, reason: 'check $i');
      await pumpEventQueue();
    }
  });

  test('muting in settings silences the live service', () async {
    final (container, db) = await makeContainer();
    final audio = container.read(audioServiceProvider);
    await pumpEventQueue();
    expect(audio.muted, isFalse);

    await container.read(settingsRepositoryProvider).setSoundMuted(true);
    await pumpEventQueue();

    expect(audio.muted, isTrue);
  });

  test('mute is honored from cold start, before the database answers', () {
    // No pump: the stream has not emitted yet. Silence is the safe guess —
    // a child who muted the app must not be blasted on the next launch.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    expect(container.read(audioServiceProvider).muted, isTrue);
  });
}
