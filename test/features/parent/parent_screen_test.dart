import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/features/parent/presentation/parent_screen.dart';
import 'package:hatch/features/parent/presentation/teaching_catalogue_screen.dart';
import 'package:hatch/shared/theme/app_theme.dart';

import '../album/engine_harness.dart';

void main() {
  Future<void> pumpParent(
    WidgetTester tester,
    ProviderContainer container,
    int profileId,
  ) async {
    // Tall surface so the lazy ListView builds EVERY text — both for the
    // positive assertions and so the ADR-0004 sweep scans the whole screen,
    // not just what fits above the fold.
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: ParentScreen(profileId: profileId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openGate(WidgetTester tester) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('hold-gate-ring'))),
    );
    // Priming pump: the hold ticker measures from its first frame in tests.
    await tester.pump();
    await tester.pump(const Duration(seconds: 2, milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('the corner offers the teaching catalogue, so a parent can see '
      'what the app does without weeks of play', (tester) async {
    final (container, profileId) = await makeContainerWithProfile();
    await driveEngine(container, profileId, days: 2);

    await withClock(
      Clock.fixed(kDriveStart.add(const Duration(days: 2))),
      () async {
        await pumpParent(tester, container, profileId);
        await openGate(tester);

        // Every teaching move is gated behind weeks of real play; a parent
        // evaluating Hatch has minutes. This is the door.
        await tester.tap(find.byKey(const Key('parent-teaching-catalogue')));
        await tester.pumpAndSettle();
        expect(find.byType(TeachingCatalogueScreen), findsOneWidget);
      },
    );
  });

  testWidgets('the corner is gated: no stats visible until a completed hold', (
    tester,
  ) async {
    final (container, profileId) = await makeContainerWithProfile();
    await driveEngine(container, profileId, days: 2);

    await withClock(
      Clock.fixed(kDriveStart.add(const Duration(days: 2))),
      () async {
        await pumpParent(tester, container, profileId);
        expect(find.text('For grown-ups'), findsOneWidget);
        expect(find.byKey(const Key('parent-heatmap')), findsNothing);
        expect(find.textContaining('automatic'), findsNothing);

        await openGate(tester);
        expect(find.byKey(const Key('parent-heatmap')), findsOneWidget);
      },
    );
  });

  testWidgets('shows mastery states in plain language, with the honest '
      'method note and the backup pointer', (tester) async {
    final (container, profileId) = await makeContainerWithProfile();
    final service = await driveEngine(container, profileId);

    await withClock(
      Clock.fixed(kDriveStart.add(const Duration(days: 6))),
      () async {
        final stats = service.stats();
        await pumpParent(tester, container, profileId);
        await openGate(tester);

        final auto = stats.automaticCount;
        final growing = stats.startedCount - auto;
        expect(
          find.text(
            auto == 1
                ? '1 of 66 facts is automatic'
                : '$auto of 66 facts are automatic',
          ),
          findsOneWidget,
        );
        expect(
          find.text(growing == 1 ? '1 is growing' : '$growing are growing'),
          findsOneWidget,
        );
        expect(
          find.text('${66 - stats.startedCount} not started yet'),
          findsOneWidget,
        );
        expect(find.textContaining('waiting today'), findsOneWidget);
        expect(
          find.textContaining('spreads practice across calendar days'),
          findsOneWidget,
        );
        expect(find.textContaining('Backups live in Settings'), findsOneWidget);
        expect(find.text('Share album poster'), findsOneWidget);
      },
    );
  });

  testWidgets('ADR-0004: never latency, speed, or per-answer data', (
    tester,
  ) async {
    final (container, profileId) = await makeContainerWithProfile();
    await driveEngine(container, profileId);

    await withClock(
      Clock.fixed(kDriveStart.add(const Duration(days: 6))),
      () async {
        await pumpParent(tester, container, profileId);
        await openGate(tester);

        final texts = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => (t.data ?? '').toLowerCase())
            .toList();
        for (final banned in ['ms', 'latency', 'speed', 'second', '%']) {
          expect(
            texts.where((t) => t.contains(banned)),
            isEmpty,
            reason:
                'parent view shows mastery states only — "$banned" leaks '
                'timing or per-answer data (ADR-0004)',
          );
        }
      },
    );
  });
}
