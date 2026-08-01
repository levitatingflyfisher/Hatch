import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/storage/app_database.dart';
import '../domain/habitat_layout.dart';

/// Persists each profile's habitat as one JSON value in the Settings table
/// (key `habitat.<profileId>`). The Settings table rides in the OHBK backup,
/// so the arrangement she made travels with the household's data — a shelf
/// worth keeping is a shelf worth backing up.
class HabitatStore {
  HabitatStore(this._db);

  final AppDatabase _db;

  static String keyFor(int profileId) => 'habitat.$profileId';

  Future<HabitatLayout> load(int profileId) async {
    final row = await (_db.select(
      _db.settings,
    )..where((t) => t.key.equals(keyFor(profileId)))).getSingleOrNull();
    if (row == null) return const HabitatLayout();
    try {
      return HabitatLayout.fromJson(
        jsonDecode(row.value) as Map<String, Object?>,
      );
    } on FormatException {
      // A corrupt value degrades to an empty meadow, silently: the habitat
      // is decoration and must never turn into an error screen.
      return const HabitatLayout();
    } on TypeError {
      return const HabitatLayout();
    }
  }

  Future<void> save(int profileId, HabitatLayout layout) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(
          key: keyFor(profileId),
          value: jsonEncode(layout.toJson()),
        ),
      );
}

final habitatStoreProvider = Provider<HabitatStore>(
  (ref) => HabitatStore(ref.watch(appDatabaseProvider)),
);
