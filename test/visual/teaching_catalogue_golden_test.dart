@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/features/parent/presentation/teaching_catalogue_screen.dart';
import 'package:hatch/shared/theme/app_theme.dart';

/// The catalogue is the app's demo surface — the one screen whose whole job is
/// to be looked at. So it gets a golden, and the golden gets looked at: run
/// with `--update-goldens` and OPEN the PNG. A golden only ever answers "did
/// this change"; the reviewing eye is what answers "is this good".
void main() {
  testWidgets('the teaching catalogue, top to bottom', (tester) async {
    // Phone width, where it actually has to work.
    tester.view.physicalSize = const Size(360, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const TeachingCatalogueScreen()),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(TeachingCatalogueScreen),
      matchesGoldenFile('goldens/teaching_catalogue_light.png'),
    );
  });
}
