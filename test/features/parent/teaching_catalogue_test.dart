import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/features/nursery/domain/ladder_copy.dart';
import 'package:hatch/features/nursery/domain/vignette_scripts.dart';
import 'package:hatch/features/nursery/presentation/vignette_stage.dart';
import 'package:hatch/features/parent/presentation/teaching_catalogue_screen.dart';
import 'package:hatch/shared/painters/shortfall_overflow.dart';
import 'package:hatch/shared/theme/app_theme.dart';
import 'package:mastery_core/mastery_core.dart';

/// The catalogue exists because every teaching move in Hatch is gated behind
/// weeks of play: `foldDouble` ("Double it!") needs four families satisfied,
/// a fifth unlocked, and the fact climbed to the labeled rung. A parent
/// deciding whether to hand this to their child — or a developer checking
/// their own work — could not see what the app does without grinding to it.
///
/// So this screen takes no profile and no engine: it is constructible from
/// pure plans and painters alone, which is exactly why it can show
/// everything at once.
Future<void> pumpCatalogue(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2220);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.light, home: const TeachingCatalogueScreen()),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('the still frame is taken where the gap is actually visible', () {
    // Picked by reasoning about the choreography's phase windows, so pin it:
    // if bloomEnd/placeEnd move, the catalogue would silently show a
    // different instant and nothing would notice. Every egg she answered is
    // down (place complete) and the teach is under way but not finished —
    // an empty-welled tray with the missing eggs on their way in.
    const miss = ShortfallOverflow(a: 4, b: 7, answer: 21);
    expect(miss.place(missFrame, Rung.grid), 1);
    expect(miss.teach(missFrame), greaterThan(0));
    expect(miss.teach(missFrame), lessThan(1));
  });

  testWidgets('every teaching move in the engine is named on the catalogue', (
    tester,
  ) async {
    await pumpCatalogue(tester);
    for (final route in StrategyRoute.values) {
      final card = find.byKey(ValueKey('catalogue-move-${route.name}'));
      await tester.scrollUntilVisible(card, 200);
      expect(
        find.descendant(of: card, matching: find.text(vignetteLabel(route))),
        findsOneWidget,
        reason: '${route.name} has no entry',
      );
    }
  });

  testWidgets('every rung of the weaning ladder is named', (tester) async {
    await pumpCatalogue(tester);
    for (final rung in Rung.values) {
      final card = find.byKey(ValueKey('catalogue-rung-${rung.name}'));
      await tester.scrollUntilVisible(card, 200);
      expect(
        find.descendant(of: card, matching: find.text(rungLabel(rung))),
        findsOneWidget,
        reason: '${rung.name} has no entry',
      );
    }
  });

  testWidgets('both wrong-answer shapes appear in the child\'s own words', (
    tester,
  ) async {
    await pumpCatalogue(tester);
    await tester.scrollUntilVisible(find.text('Room for more!'), 200);
    expect(find.text('Room for more!'), findsOneWidget);
    expect(find.text('Too many to fit!'), findsOneWidget);
  });

  testWidgets('a move plays on tap — the catalogue is a demo, not a poster', (
    tester,
  ) async {
    await pumpCatalogue(tester);
    await tester.scrollUntilVisible(find.text('Double it!'), 200);
    await tester.tap(find.text('Double it!'));
    await tester.pump();
    expect(find.byType(GuidedMovePlayer), findsOneWidget);
  });
}
