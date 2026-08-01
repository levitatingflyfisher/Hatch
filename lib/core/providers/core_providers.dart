// lib/core/providers/core_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/profiles/data/profiles_dao.dart';
import '../../features/settings/data/settings_repository.dart';
import '../storage/app_database.dart';

part 'core_providers.g.dart';

// Seeded from main() before ProviderScope.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(),
);

@riverpod
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}

@riverpod
ProfilesDao profilesDao(Ref ref) => ProfilesDao(ref.watch(appDatabaseProvider));

/// All profiles in creation order — the picker grid and the "Hatcher N"
/// default-name numbering.
@riverpod
Stream<List<Profile>> profiles(Ref ref) =>
    ref.watch(profilesDaoProvider).watchAll();

@riverpod
SettingsRepository settingsRepository(Ref ref) =>
    SettingsRepository(ref.watch(appDatabaseProvider));

/// Whether sound is muted. Every audio cue checks this; it must be honored
/// from cold start, so it lives in the database, not in-memory state.
@riverpod
Stream<bool> soundMuted(Ref ref) =>
    ref.watch(settingsRepositoryProvider).watchSoundMuted();
