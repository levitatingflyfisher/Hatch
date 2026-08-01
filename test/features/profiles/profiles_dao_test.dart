import 'package:clock/clock.dart';
import 'package:hatch/core/storage/app_database.dart';
import 'package:hatch/features/profiles/data/profiles_dao.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ProfilesDao dao;

  final fixed = DateTime(2026, 8, 6, 9);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = ProfilesDao(db);
  });

  tearDown(() => db.close());

  Future<int> seedEventFor(int profileId) async {
    return db
        .into(db.answerEvents)
        .insert(
          AnswerEventsCompanion.insert(
            profileId: profileId,
            factA: 3,
            factB: 8,
            direction: 0,
            kind: 4, // EventKind.bee.index per the contract
            rung: 3,
            correct: true,
            latencyMs: const Value(1800),
            production: true,
            at: fixed,
          ),
        );
  }

  group('createProfile', () {
    test(
      'creates with empty name, a glyph seed, and clock-driven createdAt',
      () async {
        final id = await withClock(
          Clock.fixed(fixed),
          () => dao.createProfile(),
        );
        final rows = await dao.watchAll().first;

        expect(rows, hasLength(1));
        expect(rows.single.id, id);
        expect(rows.single.name, isEmpty);
        expect(rows.single.createdAt, fixed);
      },
    );

    test('rotates paletteIndex across successive profiles', () async {
      await dao.createProfile();
      await dao.createProfile();
      final rows = await dao.watchAll().first;
      expect(rows[0].paletteIndex, isNot(rows[1].paletteIndex));
    });

    test('distinct profiles get distinct glyph seeds', () async {
      await dao.createProfile();
      await dao.createProfile();
      final rows = await dao.watchAll().first;
      expect(rows[0].glyphSeed, isNot(rows[1].glyphSeed));
    });
  });

  group('rename', () {
    test('updates the name in place', () async {
      final id = await dao.createProfile();
      await dao.rename(id, 'Ada');
      final rows = await dao.watchAll().first;
      expect(rows.single.name, 'Ada');
    });
  });

  group('remove', () {
    test('deletes the profile and cascades its events and snapshot', () async {
      final id = await dao.createProfile();
      await seedEventFor(id);
      await db
          .into(db.engineSnapshots)
          .insert(
            EngineSnapshotsCompanion.insert(
              profileId: Value(id),
              json: '{"v":1}',
              updatedAt: fixed,
            ),
          );

      await dao.remove(id);

      expect(await dao.watchAll().first, isEmpty);
      expect(await db.select(db.answerEvents).get(), isEmpty);
      expect(await db.select(db.engineSnapshots).get(), isEmpty);
    });

    test('leaves other profiles untouched', () async {
      final keep = await dao.createProfile();
      final drop = await dao.createProfile();
      await seedEventFor(keep);
      await seedEventFor(drop);

      await dao.remove(drop);

      final rows = await dao.watchAll().first;
      expect(rows.single.id, keep);
      final events = await db.select(db.answerEvents).get();
      expect(events.single.profileId, keep);
    });
  });
}
