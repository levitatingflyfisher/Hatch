import 'package:hatch/core/providers/core_providers.dart';
import 'package:hatch/core/storage/app_database.dart';
import 'package:hatch/features/profiles/presentation/profile_picker_screen.dart';
import 'package:hatch/shared/theme/app_theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression: at tablet/desktop widths the picker rendered left-aligned
/// (caught in a web screenshot pass). The headline and the egg grid must sit
/// on the horizontal center at any width.
void main() {
  testWidgets('picker content is horizontally centered at desktop width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(const {});
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
    await container.read(profilesDaoProvider).createProfile();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ProfilePickerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final headline = tester.getCenter(find.text("Who's hatching today?"));
    expect(headline.dx, moreOrLessEquals(512, epsilon: 2));
    final egg = tester.getCenter(find.text('Hatcher 1'));
    final add = tester.getCenter(find.text('New hatcher'));
    final gridCenter = (egg.dx + add.dx) / 2;
    expect(gridCenter, moreOrLessEquals(512, epsilon: 2));
  });
}
