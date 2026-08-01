import 'package:hatch/core/providers/core_providers.dart';
import 'package:hatch/core/router/app_router.dart';
import 'package:hatch/core/storage/app_database.dart';
import 'package:hatch/features/album/presentation/album_screen.dart';
import 'package:hatch/features/home/presentation/home_screen.dart';
import 'package:hatch/features/profiles/presentation/profile_picker_screen.dart';
import 'package:hatch/shared/theme/app_theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> makeContainer({
  Map<String, Object> prefsValues = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefsValues);
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
  return container;
}

void main() {
  testWidgets(
    'home shows the app name, the active hatcher, live mode buttons, and '
    'the fresh-hatcher nudge on the Nursery',
    (tester) async {
      // The first insert into a fresh database always takes id 1; the prefs
      // must be seeded before the container captures them.
      final container = await makeContainer(
        prefsValues: {'active_profile_id': 1},
      );
      final id = await container.read(profilesDaoProvider).createProfile();
      expect(id, 1);

      final router = container.read(appRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      router.go('/home');
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Hatch'), findsOneWidget);
      expect(find.text('Hatcher 1'), findsOneWidget);

      for (final label in [
        'The Nursery',
        'Hatch Rush',
        'The Album',
        'Habitats',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      final buttons = tester.widgetList<FilledButton>(
        find.byType(FilledButton),
      );
      expect(buttons, hasLength(3));
      for (final button in buttons) {
        expect(button.onPressed, isNotNull, reason: 'modes are live now');
      }
      // A brand-new hatcher gets the one nudge home allows itself.
      expect(find.text('start here — an egg is waiting'), findsOneWidget);
      // Parent corner and settings sit small in the top row.
      expect(find.byTooltip('Parent corner'), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);
    },
  );

  testWidgets('tapping The Album navigates to the album', (tester) async {
    final container = await makeContainer(
      prefsValues: {'active_profile_id': 1},
    );
    await container.read(profilesDaoProvider).createProfile();

    final router = container.read(appRouterProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    router.go('/home');
    await tester.pumpAndSettle();

    await tester.tap(find.text('The Album'));
    await tester.pumpAndSettle();
    expect(find.byType(AlbumScreen), findsOneWidget);
  });

  testWidgets('a stale active profile id returns to the picker', (
    tester,
  ) async {
    // Prefs claim profile 99, but the database has no such row (the state a
    // restore can leave behind).
    final container = await makeContainer(
      prefsValues: {'active_profile_id': 99},
    );
    final router = container.read(appRouterProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    router.go('/home');
    await tester.pumpAndSettle();

    expect(find.byType(ProfilePickerScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });
}
