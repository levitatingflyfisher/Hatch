import 'package:hatch/core/storage/app_database.dart';
import 'package:hatch/features/settings/data/settings_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = SettingsRepository(db);
  });

  tearDown(() => db.close());

  test('sound defaults to on (not muted)', () async {
    expect(await repo.watchSoundMuted().first, isFalse);
  });

  test('setSoundMuted persists and the watch stream emits it', () async {
    await repo.setSoundMuted(true);
    expect(await repo.watchSoundMuted().first, isTrue);

    await repo.setSoundMuted(false);
    expect(await repo.watchSoundMuted().first, isFalse);
  });

  test('mute survives a reopen of the same database', () async {
    await repo.setSoundMuted(true);
    // Same executor, fresh repository — the flag lives in the settings
    // table, not in memory.
    final again = SettingsRepository(db);
    expect(await again.watchSoundMuted().first, isTrue);
  });
}
