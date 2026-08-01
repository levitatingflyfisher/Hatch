import 'dart:convert';

import 'package:drift/drift.dart' show StringExpressionOperators;

import '../../../core/storage/app_database.dart';

/// Best-run storage over the Drift `settings` table (the table, not
/// SharedPreferences, so a backup carries the ghosts with the household's
/// data — same law as the mute flag).
///
/// **One row per profile, not one per round length.** The first cut keyed on
/// `(profile, exact event count)` so that "the ghost only races runs of
/// comparable composition". But bee rounds randomize their size — the
/// assembler picks `beeMinEvents + seed % 7`, i.e. 10..16 eggs, re-rolled
/// every round — so two consecutive runs matched length only about one time
/// in seven. The rest read an empty slot, raced no ghost at all, and told the
/// child "your first rush is in the book!" again. She met that message three
/// times in a row before it was reported.
///
/// The fix is to stop treating length as part of the identity. A run's
/// comparable quantity is its *pace* (see [RushGhost.pace]), and pace holds
/// across lengths, so one stored curve serves every round she plays.
class RushBestStore {
  RushBestStore(this._db);

  final AppDatabase _db;

  static String keyFor(int profileId) => 'rush.best.$profileId';

  /// Rows written by pre-fix builds, keyed `rush.best.<profile>.<count>`.
  /// Read-only and never rewritten: a child who already set times keeps them
  /// instead of being told, one more time, that this is her first rush.
  static String legacyPrefix(int profileId) => 'rush.best.$profileId.';

  /// The stored best run as cumulative ms per hatched egg, or null when this
  /// profile has never finished a round (the first run races solo).
  Future<List<int>?> read(int profileId) async {
    final row = await (_db.select(
      _db.settings,
    )..where((t) => t.key.equals(keyFor(profileId)))).getSingleOrNull();
    final current = row == null ? null : _decode(row.value);
    if (current != null && current.isNotEmpty) return current;
    return _legacyBest(profileId);
  }

  Future<void> write(int profileId, List<int> cumulativeMs) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(
          key: keyFor(profileId),
          value: jsonEncode(cumulativeMs),
        ),
      );

  /// The quickest surviving legacy run, chosen by pace: those rows have
  /// differing lengths by construction, so a twelve-egg run must not lose to
  /// a four-egg one purely on total elapsed time.
  Future<List<int>?> _legacyBest(int profileId) async {
    final prefix = legacyPrefix(profileId);
    final rows = await (_db.select(
      _db.settings,
    )..where((t) => t.key.like('$prefix%'))).get();
    List<int>? best;
    for (final row in rows) {
      final run = _decode(row.value);
      if (run == null || run.isEmpty) continue;
      if (best == null || _pace(run) < _pace(best)) best = run;
    }
    return best;
  }

  static double _pace(List<int> run) => run.last / run.length;

  /// A corrupt row reads as no ghost — the rush must never crash over a stale
  /// record, and a missing ghost is a survivable state the app already has.
  static List<int>? _decode(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) return null;
      return decoded.map((e) => (e as num).toInt()).toList(growable: false);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}
