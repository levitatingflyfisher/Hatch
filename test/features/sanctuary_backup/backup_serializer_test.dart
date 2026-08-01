import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:hatch/core/storage/app_database.dart';
import 'package:hatch/features/sanctuary_backup/data/backup_serializer.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';

void main() {
  late AppDatabase db;
  late HatchBackupSerializer serializer;

  final fixed = DateTime.utc(2026, 8, 6, 9);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    serializer = HatchBackupSerializer(db);
  });

  tearDown(() => db.close());

  Future<int> seedProfile({String name = 'Ada'}) async {
    return db
        .into(db.profiles)
        .insert(
          ProfilesCompanion.insert(
            name: Value(name),
            glyphSeed: 42,
            paletteIndex: const Value(1),
            createdAt: fixed,
          ),
        );
  }

  Future<void> seedEvent(int profileId) async {
    await db
        .into(db.answerEvents)
        .insert(
          AnswerEventsCompanion.insert(
            profileId: profileId,
            factA: 3,
            factB: 8,
            direction: 1,
            kind: 4,
            rung: 3,
            correct: true,
            latencyMs: const Value(1750),
            production: true,
            at: fixed,
          ),
        );
  }

  Future<void> seedSnapshot(int profileId) async {
    await db
        .into(db.engineSnapshots)
        .insert(
          EngineSnapshotsCompanion.insert(
            profileId: Value(profileId),
            json: '{"version":1}',
            updatedAt: fixed,
          ),
        );
  }

  group('dumpAll', () {
    test(
      'wraps the fleet envelope: app id, schema version, createdAt',
      () async {
        final bytes = await withClock(
          Clock.fixed(fixed),
          () async => serializer.dumpAll(),
        );
        final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

        expect(json['app'], 'hatch');
        expect(json['schemaVersion'], 1);
        expect(json['createdAt'], fixed.toIso8601String());
        expect(json['payload'], isA<Map<String, dynamic>>());
      },
    );

    test(
      'payload carries every profile with its events and snapshot',
      () async {
        final id = await seedProfile();
        await seedEvent(id);
        await seedSnapshot(id);

        final bytes = await serializer.dumpAll();
        final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        final payload = json['payload'] as Map<String, dynamic>;

        expect(payload['profiles'], hasLength(1));
        expect(payload['answerEvents'], hasLength(1));
        expect(payload['engineSnapshots'], hasLength(1));

        final event =
            (payload['answerEvents'] as List).single as Map<String, dynamic>;
        expect(event['factA'], 3);
        expect(event['factB'], 8);
        expect(event['direction'], 1);
        expect(event['production'], true);
        expect(event['latencyMs'], 1750);
      },
    );
  });

  group('describeBackup', () {
    test('reports row counts without writing', () async {
      final id = await seedProfile();
      await seedEvent(id);

      final manifest = await serializer.describeBackup(
        await serializer.dumpAll(),
      );

      expect(manifest.appId, 'hatch');
      expect(manifest.schemaVersion, 1);
      expect(manifest.tableCounts['profiles'], 1);
      expect(manifest.tableCounts['answerEvents'], 1);
    });

    test('rejects a payload from a different app', () async {
      final foreign = BackupEnvelope.wrap(
        appId: 'furrow',
        schemaVersion: 1,
        createdAt: fixed,
        payload: const {'profiles': []},
      );
      expect(
        () => serializer.describeBackup(foreign),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a future schema version', () async {
      final future = BackupEnvelope.wrap(
        appId: 'hatch',
        schemaVersion: 99,
        createdAt: fixed,
        payload: const {'profiles': []},
      );
      expect(
        () => serializer.describeBackup(future),
        throwsA(isA<BackupSchemaException>()),
      );
    });
  });

  group('restoreAll', () {
    test('replaces local data with the backup contents', () async {
      final backedUpId = await seedProfile(name: 'Ada');
      await seedEvent(backedUpId);
      await seedSnapshot(backedUpId);
      final bytes = await serializer.dumpAll();

      // Mutate local state after the backup was taken.
      await db.delete(db.answerEvents).go();
      await db.delete(db.engineSnapshots).go();
      await db.delete(db.profiles).go();
      final strayId = await seedProfile(name: 'Stray');
      await seedEvent(strayId);

      await serializer.restoreAll(bytes);

      final profiles = await db.select(db.profiles).get();
      expect(profiles.single.name, 'Ada');
      expect(
        profiles.single.id,
        backedUpId,
        reason:
            'profile ids must survive the round trip — events and '
            'snapshots reference them',
      );
      final events = await db.select(db.answerEvents).get();
      expect(events.single.profileId, backedUpId);
      // Drift reads dateTime columns back in local time; compare instants.
      expect(events.single.at.toUtc(), fixed);
      final snapshots = await db.select(db.engineSnapshots).get();
      expect(snapshots.single.json, '{"version":1}');
    });

    test('round-trips the settings table', () async {
      await db
          .into(db.settings)
          .insert(SettingsCompanion.insert(key: 'sound_muted', value: '1'));
      final bytes = await serializer.dumpAll();
      await db.delete(db.settings).go();

      await serializer.restoreAll(bytes);

      final rows = await db.select(db.settings).get();
      expect(rows.single.key, 'sound_muted');
      expect(rows.single.value, '1');
    });

    test('rejects a wrong-app payload without touching local data', () async {
      await seedProfile(name: 'Keep');
      final foreign = BackupEnvelope.wrap(
        appId: 'furrow',
        schemaVersion: 1,
        createdAt: fixed,
        payload: const {'profiles': []},
      );

      await expectLater(
        serializer.restoreAll(foreign),
        throwsA(isA<FormatException>()),
      );
      final profiles = await db.select(db.profiles).get();
      expect(profiles.single.name, 'Keep');
    });

    test('a bad row aborts the whole restore transactionally', () async {
      await seedProfile(name: 'Keep');
      final malformed = BackupEnvelope.wrap(
        appId: 'hatch',
        schemaVersion: 1,
        createdAt: fixed,
        payload: {
          'profiles': [
            {
              'id': 1,
              'name': 'Ok',
              'glyphSeed': 1,
              'paletteIndex': 0,
              'createdAt': fixed.toIso8601String(),
            },
            {'id': 2, 'name': 'Broken'}, // missing required fields
          ],
        },
      );

      await expectLater(serializer.restoreAll(malformed), throwsA(anything));
      final profiles = await db.select(db.profiles).get();
      expect(
        profiles.single.name,
        'Keep',
        reason: 'a failed restore must leave prior state untouched',
      );
    });
  });
}
