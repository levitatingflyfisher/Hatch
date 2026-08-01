import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/core/engine/engine_service.dart';
import 'package:hatch/core/storage/app_database.dart';
import 'package:hatch/features/rush/data/rush_best_store.dart';
import 'package:hatch/features/rush/domain/rush_copy.dart';
import 'package:hatch/features/rush/presentation/rush_controller.dart';
import 'package:hatch/shared/audio/sound_cue.dart';
import 'package:hatch/shared/painters/painters.dart';
import 'package:mastery_core/mastery_core.dart';

/// Eight facts probed fast+correct instantiate at bare (engine law 1) —
/// exactly the symbolic-ready pool a bee round draws from.
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

void main() {
  late AppDatabase db;
  late int profileId;
  late EngineService service;
  late RushBestStore store;
  late List<SoundCue> cues;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    profileId = await db
        .into(db.profiles)
        .insert(
          ProfilesCompanion.insert(glyphSeed: 7, createdAt: DateTime(2026, 8)),
        );
    service = EngineService(db, profileId);
    await service.load();
    store = RushBestStore(db);
    cues = [];
  });

  tearDown(() async {
    service.dispose();
    await db.close();
  });

  Future<void> seedBareFacts(DateTime at) async {
    for (final fact in _seedFacts) {
      await service.record(
        AnswerEvent(
          fact: fact,
          direction: AskDirection.forward,
          kind: EventKind.probe,
          rung: Rung.bare,
          correct: true,
          latencyMs: 900,
          production: true,
          at: at,
        ),
      );
    }
  }

  RushController makeController() =>
      RushController(engine: service, bestStore: store, playCue: cues.add);

  test(
    'a clean round hatches every egg, closes, and stores the first best',
    () async {
      var now = DateTime(2026, 8, 6, 9);
      await withClock(Clock(() => now), () async {
        await seedBareFacts(now);
        final controller = makeController();
        await controller.begin();

        expect(controller.phase, RushPhase.prompt);
        expect(controller.target, 8);
        expect(controller.ghost, isNull, reason: 'first run races solo');
        expect(controller.ghostProgress, isNull);
        expect(cues.first, SoundCue.rushStart);

        var guard = 0;
        while (controller.phase == RushPhase.prompt) {
          expect(++guard, lessThan(20), reason: 'round failed to close');
          now = now.add(const Duration(seconds: 2));
          await controller.submit(controller.current!.fact.product);
          expect(controller.phase, RushPhase.sweep);
          await controller.advance();
        }

        expect(controller.phase, RushPhase.done);
        expect(controller.outcome, RushOutcome.firstRush);
        expect(controller.hatched, 8);
        expect(controller.selfProgress, 1);
        expect(controller.cumulativeMs, hasLength(8));
        expect(controller.cumulativeMs.last, 16000);
        expect(service.engine.pendingRequeues, isEmpty);
        expect(await store.read(profileId), controller.cumulativeMs);
      });
    },
  );

  test('a miss teaches, requeues, and the round cannot close before '
      're-retrieval', () async {
    var now = DateTime(2026, 8, 6, 9);
    await withClock(Clock(() => now), () async {
      await seedBareFacts(now);
      final controller = makeController();
      await controller.begin();

      final missed = controller.current!.fact;
      now = now.add(const Duration(seconds: 2));
      await controller.submit(missed.product + 1);

      expect(controller.phase, RushPhase.teach);
      expect(controller.teach, isNotNull);
      expect(controller.teach!.answer, missed.product + 1);
      expect(controller.teach!.kind, ShortfallOverflowKind.overflow);
      expect(cues, contains(SoundCue.miss));
      expect(service.engine.pendingRequeues, contains(missed));
      await controller.advance();

      final askedAfterMiss = <Fact>[];
      var guard = 0;
      while (controller.phase == RushPhase.prompt) {
        expect(++guard, lessThan(20), reason: 'round failed to close');
        askedAfterMiss.add(controller.current!.fact);
        now = now.add(const Duration(seconds: 2));
        await controller.submit(controller.current!.fact.product);
        await controller.advance();
      }

      // Law-8 closure: the missed fact re-asked inside this round, the
      // obligation count never inflated, and no debt survives the round.
      expect(askedAfterMiss, contains(missed));
      expect(askedAfterMiss, hasLength(8));
      expect(controller.phase, RushPhase.done);
      expect(controller.hatched, 8);
      expect(controller.target, 8);
      expect(controller.cumulativeMs, hasLength(8));
      expect(service.engine.pendingRequeues, isEmpty);

      // Every answer was persisted through the service the moment it landed
      // (interruption safety): 8 seed probes + 9 round answers.
      final rows = await db.select(db.answerEvents).get();
      expect(rows, hasLength(17));
    });
  });

  test('slower runs keep the stored best and warm copy; quicker runs '
      'overwrite it', () async {
    var now = DateTime(2026, 8, 6, 9);
    await withClock(Clock(() => now), () async {
      await seedBareFacts(now);
      final controller = makeController();

      Future<void> run(Duration perEvent) async {
        var guard = 0;
        while (controller.phase == RushPhase.prompt) {
          expect(++guard, lessThan(20), reason: 'round failed to close');
          now = now.add(perEvent);
          await controller.submit(controller.current!.fact.product);
          await controller.advance();
        }
      }

      await controller.begin();
      await run(const Duration(seconds: 2));
      expect(controller.outcome, RushOutcome.firstRush);
      final firstBest = await store.read(profileId);
      expect(firstBest, isNotNull);

      // The freshly-set best immediately races the next round as the ghost.
      await controller.again();
      expect(controller.phase, RushPhase.prompt);
      expect(controller.ghost, isNotNull);
      expect(controller.ghost!.totalMs, firstBest!.last);
      expect(controller.ghostProgress, 0);

      // Slower run: warm outcome, stored best untouched.
      await run(const Duration(seconds: 5));
      expect(controller.outcome, RushOutcome.goodRush);
      expect(rushTallyCopy(controller.outcome!), 'A good rush!');
      expect(await store.read(profileId), firstBest);

      // Quicker run: celebrated and stored.
      await controller.again();
      await run(const Duration(milliseconds: 100));
      expect(controller.outcome, RushOutcome.personalBest);
      expect(rushTallyCopy(controller.outcome!), 'Your quickest rush yet!');
      expect(await store.read(profileId), controller.cumulativeMs);
      expect(controller.cumulativeMs.last, lessThan(firstBest.last));
    });
  });

  // The shipped bug: the ghost was stored one row per (profile, EXACT event
  // count), but bee rounds randomize their size (beeMinEvents + seed % 7,
  // i.e. 10..16). Two consecutive rounds matched length only ~1/7 of the
  // time; the rest read an empty slot, raced nothing, and greeted the child
  // with "your first rush is in the book!" — three times running, in the
  // playtest that found this. The fixture below is the shape the old tests
  // could not express, because they pinned every round to eight events.
  group('the ghost survives a change of round length', () {
    test('a best set over five eggs still races an eight-egg round', () async {
      var now = DateTime(2026, 8, 6, 9);
      await withClock(Clock(() => now), () async {
        await seedBareFacts(now);
        // Her previous run: five eggs, two seconds each.
        await store.write(profileId, [2000, 4000, 6000, 8000, 10000]);
        final controller = makeController();
        await controller.begin();

        expect(
          controller.target,
          isNot(5),
          reason: 'the fixture is pointless unless the lengths differ',
        );
        expect(
          controller.ghost,
          isNotNull,
          reason: 'a stored best must race whatever length comes up next',
        );
        expect(controller.ghostProgress, 0);

        var guard = 0;
        while (controller.phase == RushPhase.prompt) {
          expect(++guard, lessThan(20), reason: 'round failed to close');
          now = now.add(const Duration(seconds: 5));
          await controller.submit(controller.current!.fact.product);
          await controller.advance();
        }

        expect(
          controller.outcome,
          RushOutcome.goodRush,
          reason:
              '5 s/egg is slower than the stored 2 s/egg — but it is '
              'still not a FIRST rush',
        );
      });
    });

    test('personal best is decided on pace, so a longer round does not lose '
        'merely for being longer', () async {
      var now = DateTime(2026, 8, 6, 9);
      await withClock(Clock(() => now), () async {
        await seedBareFacts(now);
        // Four eggs in 8 s total — a pace of 2000 ms/egg.
        await store.write(profileId, [2000, 4000, 6000, 8000]);
        final controller = makeController();
        await controller.begin();
        expect(controller.target, 8);

        // Eight eggs at 1.5 s each: 12 s total. Slower on the wall clock than
        // the stored 8 s, quicker per egg. Comparing totals called this a
        // "good rush" and silently kept the worse run.
        var guard = 0;
        while (controller.phase == RushPhase.prompt) {
          expect(++guard, lessThan(20), reason: 'round failed to close');
          now = now.add(const Duration(milliseconds: 1500));
          await controller.submit(controller.current!.fact.product);
          await controller.advance();
        }

        expect(controller.cumulativeMs.last, 12000);
        expect(controller.outcome, RushOutcome.personalBest);
        expect(await store.read(profileId), controller.cumulativeMs);
      });
    });

    test('a pre-fix per-count row is adopted rather than discarded', () async {
      var now = DateTime(2026, 8, 6, 9);
      await withClock(Clock(() => now), () async {
        await seedBareFacts(now);
        // What a shipped 0.1.1 build left behind for this child.
        await db
            .into(db.settings)
            .insert(
              SettingsCompanion.insert(
                key: 'rush.best.$profileId.5',
                value: '[2000,4000,6000,8000,10000]',
              ),
            );
        final controller = makeController();
        await controller.begin();
        expect(
          controller.ghost,
          isNotNull,
          reason: 'times she already set are hers, not thrown away',
        );
      });
    });
  });

  test('ghost interpolation over a real stored run', () async {
    var now = DateTime(2026, 8, 6, 9);
    await withClock(Clock(() => now), () async {
      await seedBareFacts(now);
      final controller = makeController();
      await controller.begin();
      var guard = 0;
      while (controller.phase == RushPhase.prompt) {
        expect(++guard, lessThan(20), reason: 'round failed to close');
        now = now.add(const Duration(seconds: 2));
        await controller.submit(controller.current!.fact.product);
        await controller.advance();
      }

      await controller.again();
      // Best run hatched every 2 s; at 8 s the ghost sits exactly at 4/8.
      now = now.add(const Duration(seconds: 8));
      expect(controller.ghostProgress, closeTo(0.5, 1e-9));
      now = now.add(const Duration(seconds: 60));
      expect(controller.ghostProgress, 1);
    });
  });

  test('tally copy is never negative, for any outcome', () {
    const banned = [
      'slow',
      'not ',
      "didn't",
      'worse',
      'fail',
      'wrong',
      'miss',
      'lost',
      'behind',
      'try again',
    ];
    for (final outcome in RushOutcome.values) {
      final copy = rushTallyCopy(outcome);
      expect(copy, isNotEmpty);
      for (final word in banned) {
        expect(copy.toLowerCase(), isNot(contains(word)));
      }
    }
    expect(
      rushTallyCopy(RushOutcome.firstRush),
      'Your first rush is in the book!',
    );
    expect(rushTallyCopy(RushOutcome.personalBest), 'Your quickest rush yet!');
    expect(rushTallyCopy(RushOutcome.goodRush), 'A good rush!');
  });

  test(
    'a sparse engine yields the friendly empty state, no round, no cues',
    () async {
      final controller = makeController();
      await controller.begin();
      expect(controller.phase, RushPhase.empty);
      expect(controller.current, isNull);
      expect(cues, isEmpty, reason: 'no round started, no start cue');
    },
  );
}
