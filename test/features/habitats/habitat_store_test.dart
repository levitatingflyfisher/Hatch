import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/core/storage/app_database.dart';
import 'package:hatch/features/habitats/data/habitat_store.dart';
import 'package:hatch/features/habitats/domain/habitat_layout.dart';

void main() {
  late AppDatabase db;
  late HabitatStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = HabitatStore(db);
  });

  tearDown(() => db.close());

  test('round-trips a layout through the settings table', () async {
    const layout = HabitatLayout(
      biome: HabitatBiome.pond,
      slots: {0: '2x3', 5: '4x7', 8: '5x5'},
    );
    await store.save(7, layout);
    expect(await store.load(7), layout);
  });

  test(
    'stores under habitat.<profileId> so profiles never share a shelf',
    () async {
      await store.save(3, const HabitatLayout(biome: HabitatBiome.hill));
      final row = await (db.select(
        db.settings,
      )..where((t) => t.key.equals('habitat.3'))).getSingleOrNull();
      expect(row, isNotNull);
      // The other profile still gets the default empty meadow.
      expect(await store.load(4), const HabitatLayout());
    },
  );

  test(
    'a saved layout overwrites the previous one (no history, no growth)',
    () async {
      await store.save(1, const HabitatLayout(slots: {0: '2x3'}));
      await store.save(1, const HabitatLayout(slots: {1: '2x3'}));
      expect(await store.load(1), const HabitatLayout(slots: {1: '2x3'}));
      final rows = await db.select(db.settings).get();
      expect(rows, hasLength(1));
    },
  );

  test(
    'missing row and corrupt JSON both degrade to the default layout',
    () async {
      expect(await store.load(9), const HabitatLayout());

      await db
          .into(db.settings)
          .insertOnConflictUpdate(
            SettingsCompanion.insert(
              key: HabitatStore.keyFor(9),
              value: 'not json at all',
            ),
          );
      expect(await store.load(9), const HabitatLayout());

      // Valid JSON, wrong shape.
      await db
          .into(db.settings)
          .insertOnConflictUpdate(
            SettingsCompanion.insert(
              key: HabitatStore.keyFor(9),
              value: '[1, 2, 3]',
            ),
          );
      expect(await store.load(9), const HabitatLayout());
    },
  );

  group('HabitatLayout', () {
    test('fromJson tolerates unknown biomes and bad slots', () {
      final layout = HabitatLayout.fromJson(const {
        'v': 1,
        'biome': 'volcano',
        'slots': {
          '0': '2x3',
          'x': '4x4', // unparseable key: dropped
          '99': '5x5', // out of range: dropped
          '1': 7, // non-string critter: dropped
        },
      });
      expect(layout.biome, HabitatBiome.meadow);
      expect(layout.slots, {0: '2x3'});
    });

    test('place vacates the critter\'s previous slot', () {
      const start = HabitatLayout(slots: {2: '2x3'});
      final moved = start.place(6, '2x3');
      expect(moved.slots, {6: '2x3'});
    });

    test('place over an occupied slot replaces the occupant', () {
      const start = HabitatLayout(slots: {2: '2x3'});
      expect(start.place(2, '4x7').slots, {2: '4x7'});
    });

    test('clearSlot sends the occupant back to the roster', () {
      const start = HabitatLayout(slots: {2: '2x3', 3: '4x7'});
      expect(start.clearSlot(2).slots, {3: '4x7'});
    });
  });
}
