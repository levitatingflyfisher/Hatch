import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/core/engine/engine_providers.dart';
import 'package:hatch/core/providers/core_providers.dart';
import 'package:hatch/core/storage/app_database.dart';
import 'package:hatch/features/nursery/domain/construct_plan.dart';
import 'package:hatch/features/nursery/domain/nursery_controller.dart';
import 'package:hatch/features/nursery/domain/vignette_scripts.dart';
import 'package:hatch/features/nursery/presentation/nursery_screen.dart';
import 'package:hatch/shared/answer/answer_input.dart';
import 'package:hatch/shared/audio/audio.dart';
import 'package:hatch/shared/theme/app_theme.dart';
import 'package:mastery_core/mastery_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// No-op audio backend: the audio law says cues are never load-bearing, so
/// the whole flow must run silent.
class _SilentPlayer implements CuePlayer {
  @override
  Future<void> load(String assetPath) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {}
}

Future<(ProviderContainer, int)> makeContainer() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase(NativeDatabase.memory());
  final audio = AudioService(
    isMuted: () => true,
    playerFactory: _SilentPlayer.new,
  );
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appDatabaseProvider.overrideWithValue(db),
      audioServiceProvider.overrideWithValue(audio),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(db.close);
  addTearDown(audio.dispose);
  final profileId = await db
      .into(db.profiles)
      .insert(
        ProfilesCompanion.insert(glyphSeed: 3, createdAt: DateTime(2026, 8)),
      );
  return (container, profileId);
}

Future<NurseryController> pumpNursery(WidgetTester tester) async {
  // Portrait phone per the layout law (must work at 360×740).
  tester.view.physicalSize = const Size(1080, 2220);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final (container, profileId) = await makeContainer();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        home: NurseryScreen(profileId: profileId),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.state<NurseryFlowState>(find.byType(NurseryFlow)).controller;
}

Future<void> tapNumpad(
  WidgetTester tester,
  int value, {
  bool settle = true,
}) async {
  for (final ch in '$value'.split('')) {
    await tester.tap(
      find.descendant(
        of: find.byType(HatchNumPad),
        matching: find.widgetWithText(InkWell, ch),
      ),
    );
    await tester.pump();
  }
  await tester.tap(
    find.descendant(
      of: find.byType(HatchNumPad),
      matching: find.byIcon(Icons.check_rounded),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// Plays whatever the round asks until the done tile, answering
/// [answerFor] (correct by default) and driving every surface through its
/// real gestures.
Future<void> playToDone(
  WidgetTester tester,
  NurseryController controller, {
  int Function(RoundEventSpec spec)? answerFor,
  NurseryPhase haltAt = NurseryPhase.done,
  int maxSteps = 400,
}) async {
  var steps = 0;
  while (controller.phase != haltAt && steps++ < maxSteps) {
    switch (controller.phase) {
      case NurseryPhase.vignette:
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('nursery-continue')));
        await tester.pumpAndSettle();
      case NurseryPhase.building:
        final plan = ConstructPlan.forSpec(controller.current!);
        if (plan.verb == ConstructVerb.stack && plan.frameA == 0) {
          await tester.pumpAndSettle();
        } else if (plan.verb == ConstructVerb.stack) {
          await tester.tap(find.byKey(const ValueKey('nursery-dispenser')));
          await tester.pump();
          await tester.tap(find.byKey(const ValueKey('nursery-frame')));
          // Settle, not pump: the last row of a tray holds for a beat before
          // the numpad arrives, and the dispenser is gone by then.
          await tester.pumpAndSettle();
        } else {
          await tester.tap(find.byKey(const ValueKey('nursery-frame')));
          await tester.pumpAndSettle();
        }
      case NurseryPhase.answering:
        final spec = controller.current!;
        final answer = answerFor?.call(spec) ?? spec.fact.product;
        if (controller.isChoice(spec)) {
          await tester.tap(
            find
                .descendant(
                  of: find.byType(ChoiceButtons),
                  matching: find.text('$answer'),
                )
                .first,
          );
          await tester.pumpAndSettle();
        } else {
          await tapNumpad(tester, answer);
        }
      case NurseryPhase.feedbackMiss:
        // A miss waits for the child; it never advances on its own.
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('nursery-miss-continue')));
        await tester.pumpAndSettle();
      case NurseryPhase.feedbackCorrect:
      case NurseryPhase.strategyPlaying:
      case NurseryPhase.celebrating:
        await tester.pumpAndSettle();
      case NurseryPhase.strategyOffer:
        await tester.tap(find.byKey(const ValueKey('nursery-route-0')));
        await tester.pumpAndSettle();
      case NurseryPhase.hatching:
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('nursery-hatch')));
        await tester.pumpAndSettle();
      case NurseryPhase.idle:
      case NurseryPhase.done:
        await tester.pump();
    }
  }
  expect(
    controller.phase,
    haltAt,
    reason: 'round never reached ${haltAt.name}',
  );
}

void main() {
  testWidgets('full happy-path round: vignette, practices, probes on the '
      'numpad, celebration — and no scores anywhere', (tester) async {
    final controller = await pumpNursery(tester);

    // Fresh engine: the ×2 vignette leads, wordless except its one label.
    expect(controller.phase, NurseryPhase.vignette);
    expect(find.text('Stack the rows!'), findsOneWidget);
    expect(find.byKey(const ValueKey('nursery-close')), findsOneWidget);

    await playToDone(tester, controller);

    expect(find.text('Hatch another?'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    // Competence is the built tray, never a report card.
    expect(find.textContaining('/'), findsNothing);
    expect(find.textContaining('score'), findsNothing);

    // Instant restart.
    await tester.tap(find.byKey(const ValueKey('nursery-again')));
    await tester.pump();
    expect(controller.phase, isNot(NurseryPhase.done));
  });

  testWidgets('wrong answer: shortfall choreography, requeue, and the '
      're-ask closes the round', (tester) async {
    final controller = await pumpNursery(tester);

    // Through the vignette to the first practice's answer step.
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nursery-continue')));
    await tester.pumpAndSettle();
    while (controller.phase == NurseryPhase.building) {
      await tester.tap(find.byKey(const ValueKey('nursery-dispenser')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('nursery-frame')));
      await tester.pumpAndSettle();
    }
    expect(controller.phase, NurseryPhase.answering);
    final target = controller.current!.fact;

    await tapNumpad(tester, target.product + 1, settle: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.phase, NurseryPhase.feedbackMiss);
    expect(find.byKey(const ValueKey('nursery-shortfall')), findsOneWidget);
    expect(controller.service.engine.pendingRequeues, contains(target));

    // The teaching moment holds instead of flashing past, and says in
    // numerals what the fact actually is.
    await tester.pumpAndSettle();
    expect(controller.phase, NurseryPhase.feedbackMiss);
    expect(find.byKey(const ValueKey('nursery-truth')), findsOneWidget);
    expect(
      find.textContaining('${target.product}'),
      findsWidgets,
      reason: 'the true product is shown, not merely implied by the tray',
    );

    // No reveal-then-move-on: the round continues and the re-ask returns.
    var reAsks = 0;
    await playToDone(
      tester,
      controller,
      answerFor: (spec) {
        if (spec.fact == target && controller.eventIndex > 0) reAsks++;
        return spec.fact.product;
      },
    );
    expect(reAsks, greaterThanOrEqualTo(1));
    expect(controller.service.engine.pendingRequeues, isEmpty);
  });

  testWidgets('construct STACK tap-tap: strip → frame snaps rows with a '
      'running skip-count, then the numpad', (tester) async {
    final controller = await pumpNursery(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nursery-continue')));
    await tester.pumpAndSettle();

    // Practice 1 (1×2): one row stacks and construction completes.
    expect(controller.phase, NurseryPhase.building);
    expect(controller.current!.kind, EventKind.vignettePractice);
    expect(find.byKey(const ValueKey('nursery-dispenser')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nursery-dispenser')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('nursery-frame')));
    await tester.pump();
    // The filled tray gets a beat of its own before the question arrives.
    expect(controller.phase, NurseryPhase.building);
    expect(find.byType(HatchNumPad), findsNothing);
    await tester.pumpAndSettle();
    expect(controller.phase, NurseryPhase.answering);
    expect(find.byType(HatchNumPad), findsOneWidget);
    await tapNumpad(tester, controller.current!.fact.product);

    // Practice 2 (2×2): the running total counts 2… 4 as rows snap in.
    expect(controller.phase, NurseryPhase.building);
    final (a, b) = controller.displayFactors(controller.current!);
    expect(a, greaterThan(1));
    await tester.tap(find.byKey(const ValueKey('nursery-dispenser')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('nursery-frame')));
    await tester.pump();
    expect(controller.phase, NurseryPhase.building);
    expect(find.byKey(const ValueKey('nursery-running-total')), findsOneWidget);
    expect(find.text('$b'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('nursery-frame')));
    await tester.pumpAndSettle();
    expect(controller.phase, NurseryPhase.answering);
    expect(find.byType(HatchNumPad), findsOneWidget);
  });

  testWidgets('a miss waits for the child: no auto-advance, and the tap is '
      'what moves the round on', (tester) async {
    final controller = await pumpNursery(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nursery-continue')));
    await tester.pumpAndSettle();
    while (controller.phase == NurseryPhase.building) {
      await tester.tap(find.byKey(const ValueKey('nursery-dispenser')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('nursery-frame')));
      await tester.pumpAndSettle();
    }
    final target = controller.current!.fact;
    await tapNumpad(tester, target.product + 1, settle: false);
    await tester.pumpAndSettle();

    // Ten seconds of a child staring at it changes nothing. This is the
    // whole point: the screen does not take the lesson away.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(controller.phase, NurseryPhase.feedbackMiss);
    expect(find.byKey(const ValueKey('nursery-truth')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nursery-miss-continue')));
    await tester.pumpAndSettle();
    expect(controller.phase, isNot(NurseryPhase.feedbackMiss));
  });

  testWidgets('an overflow miss names what the tray is doing, not only the '
      'fact', (tester) async {
    final controller = await pumpNursery(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nursery-continue')));
    await tester.pumpAndSettle();
    while (controller.phase == NurseryPhase.building) {
      await tester.tap(find.byKey(const ValueKey('nursery-dispenser')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('nursery-frame')));
      await tester.pumpAndSettle();
    }
    final target = controller.current!.fact;
    await tapNumpad(tester, target.product + 1, settle: false);
    await tester.pumpAndSettle();

    expect(controller.phase, NurseryPhase.feedbackMiss);
    // The eggs she cannot fit are rolling off the edge; the screen says so.
    expect(find.text('Too many to fit!'), findsOneWidget);
  });

  testWidgets('a shortfall miss names the room the ghost eggs are filling', (
    tester,
  ) async {
    final controller = await pumpNursery(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nursery-continue')));
    await tester.pumpAndSettle();
    while (controller.phase == NurseryPhase.building) {
      await tester.tap(find.byKey(const ValueKey('nursery-dispenser')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('nursery-frame')));
      await tester.pumpAndSettle();
    }
    final target = controller.current!.fact;
    // Under the true product, so wells are left empty. Guarded: a 0-fact has
    // no room below it.
    final short = target.product > 1 ? target.product - 1 : 1;
    await tapNumpad(tester, short, settle: false);
    await tester.pumpAndSettle();

    expect(controller.phase, NurseryPhase.feedbackMiss);
    expect(find.text('Room for more!'), findsOneWidget);
  });

  testWidgets('the strategy offer names every choice before she picks one', (
    tester,
  ) async {
    final controller = await pumpNursery(tester);
    Fact? target;
    await playToDone(
      tester,
      controller,
      haltAt: NurseryPhase.strategyOffer,
      answerFor: (spec) {
        target ??= spec.fact;
        return spec.fact == target ? spec.fact.product + 1 : spec.fact.product;
      },
    );

    // Three misses in a row is the most confused a child ever is, and this is
    // the app's only real choice. It cannot be two unlabelled thumbnails.
    final offer = controller.strategyOffer!;
    expect(find.text(vignetteLabel(offer.offered)), findsOneWidget);
    if (offer.alternate != null) {
      expect(find.text(vignetteLabel(offer.alternate!)), findsOneWidget);
    }
    expect(find.text('Show me'), findsOneWidget);
  });

  testWidgets('a correct answer settles before it advances', (tester) async {
    final controller = await pumpNursery(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nursery-continue')));
    await tester.pumpAndSettle();
    while (controller.phase == NurseryPhase.building) {
      await tester.tap(find.byKey(const ValueKey('nursery-dispenser')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('nursery-frame')));
      await tester.pumpAndSettle();
    }
    await tapNumpad(tester, controller.current!.fact.product, settle: false);
    await tester.pump();
    expect(controller.phase, NurseryPhase.feedbackCorrect);

    // The sweep runs, and then the finished tray is allowed to sit there —
    // the frame that used to be snatched away the instant it completed.
    await tester.pump(controller.sweepTier.duration);
    expect(
      controller.phase,
      NurseryPhase.feedbackCorrect,
      reason: 'the sweep should hold at full before the round moves on',
    );
    await tester.pumpAndSettle();
    expect(controller.phase, isNot(NurseryPhase.feedbackCorrect));
  });
}
