import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/features/nursery/presentation/nursery_screen.dart';
import 'package:hatch/shared/audio/sound_cue.dart';
import 'package:hatch/shared/painters/hatch_moment.dart';
import 'package:hatch/shared/theme/app_theme.dart';
import 'package:mastery_core/mastery_core.dart';

/// The hatch is what the child is here for, and it is the cue path a playtest
/// can least easily reach — a fact only fires after fast typed recall on
/// separate calendar days. Every other sound in the app went unheard for a
/// full release without a single test noticing (ADR-0003 postscript), so this
/// one gets a witness of its own.
Future<List<SoundCue>> pumpHatch(
  WidgetTester tester, {
  VoidCallback? onContinue,
}) async {
  final cues = <SoundCue>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: HatchStage(
          fact: const Fact(2, 3),
          playCue: cues.add,
          onContinue: onContinue ?? () {},
        ),
      ),
    ),
  );
  return cues;
}

void main() {
  testWidgets('the egg cracks, hatches, and the critter chirps — in that '
      'order, across the full moment', (tester) async {
    final cues = await pumpHatch(tester);

    // The crack lands with the first frame: the shell is already breaking
    // when the child's eye arrives.
    expect(cues, [SoundCue.crack]);

    // Nothing more until the shell actually splits. These pumps are
    // cumulative, so each one is only the *gap* to the next checkpoint —
    // overshoot past 0.8 and the chirp arrives early and the order is
    // untested rather than wrong.
    await tester.pump(HatchMoment.duration * (HatchMoment.crackEnd * 0.9));
    expect(cues, [SoundCue.crack]);

    await tester.pump(HatchMoment.duration * (HatchMoment.crackEnd * 0.15));
    expect(cues, [SoundCue.crack, SoundCue.hatch]);

    await tester.pumpAndSettle();
    expect(cues.length, 3, reason: 'the critter should have peeped by now');
    expect(
      cues.last,
      isIn([SoundCue.chirp1, SoundCue.chirp2, SoundCue.chirp3]),
    );
  });

  testWidgets('the moment is never rushed and never repeats a cue', (
    tester,
  ) async {
    final cues = await pumpHatch(tester);
    await tester.pumpAndSettle();
    // Long after the animation is over, sitting on the critter.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(cues.length, 3, reason: 'cues must fire once each, not per frame');
  });

  testWidgets('a tap does nothing until the critter is out, then continues', (
    tester,
  ) async {
    var continued = 0;
    await pumpHatch(tester, onContinue: () => continued++);

    // Mid-hatch: an impatient thumb must not skip the payoff.
    await tester.pump(HatchMoment.duration * 0.5);
    await tester.tap(find.byKey(const ValueKey('nursery-hatch')));
    await tester.pump();
    expect(continued, 0);

    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.touch_app_rounded), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nursery-hatch')));
    await tester.pump();
    expect(continued, 1);
  });
}
