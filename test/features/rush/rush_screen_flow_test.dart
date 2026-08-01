import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/core/engine/engine_providers.dart';
import 'package:hatch/core/engine/engine_service.dart';
import 'package:hatch/core/providers/core_providers.dart';
import 'package:hatch/core/storage/app_database.dart';
import 'package:hatch/features/rush/data/rush_best_store.dart';
import 'package:hatch/features/rush/domain/rush_copy.dart';
import 'package:hatch/features/rush/presentation/rush_screen.dart';
import 'package:hatch/shared/answer/answer_input.dart';
import 'package:hatch/shared/audio/audio.dart';
import 'package:hatch/shared/critters/critters.dart';
import 'package:hatch/shared/painters/painters.dart';
import 'package:hatch/shared/theme/app_theme.dart';
import 'package:mastery_core/mastery_core.dart';

/// End-to-end rush over the real engine and in-memory database: prompts
/// answered through the numpad, a wrong answer raising the teach overlay
/// and re-asking before the round closes, the tally card, best persistence
/// and the instant restart. The race ticker never settles, so these tests
/// pump bounded durations — never pumpAndSettle.
class _FakeCuePlayer implements CuePlayer {
  @override
  Future<void> load(String assetPath) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {}
}

const _seedFacts = [
  Fact(2, 2),
  Fact(2, 3),
  Fact(2, 4),
  Fact(2, 5),
  Fact(2, 6),
  Fact(2, 7),
  Fact(2, 8),
  Fact(2, 9),
];

Future<(AppDatabase, int)> makeDb({required bool seeded}) async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final profileId = await db
      .into(db.profiles)
      .insert(
        ProfilesCompanion.insert(glyphSeed: 3, createdAt: DateTime(2026, 8)),
      );
  if (seeded) {
    // Fast+correct bare probes make eight symbolic-ready eggs (law 1) — the
    // pool the screen's own engine instance restores from its snapshot.
    final seeder = EngineService(db, profileId);
    await seeder.load();
    for (final fact in _seedFacts) {
      await seeder.record(
        AnswerEvent(
          fact: fact,
          direction: AskDirection.forward,
          kind: EventKind.probe,
          rung: Rung.bare,
          correct: true,
          latencyMs: 900,
          production: true,
          at: DateTime(2026, 8, 6, 9),
        ),
      );
    }
    seeder.dispose();
  }
  return (db, profileId);
}

Future<void> pumpRush(
  WidgetTester tester,
  AppDatabase db,
  int profileId,
) async {
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      audioServiceProvider.overrideWith(
        (ref) => AudioService(
          isMuted: () => true,
          playerFactory: _FakeCuePlayer.new,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        home: RushScreen(profileId: profileId),
      ),
    ),
  );
}

Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 60,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 60));
  }
  fail('never appeared: $finder');
}

Finder _trayFinder() =>
    find.byWidgetPredicate((w) => w is CustomPaint && w.painter is TrayPainter);

(int, int) currentTray(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(_trayFinder());
  final tray = paint.painter as TrayPainter;
  return (tray.a, tray.b);
}

Future<void> tapAnswer(WidgetTester tester, int answer) async {
  for (final digit in '$answer'.split('')) {
    await tester.tap(find.widgetWithText(InkWell, digit));
    await tester.pump(const Duration(milliseconds: 30));
  }
  await tester.tap(find.byIcon(Icons.check_rounded));
  await tester.pump(const Duration(milliseconds: 40));
}

void main() {
  testWidgets('a first rush says what the race is going to be', (tester) async {
    final (db, profileId) = await makeDb(seeded: true);
    await pumpRush(tester, db, profileId);
    await pumpUntil(tester, find.byType(HatchNumPad));

    // "What am I racing?" had no answer on screen. With nothing on record
    // the honest answer is: nothing yet, and here is why it matters.
    expect(
      find.text('First rush! The next one races this one.'),
      findsOneWidget,
    );
  });

  testWidgets('with a best on record, the screen names the shadow she is '
      'racing', (tester) async {
    final (db, profileId) = await makeDb(seeded: true);
    await RushBestStore(db).write(profileId, const [900, 1800, 2700, 3600]);
    await pumpRush(tester, db, profileId);
    await pumpUntil(tester, find.byType(HatchNumPad));

    expect(find.text('The shadow is your last rush.'), findsOneWidget);
  });

  testWidgets('a full rush: numpad answers, a teach moment with re-ask, the '
      'tally card, a persisted best and instant restart', (tester) async {
    final (db, profileId) = await makeDb(seeded: true);
    await pumpRush(tester, db, profileId);
    await pumpUntil(tester, find.byType(HatchNumPad));
    await pumpUntil(tester, _trayFinder());

    // Wrong answer first: the shortfall/overflow teach overlay must appear.
    final (missedA, missedB) = currentTray(tester);
    await tapAnswer(tester, missedA * missedB + 1);
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is ShortfallOverflowPainter,
      ),
      findsOneWidget,
    );
    // The compressed teach (~1.2 s) plays out, then the next prompt.
    await tester.pump(const Duration(milliseconds: 1300));
    await pumpUntil(tester, _trayFinder());

    // Answer every remaining prompt correctly. The missed tag must come
    // back around (law-8 re-retrieval) before the round is allowed to end.
    final seen = <(int, int)>[];
    var guard = 0;
    while (find.text('Again?').evaluate().isEmpty) {
      guard++;
      if (guard > 60) fail('round failed to close');
      if (_trayFinder().evaluate().isEmpty) {
        await tester.pump(const Duration(milliseconds: 120));
        continue;
      }
      final (a, b) = currentTray(tester);
      seen.add((a, b));
      await tapAnswer(tester, a * b);
      await tester.pump(const Duration(milliseconds: 700));
    }
    expect(seen, contains((missedA, missedB)));

    // Tally: first-run copy (warm, no numbers, no clock), big restart tile.
    expect(find.text('Your first rush is in the book!'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    // The best run persisted as cumulative ms under the profile's one
    // rush.best key — no event count in it, so the next round races this
    // ghost whatever length it draws.
    final rows = await db.select(db.settings).get();
    final best = rows.where((r) => r.key == RushBestStore.keyFor(profileId));
    expect(best, hasLength(1));
    final stored = jsonDecode(best.single.value) as List<dynamic>;
    expect(stored, hasLength(8));

    // "Again?" restarts instantly into a fresh round.
    await tester.tap(find.text('Again?'));
    await pumpUntil(tester, _trayFinder());
    expect(find.byType(HatchNumPad), findsOneWidget);
  });

  testWidgets('with too few hatchable eggs the screen shows the friendly '
      'nursery state', (tester) async {
    final (db, profileId) = await makeDb(seeded: false);
    await pumpRush(tester, db, profileId);
    await pumpUntil(tester, find.text(rushEmptyCopy));

    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is CritterPainter,
      ),
      findsOneWidget,
    );
    expect(find.byType(HatchNumPad), findsNothing);
    expect(find.text('Done'), findsOneWidget);
  });
}
