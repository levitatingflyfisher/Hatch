@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/shared/critters/critters.dart';
import 'package:hatch/shared/painters/painters.dart';
import 'package:hatch/shared/scene/scene.dart';
import 'package:hatch/shared/theme/app_colors.dart';
import 'package:mastery_core/mastery_core.dart';

/// Golden sweep of the painter inventory. Each golden is a labeled contact
/// strip; run locally with --update-goldens and LOOK at the PNGs.
void main() {
  final hue = AppColors.critterPalette[3 % AppColors.critterPalette.length];
  final seed = seedFor(4, 7);

  Widget cell(String label, Widget child, {double w = 210, double h = 150}) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: w, height: h, child: child),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.ink),
          ),
        ],
      ),
    );
  }

  Future<void> pumpSheet(
    WidgetTester tester,
    Widget child, {
    Size view = const Size(1000, 700),
    Color background = AppColors.cream,
  }) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = view;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: background,
          body: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: RepaintBoundary(
                child: ColoredBox(color: background, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Finder sheetFinder() => find.byType(RepaintBoundary).last;

  testWidgets('tray rungs and settle', (tester) async {
    await pumpSheet(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final rung in Rung.values)
                cell(
                  '4×7 ${rung.name}',
                  CustomPaint(
                    painter: TrayPainter(
                      a: 4,
                      b: 7,
                      rung: rung,
                      hue: hue,
                      seed: seed,
                    ),
                  ),
                ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final settle in [0.0, 0.4, 0.75, 1.0])
                cell(
                  'settle $settle',
                  CustomPaint(
                    painter: TrayPainter(
                      a: 3,
                      b: 5,
                      rung: Rung.grid,
                      hue: AppColors.sky,
                      seed: seedFor(3, 5),
                      settleProgress: settle,
                    ),
                  ),
                  w: 160,
                  h: 110,
                ),
            ],
          ),
          // The album scale: every rung must still read at ~30px.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final rung in Rung.values)
                cell(
                  '30px',
                  Center(
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CustomPaint(
                        painter: TrayPainter(
                          a: 4,
                          b: 7,
                          rung: rung,
                          hue: hue,
                          seed: seed,
                        ),
                      ),
                    ),
                  ),
                  w: 60,
                  h: 40,
                ),
            ],
          ),
        ],
      ),
    );
    await expectLater(
      sheetFinder(),
      matchesGoldenFile('goldens/painters_tray_rungs.png'),
    );
  });

  testWidgets('incubator frame seams', (tester) async {
    await pumpSheet(
      tester,
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          cell(
            '4×7 plain',
            const CustomPaint(painter: IncubatorFramePainter(a: 4, b: 7)),
          ),
          cell(
            '7×8 split after 5',
            const CustomPaint(
              painter: IncubatorFramePainter(a: 7, b: 8, seam: SplitSeam(5)),
            ),
            h: 190,
          ),
          cell(
            '9×6 trim row',
            const CustomPaint(
              painter: IncubatorFramePainter(a: 9, b: 6, seam: TrimRowSeam()),
            ),
            h: 190,
          ),
          cell(
            '3×6 ghost row',
            const CustomPaint(
              painter: IncubatorFramePainter(a: 3, b: 6, seam: GhostRowSeam()),
            ),
          ),
        ],
      ),
      view: const Size(1100, 320),
    );
    await expectLater(
      sheetFinder(),
      matchesGoldenFile('goldens/painters_frame_seams.png'),
    );
  });

  testWidgets('dotted trail and racing caterpillar', (tester) async {
    final wavy = Path()
      ..moveTo(10, 60)
      ..cubicTo(80, 0, 160, 120, 230, 40);
    await pumpSheet(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          cell(
            'dotted trail (progress 0.7)',
            CustomPaint(painter: DottedTrailPainter(path: wavy, progress: 0.7)),
            w: 240,
            h: 120,
          ),
          cell(
            'caterpillar 0.55, ghost 0.75',
            const CustomPaint(
              painter: CaterpillarProgressPainter(
                progress: 0.55,
                ghostProgress: 0.75,
                hue: AppColors.leaf,
                seed: 5,
              ),
            ),
            w: 420,
            h: 64,
          ),
          cell(
            'caterpillar 0.05, no ghost',
            const CustomPaint(
              painter: CaterpillarProgressPainter(
                progress: 0.05,
                hue: AppColors.coral,
                seed: 9,
              ),
            ),
            w: 420,
            h: 64,
          ),
          cell(
            'caterpillar 1.0 (finished) ghost 0.8',
            const CustomPaint(
              painter: CaterpillarProgressPainter(
                progress: 1,
                ghostProgress: 0.8,
                hue: AppColors.grape,
                seed: 2,
              ),
            ),
            w: 420,
            h: 64,
          ),
        ],
      ),
      view: const Size(520, 560),
    );
    await expectLater(
      sheetFinder(),
      matchesGoldenFile('goldens/painters_trail_caterpillar.png'),
    );
  });

  testWidgets('cell fill sweep frames', (tester) async {
    await pumpSheet(
      tester,
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 0.3 / 0.63 / 0.95 land inside the per-row star-pop windows.
          for (final p in [0.0, 0.3, 0.63, 0.95, 1.0])
            cell(
              'sweep $p',
              CustomPaint(
                painter: CellFillSweepPainter(
                  a: 3,
                  b: 6,
                  progress: p,
                  hue: AppColors.tangerine,
                  seed: seedFor(3, 6),
                ),
              ),
              w: 190,
              h: 120,
            ),
        ],
      ),
      view: const Size(1080, 200),
    );
    await expectLater(
      sheetFinder(),
      matchesGoldenFile('goldens/painters_cell_fill_sweep.png'),
    );
  });

  testWidgets('shortfall and overflow teaching frames', (tester) async {
    const short = ShortfallOverflow(a: 4, b: 7, answer: 24);
    const over = ShortfallOverflow(a: 4, b: 7, answer: 32);
    await pumpSheet(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final p in [0.3, 0.62, 0.8, 0.97])
                cell(
                  'shortfall 24 in 4×7 @$p',
                  CustomPaint(
                    painter: ShortfallOverflowPainter(
                      choreography: short,
                      rung: Rung.grid,
                      progress: p,
                      hue: hue,
                      seed: seed,
                    ),
                  ),
                  w: 200,
                  h: 130,
                ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final p in [0.62, 0.8, 0.97])
                cell(
                  'overflow 32 in 4×7 @$p',
                  CustomPaint(
                    painter: ShortfallOverflowPainter(
                      choreography: over,
                      rung: Rung.grid,
                      progress: p,
                      hue: AppColors.sky,
                      seed: seed,
                    ),
                  ),
                  w: 200,
                  h: 130,
                ),
              // Bare rung: the tag chip blooms open first.
              for (final p in [0.06, 0.14])
                cell(
                  'bare bloom @$p',
                  CustomPaint(
                    painter: ShortfallOverflowPainter(
                      choreography: short,
                      rung: Rung.bare,
                      progress: p,
                      hue: hue,
                      seed: seed,
                    ),
                  ),
                  w: 200,
                  h: 130,
                ),
            ],
          ),
        ],
      ),
      view: const Size(1120, 420),
    );
    await expectLater(
      sheetFinder(),
      matchesGoldenFile('goldens/painters_shortfall_overflow.png'),
    );
  });

  testWidgets('ghost cursor replay states', (tester) async {
    final script = GhostCursorScript(const [
      MoveTo(Offset(1.2, 0.6), duration: Duration(milliseconds: 400)),
      TapAt(duration: Duration(milliseconds: 300)),
      DragTo(Offset(4.2, 2.4), duration: Duration(milliseconds: 800)),
    ], start: const Offset(0.4, 2.2));
    Widget frame(Duration at) {
      return CustomPaint(
        painter: GhostCursorPainter(
          state: script.stateAt(at),
          viewport: SceneViewport(
            hoop: const Rect.fromLTWH(0, 0, 240, 150),
            sceneSize: const Size(5, 3),
          ),
        ),
      );
    }

    await pumpSheet(
      tester,
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          cell(
            'mid-move',
            frame(const Duration(milliseconds: 200)),
            w: 240,
            h: 150,
          ),
          cell(
            'tap ripple',
            frame(const Duration(milliseconds: 550)),
            w: 240,
            h: 150,
          ),
          cell(
            'mid-drag',
            frame(const Duration(milliseconds: 1100)),
            w: 240,
            h: 150,
          ),
        ],
      ),
      view: const Size(820, 230),
    );
    await expectLater(
      sheetFinder(),
      matchesGoldenFile('goldens/painters_ghost_cursor.png'),
    );
  });

  testWidgets('hatch moment frames and sparks', (tester) async {
    final spec = CritterSpec.of(const Fact(3, 8));
    await pumpSheet(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final p in [0.0, 0.16, 0.5, 0.68, 0.84, 1.0])
                cell(
                  'hatch @$p',
                  CustomPaint(
                    painter: HatchMomentPainter(spec: spec, progress: p),
                  ),
                  w: 140,
                  h: 150,
                ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final p in [0.25, 0.55, 0.85])
                cell(
                  'sparks @$p',
                  CustomPaint(
                    painter: SparkBurstPainter(progress: p, seed: 12),
                  ),
                  w: 120,
                  h: 120,
                ),
            ],
          ),
        ],
      ),
      view: const Size(1000, 400),
    );
    await expectLater(
      sheetFinder(),
      matchesGoldenFile('goldens/painters_hatch_moment.png'),
    );
  });
}
