// lib/core/storage/app_database.dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

// ─── Tables ───────────────────────────────────────────────────────────────────

/// One hatcher on this device (up to 4). [name] may be empty — the picker
/// shows "Hatcher N" so creating a profile never requires typing.
/// [glyphSeed] drives the egg-avatar painter deterministically;
/// [paletteIndex] rotates the critter palette so siblings' eggs differ.
class Profiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withDefault(const Constant(''))();
  IntColumn get glyphSeed => integer()();
  IntColumn get paletteIndex => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
}

/// The append-only answer ledger. Columns mirror mastery_core's AnswerEvent
/// (MASTERY_CORE_CONTRACT.md) field-for-field so events round-trip losslessly
/// once the engine lands: (factA, factB) is the canonical folded fact
/// (a <= b), [direction] is AskDirection.index (0 forward / 1 reversed),
/// [kind] is EventKind.index, [rung] is Rung.index. [production] must be
/// preserved exactly — only production events may ever earn automaticity
/// credit (engine law). Row class is named AnswerEventRow so it can coexist
/// with mastery_core's AnswerEvent in one import scope.
@DataClassName('AnswerEventRow')
class AnswerEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer().references(Profiles, #id)();
  IntColumn get factA => integer()();
  IntColumn get factB => integer()();
  IntColumn get direction => integer()();
  IntColumn get kind => integer()();
  IntColumn get rung => integer()();
  BoolColumn get correct => boolean()();
  IntColumn get latencyMs => integer().nullable()();
  BoolColumn get production => boolean()();
  DateTimeColumn get at => dateTime()();
}

/// One MasteryEngine.snapshot() per profile, stored as its JSON encoding.
/// The engine is the source of truth for the shape; the app only persists
/// and round-trips it.
class EngineSnapshots extends Table {
  IntColumn get profileId => integer().references(Profiles, #id)();
  TextColumn get json => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {profileId};
}

/// Simple key→value store for device-wide preferences (sound mute etc.).
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// ─── Database ─────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [Profiles, AnswerEvents, EngineSnapshots, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'hatch',
              // Web needs to know where the sqlite3 WASM engine + drift worker
              // live (both shipped in web/); without this drift_flutter throws
              // "the `web` parameter needs to be set" at startup.
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ),
      );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // The ledger is read per-profile in event order (round assembly,
      // parent heatmap, 90-day pruning all scan this way).
      await customStatement(
        'CREATE INDEX IF NOT EXISTS ix_events_profile_at '
        'ON answer_events(profile_id, at)',
      );
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
