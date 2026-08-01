import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/features/album/presentation/album_screen.dart';
import 'package:hatch/shared/painters/album_painter.dart';
import 'package:hatch/shared/painters/tray_painter.dart';
import 'package:hatch/shared/theme/app_theme.dart';
import 'package:mastery_core/mastery_core.dart';

import 'engine_harness.dart';

void main() {
  Future<void> pumpAlbum(
    WidgetTester tester,
    ProviderContainer container,
    int profileId,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: AlbumScreen(profileId: profileId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Center of grid cell (row, col), mirroring AlbumPainter's uniform
  /// centered 11×11 layout.
  Offset cellCenter(WidgetTester tester, int row, int col) {
    final rect = tester.getRect(find.byKey(const Key('album-grid')));
    final cell = math.min(rect.width, rect.height) / 11;
    final origin =
        rect.topLeft +
        Offset((rect.width - cell * 11) / 2, (rect.height - cell * 11) / 2);
    return origin + Offset((col + 0.5) * cell, (row + 0.5) * cell);
  }

  testWidgets('paints the sampler view and repaints only when the engine '
      'records (live album law)', (tester) async {
    final (container, profileId) = await makeContainerWithProfile();
    final service = await driveEngine(container, profileId, days: 1);

    await withClock(Clock.fixed(kDriveStart), () async {
      await pumpAlbum(tester, container, profileId);

      AlbumPainter painterNow() =>
          tester
                  .widget<CustomPaint>(find.byKey(const Key('album-grid')))
                  .painter
              as AlbumPainter;

      final before = painterNow().view;
      // A frame with no engine activity must NOT rebuild the album.
      await tester.pump();
      expect(identical(painterNow().view, before), isTrue);

      // A recorded answer notifies the service; the album rebuilds with a
      // fresh view.
      final round = service.assembleRound(RoundIntent.piecing);
      final spec = round.events.first;
      await service.record(
        AnswerEvent(
          fact: spec.fact,
          direction: spec.direction,
          kind: spec.kind,
          rung: spec.rung,
          correct: true,
          latencyMs: 800,
          production: true,
          at: kDriveStart,
        ),
      );
      await tester.pump();
      expect(identical(painterNow().view, before), isFalse);
    });
  });

  testWidgets('tapping a growing cell opens its detail sheet with the tray '
      'at its rung', (tester) async {
    final (container, profileId) = await makeContainerWithProfile();
    final service = await driveEngine(container, profileId, days: 1);

    await withClock(Clock.fixed(kDriveStart), () async {
      final view = service.samplerView();
      final growing = view.cells.values.firstWhere(
        (c) => c.started && c.phase != Phase.automatic,
        orElse: () => throw StateError(
          'drive produced no growing fact — engine tuning changed?',
        ),
      );

      await pumpAlbum(tester, container, profileId);
      await tester.tapAt(cellCenter(tester, growing.fact.a, growing.fact.b));
      await tester.pumpAndSettle();

      expect(
        find.text('${growing.fact.a} × ${growing.fact.b}'),
        findsOneWidget,
      );
      expect(find.text('Growing in the Nursery.'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is TrayPainter,
          ),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('a hatched, overdue fact reads as sleepy — warm visit copy, '
      'and its twin state shows', (tester) async {
    final (container, profileId) = await makeContainerWithProfile();
    final service = await driveEngine(container, profileId, days: 6);

    // Long after the drive — past any 30-day interval times its speed
    // multiplier — so automatic facts are due. Due is never punished; the
    // album only makes the critter sleepy.
    final later = kDriveStart.add(const Duration(days: 180));
    await withClock(Clock.fixed(later), () async {
      final view = service.samplerView();
      final hatched = view.cells.values.firstWhere(
        (c) => c.phase == Phase.automatic && !c.fact.isSquare,
        orElse: () =>
            throw StateError('drive hatched nothing — engine tuning changed?'),
      );
      expect(
        hatched.dueNow,
        isTrue,
        reason: '180 days out, an automatic fact must be due for review',
      );

      await pumpAlbum(tester, container, profileId);
      await tester.tapAt(cellCenter(tester, hatched.fact.a, hatched.fact.b));
      await tester.pumpAndSettle();

      expect(
        find.text(
          "This one's sleepy — a visit to the Nursery will wake it up.",
        ),
        findsOneWidget,
      );
      // Twin row present in one of its two honest states.
      final twinLabel = '${hatched.fact.b} × ${hatched.fact.a}';
      expect(find.textContaining('Its twin, $twinLabel'), findsOneWidget);
    });
  });

  testWidgets('refuse-list: the album never shows percentages or counts of '
      'what is missing', (tester) async {
    final (container, profileId) = await makeContainerWithProfile();
    await driveEngine(container, profileId, days: 2);

    await withClock(Clock.fixed(kDriveStart), () async {
      await pumpAlbum(tester, container, profileId);
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .toList();
      expect(
        texts.where((t) => t.contains('%')),
        isEmpty,
        reason: 'the picture IS the progress — no percentages, ever',
      );
      expect(
        texts.where((t) => t.toLowerCase().contains('left')),
        isEmpty,
        reason: 'no "N left!" completion nags',
      );
    });
  });
}
