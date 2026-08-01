import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/core/storage/app_database.dart';
import 'package:hatch/features/rush/data/rush_best_store.dart';

void main() {
  late AppDatabase db;
  late RushBestStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = RushBestStore(db);
  });

  tearDown(() => db.close());

  Future<void> putRaw(String key, String value) => db
      .into(db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion(key: Value(key), value: Value(value)),
      );

  test('a missing key reads as null — the first run races solo', () async {
    expect(await store.read(1), isNull);
  });

  test('write/read round-trips the cumulative list', () async {
    await store.write(1, [1200, 2500, 4100]);
    expect(await store.read(1), [1200, 2500, 4100]);
  });

  test('writing again overwrites the stored best', () async {
    await store.write(1, [2000, 4000]);
    await store.write(1, [1000, 1900]);
    expect(await store.read(1), [1000, 1900]);
  });

  test('one row per profile, whatever the round length — a best set over '
      'five eggs is the same ghost a sixteen-egg round races', () async {
    await store.write(1, [2000, 4000, 6000, 8000, 10000]);
    expect(await store.read(1), hasLength(5));
    // Nothing about the read depends on how long the NEXT round will be.
    expect(await store.read(2), isNull);
  });

  test('profiles are stored independently', () async {
    await store.write(1, [100]);
    await store.write(2, [300]);
    expect(await store.read(1), [100]);
    expect(await store.read(2), [300]);
  });

  test('a corrupt row reads as no ghost, never a crash', () async {
    await putRaw(RushBestStore.keyFor(1), 'not json at all');
    expect(await store.read(1), isNull);

    await putRaw(RushBestStore.keyFor(1), '{"nope": true}');
    expect(await store.read(1), isNull);
  });

  group('legacy per-count rows', () {
    // Pre-fix builds wrote rush.best.<profile>.<eventCount>. A child who
    // already set times keeps them rather than being told, one more time,
    // that this is her first rush.
    test('the quickest legacy run is adopted, chosen by pace not by total '
        'so a long row cannot lose to a short one', () async {
      // 4 eggs in 8 s — pace 2000/egg.
      await putRaw('rush.best.1.4', '[2000,4000,6000,8000]');
      // 12 eggs in 18 s — a much bigger total, but a quicker 1500/egg.
      await putRaw(
        'rush.best.1.12',
        '[1500,3000,4500,6000,7500,9000,10500,12000,13500,15000,16500,18000]',
      );
      expect(await store.read(1), hasLength(12));
    });

    test('a current row wins over any legacy row', () async {
      await putRaw('rush.best.1.4', '[100,200,300,400]');
      await store.write(1, [9000, 18000]);
      expect(await store.read(1), [9000, 18000]);
    });

    test('legacy rows belong to their own profile only', () async {
      await putRaw('rush.best.2.4', '[2000,4000,6000,8000]');
      expect(await store.read(1), isNull);
      expect(await store.read(2), hasLength(4));
    });

    test('corrupt or empty legacy rows are skipped, not crashed on', () async {
      await putRaw('rush.best.1.4', 'garbage');
      await putRaw('rush.best.1.6', '[]');
      await putRaw('rush.best.1.8', '[1000,2000]');
      expect(await store.read(1), [1000, 2000]);
    });
  });
}
