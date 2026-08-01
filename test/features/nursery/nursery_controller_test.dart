import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/core/engine/engine_service.dart';
import 'package:hatch/core/storage/app_database.dart';
import 'package:hatch/features/nursery/domain/nursery_controller.dart';
import 'package:hatch/shared/audio/sound_cue.dart';
import 'package:hatch/shared/painters/shortfall_overflow.dart';
import 'package:mastery_core/mastery_core.dart';

/// Wall-clock stand-in: every now() steps one second (so identical answers
/// can never collide on the engine's per-event dedupe key) and tests can
/// jump the calendar between rounds (the spacing clock is calendar days).
class SteppingClock {
  SteppingClock(this._base);

  DateTime _base;
  int _ticks = 0;

  DateTime now() => _base.add(Duration(seconds: ++_ticks));

  void addDays(int days) => _base = _base.add(Duration(days: days));
}

typedef Booted = ({
  NurseryController controller,
  EngineService service,
  List<SoundCue> cues,
});

Future<Booted> boot(AppDatabase db) async {
  final profileId = await db
      .into(db.profiles)
      .insert(ProfilesCompanion.insert(glyphSeed: 3, createdAt: clock.now()));
  final service = EngineService(db, profileId);
  await service.load();
  final cues = <SoundCue>[];
  return (
    controller: NurseryController(service, playCue: cues.add),
    service: service,
    cues: cues,
  );
}

/// Drives the state machine to the done tile. Returns true when a hatch
/// moment played. [answerFor] picks each answer (defaults to correct);
/// [onCelebrating] fires the moment the round completes.
Future<bool> driveToDone(
  Booted booted, {
  int Function(RoundEventSpec spec)? answerFor,
  void Function()? onCelebrating,
  int maxSteps = 600,
}) async {
  final controller = booted.controller;
  var sawHatching = false;
  var steps = 0;
  while (controller.phase != NurseryPhase.done && steps++ < maxSteps) {
    switch (controller.phase) {
      case NurseryPhase.vignette:
        await controller.vignetteFinished();
      case NurseryPhase.building:
        controller.constructionComplete();
      case NurseryPhase.answering:
        final spec = controller.current!;
        controller.answerKeyPressed();
        await controller.submitAnswer(
          answerFor?.call(spec) ?? spec.fact.product,
          production: !controller.isChoice(spec),
        );
      case NurseryPhase.feedbackCorrect:
      case NurseryPhase.feedbackMiss:
        controller.feedbackDone();
      case NurseryPhase.strategyOffer:
        controller.chooseStrategy(controller.strategyOffer!.offered);
      case NurseryPhase.strategyPlaying:
        controller.strategyPlayed();
      case NurseryPhase.celebrating:
        onCelebrating?.call();
        controller.celebrationDone();
      case NurseryPhase.hatching:
        sawHatching = true;
        controller.advanceHatch();
      case NurseryPhase.idle:
      case NurseryPhase.done:
        break;
    }
  }
  expect(steps, lessThan(maxSteps), reason: 'round never reached done');
  return sawHatching;
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('fresh engine: the due vignette plays first, then three forced '
      'practices lead the round', () async {
    final stepper = SteppingClock(DateTime(2026, 8, 10, 9));
    await withClock(Clock(stepper.now), () async {
      final booted = await boot(db);
      final controller = booted.controller;

      controller.startRound();
      expect(controller.phase, NurseryPhase.vignette);
      expect(controller.vignette!.family, Family.x2);
      expect(controller.events, isEmpty);

      await controller.vignetteFinished();
      expect(booted.cues, contains(SoundCue.chime));
      expect(booted.service.engine.familyStatus(Family.x2), FamilyStatus.open);
      expect(controller.events.length, greaterThan(3));
      for (final spec in controller.events.take(3)) {
        expect(spec.kind, EventKind.vignettePractice);
        expect(spec.fact.a, greaterThan(0));
      }
      // Practices are constructs: the toy comes before the answer step.
      expect(controller.phase, NurseryPhase.building);
    });
  });

  test('an interrupted vignette replays: completion is only recorded when '
      'the child finishes it', () async {
    final stepper = SteppingClock(DateTime(2026, 8, 10, 9));
    await withClock(Clock(stepper.now), () async {
      final booted = await boot(db);
      booted.controller.startRound();
      expect(booted.controller.phase, NurseryPhase.vignette);

      // Abandon mid-vignette (screen closed): nothing was recorded, so a
      // fresh round starts with the same vignette.
      booted.controller.startRound();
      expect(booted.controller.phase, NurseryPhase.vignette);
      expect(booted.controller.vignette!.family, Family.x2);
      expect(
        booted.service.engine.familyStatus(Family.x2),
        FamilyStatus.vignetteDue,
      );
    });
  });

  test(
    'correct production answer: settle cue, sweep feedback, advance',
    () async {
      final stepper = SteppingClock(DateTime(2026, 8, 10, 9));
      await withClock(Clock(stepper.now), () async {
        final booted = await boot(db);
        final controller = booted.controller;
        controller.startRound();
        await controller.vignetteFinished();

        controller.constructionComplete();
        expect(controller.phase, NurseryPhase.answering);
        final spec = controller.current!;
        controller.answerKeyPressed();
        await controller.submitAnswer(spec.fact.product, production: true);

        expect(controller.phase, NurseryPhase.feedbackCorrect);
        expect(booted.cues, contains(SoundCue.settle));
        controller.feedbackDone();
        expect(controller.eventIndex, 1);
        expect(controller.phase, NurseryPhase.building);
      });
    },
  );

  test('wrong answer: shortfall/overflow feedback, kind cue, requeue; the '
      're-ask returns before the round completes', () async {
    final stepper = SteppingClock(DateTime(2026, 8, 10, 9));
    await withClock(Clock(stepper.now), () async {
      final booted = await boot(db);
      final controller = booted.controller;
      controller.startRound();
      await controller.vignetteFinished();

      final target = controller.current!.fact;
      controller.constructionComplete();
      controller.answerKeyPressed();
      await controller.submitAnswer(target.product + 1, production: true);

      expect(controller.phase, NurseryPhase.feedbackMiss);
      expect(booted.cues, contains(SoundCue.miss));
      expect(booted.cues, isNot(contains(SoundCue.settle)));
      final shortfall = controller.shortfall!;
      expect(shortfall.kind, ShortfallOverflowKind.overflow);
      expect(shortfall.answer, target.product + 1);
      expect(booted.service.engine.pendingRequeues, contains(target));

      // The miss moves on — no reveal-then-move-on — and the re-ask comes
      // back later in the round.
      controller.feedbackDone();
      expect(controller.phase, NurseryPhase.building);

      var reAsks = 0;
      await driveToDone(
        booted,
        answerFor: (spec) {
          if (spec.fact == target && controller.eventIndex > 0) reAsks++;
          return spec.fact.product;
        },
        onCelebrating: () =>
            expect(booted.service.engine.pendingRequeues, isEmpty),
      );
      expect(reAsks, greaterThanOrEqualTo(1));
      expect(booted.cues, contains(SoundCue.trayDone));
    });
  });

  test('third consecutive miss: strategy switch offered, chosen route plays, '
      'the remediation re-ask closes the debt', () async {
    final stepper = SteppingClock(DateTime(2026, 8, 10, 9));
    await withClock(Clock(stepper.now), () async {
      final booted = await boot(db);
      final controller = booted.controller;
      controller.startRound();
      await controller.vignetteFinished();
      final target = controller.current!.fact;
      final initialLength = controller.events.length;

      var misses = 0;
      var steps = 0;
      while (controller.phase != NurseryPhase.strategyOffer && steps++ < 400) {
        switch (controller.phase) {
          case NurseryPhase.building:
            controller.constructionComplete();
          case NurseryPhase.answering:
            final spec = controller.current!;
            controller.answerKeyPressed();
            final wrong = spec.fact == target;
            if (wrong) misses++;
            await controller.submitAnswer(
              wrong ? spec.fact.product + 1 : spec.fact.product,
              production: !controller.isChoice(spec),
            );
          case NurseryPhase.feedbackCorrect:
          case NurseryPhase.feedbackMiss:
            controller.feedbackDone();
          default:
            fail('unexpected phase ${controller.phase}');
        }
      }
      expect(controller.phase, NurseryPhase.strategyOffer);
      expect(misses, 3);
      // Three asks can't all fit in one assembly: the round grew a requeue
      // continuation rather than completing with the debt open (law 8).
      expect(controller.events.length, greaterThan(initialLength));
      final offer = controller.strategyOffer!;
      expect(offer.fact, target);

      controller.chooseStrategy(offer.offered);
      expect(controller.phase, NurseryPhase.strategyPlaying);
      expect(controller.playingRoute, offer.offered);

      controller.strategyPlayed();
      expect(controller.phase, NurseryPhase.answering);
      final reAsk = controller.current!;
      expect(reAsk.kind, EventKind.remediation);
      expect(reAsk.fact, target);
      expect(reAsk.rung, Rung.labeled);

      controller.answerKeyPressed();
      await controller.submitAnswer(target.product, production: true);
      expect(controller.phase, NurseryPhase.feedbackCorrect);
      expect(booted.service.engine.pendingRequeues, isNot(contains(target)));
      controller.feedbackDone();

      await driveToDone(
        booted,
        onCelebrating: () =>
            expect(booted.service.engine.pendingRequeues, isEmpty),
      );
    });
  });

  test('the show-me reveal is free and still ends in a re-ask', () async {
    final stepper = SteppingClock(DateTime(2026, 8, 10, 9));
    await withClock(Clock(stepper.now), () async {
      final booted = await boot(db);
      final controller = booted.controller;
      controller.startRound();
      await controller.vignetteFinished();
      final target = controller.current!.fact;

      var steps = 0;
      while (controller.phase != NurseryPhase.strategyOffer && steps++ < 400) {
        switch (controller.phase) {
          case NurseryPhase.building:
            controller.constructionComplete();
          case NurseryPhase.answering:
            final spec = controller.current!;
            controller.answerKeyPressed();
            await controller.submitAnswer(
              spec.fact == target ? spec.fact.product + 2 : spec.fact.product,
              production: !controller.isChoice(spec),
            );
          case NurseryPhase.feedbackCorrect:
          case NurseryPhase.feedbackMiss:
            controller.feedbackDone();
          default:
            fail('unexpected phase ${controller.phase}');
        }
      }
      controller.chooseShowMe();
      expect(controller.phase, NurseryPhase.strategyPlaying);
      expect(controller.showMeReveal, isTrue);
      expect(controller.playingRoute, isNull);

      controller.strategyPlayed();
      expect(controller.current!.kind, EventKind.remediation);
      expect(controller.current!.fact, target);
    });
  });

  test(
    'factFired queues the hatch; celebration walks the queue to done',
    () async {
      final stepper = SteppingClock(DateTime(2026, 8, 10, 9));
      await withClock(Clock(stepper.now), () async {
        final booted = await boot(db);
        final service = booted.service;
        final controller = booted.controller;
        const fact = Fact(2, 3);

        AnswerEvent seedEvent(EventKind kind) => AnswerEvent(
          fact: fact,
          direction: AskDirection.forward,
          kind: kind,
          rung: Rung.bare,
          correct: true,
          latencyMs: 700,
          production: true,
          at: clock.now(),
        );

        // Day 1: a fast probe instantiates at bare. Day 2: a fast due review.
        // Two distinct automatic days banked; the third fires the fact.
        await service.record(seedEvent(EventKind.probe));
        stepper.addDays(1);
        await service.record(seedEvent(EventKind.review));
        stepper.addDays(4);

        var sawHatch = false;
        for (var round = 0; round < 15 && !sawHatch; round++) {
          controller.startRound();
          sawHatch = await driveToDone(booted);
          if (round % 3 == 2) stepper.addDays(1);
        }
        expect(sawHatch, isTrue);
        expect(controller.hatchQueue, contains(fact));
        expect(controller.phase, NurseryPhase.done);
      });
    },
  );

  test(
    'choice options are a seeded shuffle of distractors + the product',
    () async {
      final stepper = SteppingClock(DateTime(2026, 8, 10, 9));
      await withClock(Clock(stepper.now), () async {
        final booted = await boot(db);
        final controller = booted.controller;
        controller.startRound();
        await controller.vignetteFinished();
        final spec = controller.events.firstWhere(
          (s) => s.choiceDistractors.length == 2,
        );
        final options = controller.choiceOptions(spec);
        expect(options, hasLength(3));
        expect(options, contains(spec.fact.product));
        expect(options.toSet(), {...spec.choiceDistractors, spec.fact.product});
        expect(controller.choiceOptions(spec), options);
      });
    },
  );

  test('displayFactors respects the asked direction', () async {
    final stepper = SteppingClock(DateTime(2026, 8, 10, 9));
    await withClock(Clock(stepper.now), () async {
      final booted = await boot(db);
      const spec = RoundEventSpec(
        fact: Fact(3, 8),
        direction: AskDirection.reversed,
        kind: EventKind.review,
        rung: Rung.labeled,
        choiceDistractors: [21, 27],
      );
      expect(booted.controller.displayFactors(spec), (8, 3));
    });
  });
}
