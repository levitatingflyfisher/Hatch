import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';

import '../../../core/storage/app_database.dart';

/// Serializes all Hatch user data to/from a JSON [Uint8List] for
/// encrypted backup via `sanctuary_backup_ui`.
///
/// One envelope carries EVERY profile with its engine snapshot and full
/// answer ledger (plus device settings) — a shared-device backup, not a
/// per-child one. Uses the fleet-standard [BackupEnvelope] shape
/// (`{app, schemaVersion, createdAt, payload}`); Hatch is new to the
/// feature, so there is no legacy wire shape to stay compatible with.
/// Works directly off the [AppDatabase] handle the caller passes in — the
/// app's `appDatabaseProvider` singleton, never a second connection.
class HatchBackupSerializer
    implements BackupSerializer, PreviewableBackupSerializer {
  final AppDatabase _db;

  const HatchBackupSerializer(this._db);

  static const _appId = 'hatch';

  /// DateTime columns are serialized as ISO-8601 UTC strings (not drift's
  /// epoch ints): the plaintext export is a document a household can read.
  static String _stamp(DateTime dt) => dt.toUtc().toIso8601String();

  @override
  Future<Uint8List> dumpAll() async {
    final profileRows = await _db.select(_db.profiles).get();
    final eventRows = await _db.select(_db.answerEvents).get();
    final snapshotRows = await _db.select(_db.engineSnapshots).get();
    final settingRows = await _db.select(_db.settings).get();

    return BackupEnvelope.wrap(
      appId: _appId,
      schemaVersion: _db.schemaVersion,
      createdAt: clock.now(),
      payload: {
        'profiles': [
          for (final r in profileRows)
            {
              'id': r.id,
              'name': r.name,
              'glyphSeed': r.glyphSeed,
              'paletteIndex': r.paletteIndex,
              'createdAt': _stamp(r.createdAt),
            },
        ],
        'engineSnapshots': [
          for (final r in snapshotRows)
            {
              'profileId': r.profileId,
              'json': r.json,
              'updatedAt': _stamp(r.updatedAt),
            },
        ],
        'answerEvents': [
          for (final r in eventRows)
            {
              'id': r.id,
              'profileId': r.profileId,
              'factA': r.factA,
              'factB': r.factB,
              'direction': r.direction,
              'kind': r.kind,
              'rung': r.rung,
              'correct': r.correct,
              'latencyMs': r.latencyMs,
              'production': r.production,
              'at': _stamp(r.at),
            },
        ],
        'settings': [
          for (final r in settingRows) {'key': r.key, 'value': r.value},
        ],
      },
    );
  }

  /// The dry-run parse behind preview-before-restore and export
  /// verify-by-read-back: validates exactly like [restoreAll] (wrong app,
  /// future schema, missing tables) and reports row counts — never writes.
  @override
  Future<BackupManifest> describeBackup(Uint8List plaintext) async {
    _requireProfiles(_unwrap(plaintext).payload);
    return BackupEnvelope.describe(plaintext);
  }

  /// The payload gate [restoreAll] applies — shared so describe and restore
  /// can never drift apart. Only `profiles` is required: the other tables
  /// may legitimately be empty lists, and an absent key reads as empty.
  static void _requireProfiles(Map<String, Object?> payload) {
    if (payload['profiles'] is! List) {
      throw const FormatException('Missing profiles in backup payload');
    }
  }

  /// Envelope validation via the shared fleet helper: a missing or wrong
  /// `app`, a missing `schemaVersion`, or a future schema all reject —
  /// defense in depth behind the AEAD context.
  UnwrappedBackup _unwrap(Uint8List data) => BackupEnvelope.unwrap(
    data,
    expectedAppId: _appId,
    currentSchemaVersion: _db.schemaVersion,
  );

  /// Restores all user data from bytes previously created by [dumpAll].
  ///
  /// **Destructive** — every profile, engine snapshot, answer event, and
  /// setting on this device is wiped and replaced. Runs in a single
  /// transaction: a bad row anywhere aborts the whole restore, leaving prior
  /// state untouched. Profile ids are preserved exactly — the ledger and
  /// snapshots reference them.
  @override
  Future<void> restoreAll(Uint8List data) async {
    final payload = _unwrap(data).payload;
    _requireProfiles(payload);

    await _db.transaction(() async {
      // Wipe in reverse FK order: children before profiles.
      await _db.delete(_db.answerEvents).go();
      await _db.delete(_db.engineSnapshots).go();
      await _db.delete(_db.settings).go();
      await _db.delete(_db.profiles).go();

      for (final row in _rows(payload, 'profiles')) {
        await _db
            .into(_db.profiles)
            .insert(
              ProfilesCompanion.insert(
                id: Value(row['id'] as int),
                name: Value(row['name'] as String? ?? ''),
                glyphSeed: row['glyphSeed'] as int,
                paletteIndex: Value(row['paletteIndex'] as int? ?? 0),
                createdAt: DateTime.parse(row['createdAt'] as String),
              ),
            );
      }

      for (final row in _rows(payload, 'engineSnapshots')) {
        await _db
            .into(_db.engineSnapshots)
            .insert(
              EngineSnapshotsCompanion.insert(
                profileId: Value(row['profileId'] as int),
                json: row['json'] as String,
                updatedAt: DateTime.parse(row['updatedAt'] as String),
              ),
            );
      }

      for (final row in _rows(payload, 'answerEvents')) {
        await _db
            .into(_db.answerEvents)
            .insert(
              AnswerEventsCompanion.insert(
                id: Value(row['id'] as int),
                profileId: row['profileId'] as int,
                factA: row['factA'] as int,
                factB: row['factB'] as int,
                direction: row['direction'] as int,
                kind: row['kind'] as int,
                rung: row['rung'] as int,
                correct: row['correct'] as bool,
                latencyMs: Value(row['latencyMs'] as int?),
                production: row['production'] as bool,
                at: DateTime.parse(row['at'] as String),
              ),
            );
      }

      for (final row in _rows(payload, 'settings')) {
        await _db
            .into(_db.settings)
            .insert(
              SettingsCompanion.insert(
                key: row['key'] as String,
                value: row['value'] as String,
              ),
            );
      }
    });
  }

  List<Map<String, dynamic>> _rows(Map<String, Object?> payload, String key) {
    final list = payload[key] as List<dynamic>?;
    if (list == null) return const [];
    return list.cast<Map<String, dynamic>>();
  }
}
