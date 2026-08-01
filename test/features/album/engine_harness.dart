// Shared harness for the album / habitats / parent feature tests: REAL
// engine, REAL EngineService, REAL Drift database in memory — no mocks, so
// the screens are tested against the states the engine actually produces.
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/core/engine/engine_providers.dart';
import 'package:hatch/core/engine/engine_service.dart';
import 'package:hatch/core/providers/core_providers.dart';
import 'package:hatch/core/storage/app_database.dart';
import 'package:mastery_core/mastery_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The fixed calendar the drives below start on.
final kDriveStart = DateTime(2026, 8, 7, 9);

Future<(ProviderContainer, int)> makeContainerWithProfile() async {
  SharedPreferences.setMockInitialValues(const {});
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase(NativeDatabase.memory());
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appDatabaseProvider.overrideWithValue(db),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(db.close);
  final profileId = await container.read(profilesDaoProvider).createProfile();
  return (container, profileId);
}

/// Answers every event of one piecing round correctly and fast, once per
/// calendar day for [days] days from [kDriveStart]. Under engine laws 1–3,
/// fast correct probes instantiate facts at bare and spaced confirmations
/// on distinct days hatch them — so a multi-day drive yields a real mix of
/// started, growing, and automatic facts for the screens to show.
Future<EngineService> driveEngine(
  ProviderContainer container,
  int profileId, {
  int days = 6,
}) async {
  // First read builds the provider and loads (or creates) the engine; pin
  // the clock so a fresh engine's birthday is the drive's first day, not the
  // machine's real date (date-dependent tests are a known fleet scar).
  final service = await withClock(
    Clock.fixed(kDriveStart),
    () => container.read(engineServiceProvider(profileId).future),
  );
  var day = kDriveStart;
  for (var i = 0; i < days; i++) {
    await withClock(Clock.fixed(day), () async {
      final round = service.assembleRound(RoundIntent.piecing);
      for (final spec in round.events) {
        await service.record(
          AnswerEvent(
            fact: spec.fact,
            direction: spec.direction,
            kind: spec.kind,
            rung: spec.rung,
            correct: true,
            latencyMs: 800,
            production: true,
            at: day,
          ),
        );
      }
    });
    day = day.add(const Duration(days: 1));
  }
  return service;
}
