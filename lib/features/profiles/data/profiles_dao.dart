import 'dart:math';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../domain/egg_glyph.dart';

/// Data access for hatcher profiles. All timestamps flow through
/// `package:clock` so tests control them.
class ProfilesDao {
  final AppDatabase _db;

  ProfilesDao(this._db);

  static final _rng = Random();

  /// Profiles in creation order — the picker's stable grid order, and the
  /// order behind the "Hatcher N" default names.
  Stream<List<Profile>> watchAll() => (_db.select(
    _db.profiles,
  )..orderBy([(t) => OrderingTerm.asc(t.id)])).watch();

  /// Creates a profile with no typing required: [name] defaults to empty
  /// (rendered as "Hatcher N"), the glyph seed is rolled to be distinct from
  /// every existing profile's (the avatar IS the identity on the picker), and
  /// the palette start rotates so siblings' critters read differently.
  Future<int> createProfile({String name = ''}) async {
    final existing = await _db.select(_db.profiles).get();
    final usedSeeds = existing.map((p) => p.glyphSeed).toSet();
    var seed = _rng.nextInt(1 << 31);
    while (usedSeeds.contains(seed)) {
      seed = _rng.nextInt(1 << 31);
    }
    return _db
        .into(_db.profiles)
        .insert(
          ProfilesCompanion.insert(
            name: Value(name),
            glyphSeed: seed,
            paletteIndex: Value(existing.length % kCritterPaletteSize),
            createdAt: clock.now(),
          ),
        );
  }

  Future<void> rename(int id, String name) => (_db.update(
    _db.profiles,
  )..where((t) => t.id.equals(id))).write(ProfilesCompanion(name: Value(name)));

  /// Removes the profile AND everything that references it — its ledger and
  /// its engine snapshot — in one transaction. Destructive by design; the
  /// picker confirms before calling this.
  Future<void> remove(int id) => _db.transaction(() async {
    await (_db.delete(
      _db.answerEvents,
    )..where((t) => t.profileId.equals(id))).go();
    await (_db.delete(
      _db.engineSnapshots,
    )..where((t) => t.profileId.equals(id))).go();
    await (_db.delete(_db.profiles)..where((t) => t.id.equals(id))).go();
  });
}
