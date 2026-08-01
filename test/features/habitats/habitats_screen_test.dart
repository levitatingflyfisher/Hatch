import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/features/habitats/data/habitat_store.dart';
import 'package:hatch/features/habitats/domain/habitat_layout.dart';
import 'package:hatch/features/habitats/presentation/habitats_screen.dart';
import 'package:hatch/shared/theme/app_theme.dart';
import 'package:mastery_core/mastery_core.dart';

import '../album/engine_harness.dart';

void main() {
  Future<void> pumpHabitats(
    WidgetTester tester,
    ProviderContainer container,
    int profileId,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: HabitatsScreen(profileId: profileId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty state invites, never nags: one egg and the way to the '
      'Nursery', (tester) async {
    final (container, profileId) = await makeContainerWithProfile();
    // Engine exists but nothing recorded — no hatched critters.
    await withClock(Clock.fixed(kDriveStart), () async {
      await pumpHabitats(tester, container, profileId);
      expect(
        find.text('Hatch your first critter in the Nursery.'),
        findsOneWidget,
      );
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '');
      expect(
        texts.where((t) => t.contains('0') || t.contains('%')),
        isEmpty,
        reason: 'no "0 of 66", no percentages — a shelf is not a checklist',
      );
    });
  });

  testWidgets('tap a critter, tap a spot: it stands there and the '
      'arrangement persists', (tester) async {
    final (container, profileId) = await makeContainerWithProfile();
    final service = await driveEngine(container, profileId);

    await withClock(
      Clock.fixed(kDriveStart.add(const Duration(days: 6))),
      () async {
        final hatched = service
            .samplerView()
            .cells
            .values
            .where((c) => c.phase == Phase.automatic)
            .toList();
        expect(
          hatched,
          isNotEmpty,
          reason: 'the 6-day drive must hatch at least one critter',
        );
        final id = (hatched.map((c) => c.fact.id).toList()..sort()).first;

        await pumpHabitats(tester, container, profileId);
        expect(find.byKey(Key('roster-$id')), findsOneWidget);

        await tester.tap(find.byKey(Key('roster-$id')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('habitat-slot-4')));
        await tester.pumpAndSettle();

        expect(find.byKey(Key('slot-critter-$id')), findsOneWidget);
        expect(find.byKey(Key('roster-$id')), findsNothing);

        final saved = await container
            .read(habitatStoreProvider)
            .load(profileId);
        expect(saved.slots, {4: id});
      },
    );
  });

  testWidgets('tapping a standing critter sends it back to the tray', (
    tester,
  ) async {
    final (container, profileId) = await makeContainerWithProfile();
    final service = await driveEngine(container, profileId);

    await withClock(
      Clock.fixed(kDriveStart.add(const Duration(days: 6))),
      () async {
        final id =
            (service
                    .samplerView()
                    .cells
                    .values
                    .where((c) => c.phase == Phase.automatic)
                    .map((c) => c.fact.id)
                    .toList()
                  ..sort())
                .first;
        // Start already placed.
        await container
            .read(habitatStoreProvider)
            .save(profileId, HabitatLayout(slots: {2: id}));

        await pumpHabitats(tester, container, profileId);
        expect(find.byKey(Key('slot-critter-$id')), findsOneWidget);

        await tester.tap(find.byKey(const Key('habitat-slot-2')));
        await tester.pumpAndSettle();

        expect(find.byKey(Key('slot-critter-$id')), findsNothing);
        expect(find.byKey(Key('roster-$id')), findsOneWidget);
        final saved = await container
            .read(habitatStoreProvider)
            .load(profileId);
        expect(saved.slots, isEmpty);
      },
    );
  });

  testWidgets('choosing a biome persists it', (tester) async {
    final (container, profileId) = await makeContainerWithProfile();
    await withClock(Clock.fixed(kDriveStart), () async {
      await pumpHabitats(tester, container, profileId);
      await tester.tap(find.byKey(const Key('biome-pond')));
      await tester.pumpAndSettle();

      final saved = await container.read(habitatStoreProvider).load(profileId);
      expect(saved.biome, HabitatBiome.pond);
    });
  });
}
