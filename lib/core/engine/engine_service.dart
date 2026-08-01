import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:mastery_core/mastery_core.dart';

import '../storage/app_database.dart';

/// The seam between mastery_core and the app: one engine per profile, fed
/// AnswerEvents, persisted as (append-only ledger row + snapshot upsert) in a
/// single transaction so a kill mid-answer can never split them. The engine
/// stays pure — every 'now' here flows through package:clock so tests can
/// freeze the calendar (the spacing clock is calendar days, engine law 2).
class EngineService extends ChangeNotifier {
  EngineService(this._db, this.profileId);

  final AppDatabase _db;
  final int profileId;

  late MasteryEngine _engine;
  var _loaded = false;

  /// Direct engine access for read-only queries (samplerView, stats,
  /// familyStatus, nextVignette, pendingRequeues). Mutations must go through
  /// [record] / [completeVignette] or they will not be persisted.
  MasteryEngine get engine {
    assert(_loaded, 'EngineService.load() must complete before use');
    return _engine;
  }

  Future<void> load() async {
    final row = await (_db.select(
      _db.engineSnapshots,
    )..where((t) => t.profileId.equals(profileId))).getSingleOrNull();
    _engine = row == null
        ? MasteryEngine.fresh(now: clock.now())
        : MasteryEngine.fromSnapshot(
            jsonDecode(row.json) as Map<String, Object?>,
          );
    _loaded = true;
  }

  RoundSpec assembleRound(RoundIntent intent) =>
      engine.assembleRound(intent, now: clock.now());

  SamplerView samplerView() => engine.samplerView(now: clock.now());

  EngineStats stats() => engine.stats(now: clock.now());

  Future<RecordResult> record(AnswerEvent event) async {
    final result = engine.record(event);
    await _db.transaction(() async {
      await _db
          .into(_db.answerEvents)
          .insert(
            AnswerEventsCompanion.insert(
              profileId: profileId,
              factA: event.fact.a,
              factB: event.fact.b,
              direction: event.direction.index,
              kind: event.kind.index,
              rung: event.rung.index,
              correct: event.correct,
              latencyMs: Value(event.latencyMs),
              production: event.production,
              at: event.at,
            ),
          );
      await _persistSnapshot();
    });
    notifyListeners();
    return result;
  }

  Future<void> completeVignette(Family family) async {
    engine.markVignetteComplete(family, now: clock.now());
    await _persistSnapshot();
    notifyListeners();
  }

  Future<void> _persistSnapshot() => _db
      .into(_db.engineSnapshots)
      .insertOnConflictUpdate(
        EngineSnapshotsCompanion.insert(
          profileId: Value(profileId),
          json: jsonEncode(engine.snapshot()),
          updatedAt: clock.now(),
        ),
      );
}
