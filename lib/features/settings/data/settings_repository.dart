import '../../../core/storage/app_database.dart';

/// Key→value settings over the Drift `settings` table. The table (not
/// SharedPreferences) holds anything a backup should carry — the mute flag
/// travels with the household's data.
class SettingsRepository {
  final AppDatabase _db;

  SettingsRepository(this._db);

  static const _soundMutedKey = 'sound_muted';

  /// Sound defaults to ON; a missing row reads as not muted.
  Stream<bool> watchSoundMuted() =>
      (_db.select(_db.settings)..where((t) => t.key.equals(_soundMutedKey)))
          .watchSingleOrNull()
          .map((row) => row?.value == '1');

  Future<void> setSoundMuted(bool muted) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(key: _soundMutedKey, value: muted ? '1' : '0'),
      );
}
