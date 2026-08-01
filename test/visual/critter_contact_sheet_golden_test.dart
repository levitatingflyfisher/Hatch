@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/shared/critters/critters.dart';
import 'package:hatch/shared/theme/app_colors.dart';
import 'package:mastery_core/mastery_core.dart';

/// The single most important golden: all 66 critters, grouped by species row,
/// at 96px and 28px. Every critter must be distinguishable and charming at
/// both sizes, in both themes.
void main() {
  const pack = MultiplicationPack();

  // Species rows in unlock order (= descending fact count).
  const rowFamilies = [
    Family.x2,
    Family.x10,
    Family.x5,
    Family.x1,
    Family.x0,
    Family.x4,
    Family.x3,
    Family.x9,
    Family.x6,
    Family.x7,
    Family.x8,
  ];

  Widget sheet({required Color background, required Color labelColor}) {
    return ColoredBox(
      color: background,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final family in rowFamilies)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 76,
                    child: Text(
                      family.name,
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  for (final fact in pack.ownedBy(family))
                    Padding(
                      padding: const EdgeInsets.all(2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 96,
                                height: 96,
                                child: CustomPaint(
                                  painter: CritterPainter(CritterSpec.of(fact)),
                                ),
                              ),
                              SizedBox(
                                width: 28,
                                height: 28,
                                child: CustomPaint(
                                  painter: CritterPainter(CritterSpec.of(fact)),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            fact.id,
                            style: TextStyle(color: labelColor, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> pumpSheet(WidgetTester tester, Widget child) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1560, 1420);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(child: RepaintBoundary(child: child)),
          ),
        ),
      ),
    );
  }

  testWidgets('all 66 critters, light', (tester) async {
    await pumpSheet(
      tester,
      sheet(background: AppColors.cream, labelColor: AppColors.ink),
    );
    await expectLater(
      find.byType(RepaintBoundary).last,
      matchesGoldenFile('goldens/critters_contact_sheet_light.png'),
    );
  });

  testWidgets('all 66 critters, dark', (tester) async {
    await pumpSheet(
      tester,
      sheet(background: AppColors.plumDark, labelColor: AppColors.shell),
    );
    await expectLater(
      find.byType(RepaintBoundary).last,
      matchesGoldenFile('goldens/critters_contact_sheet_dark.png'),
    );
  });

  testWidgets('twins mirror and royals crown', (tester) async {
    final pairs = [
      const Fact(3, 8),
      const Fact(2, 5),
      const Fact(6, 9),
      const Fact(7, 7),
    ];
    await pumpSheet(
      tester,
      ColoredBox(
        color: AppColors.cream,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final fact in pairs)
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 96,
                        height: 96,
                        child: CustomPaint(
                          painter: CritterPainter(CritterSpec.of(fact)),
                        ),
                      ),
                      SizedBox(
                        width: 96,
                        height: 96,
                        child: CustomPaint(
                          painter: CritterPainter(CritterSpec.of(fact).twin),
                        ),
                      ),
                    ],
                  ),
                ),
              // Sleepy critter (album due-review look).
              SizedBox(
                width: 96,
                height: 96,
                child: CustomPaint(
                  painter: CritterPainter(
                    CritterSpec.of(const Fact(2, 6)),
                    sleepy: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(RepaintBoundary).last,
      matchesGoldenFile('goldens/critters_twins_sleepy.png'),
    );
  });
}
