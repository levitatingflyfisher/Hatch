@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/shared/painters/album_painter.dart';
import 'package:hatch/shared/theme/app_colors.dart';
import 'package:mastery_core/mastery_core.dart';

/// The Album at ~30px cells, mid-journey: hatched critters (some sleepy),
/// mini trays at every rung, twin eggs waiting on mirror confirmation,
/// royal crowns on the diagonal, honest muslin for the untouched frontier.
void main() {
  const pack = MultiplicationPack();

  SamplerView midJourney() {
    final cells = <Fact, SamplerCell>{};
    SamplerCell cell(
      Fact f, {
      bool started = true,
      Rung rung = Rung.grid,
      Phase phase = Phase.counting,
      bool dueNow = false,
      bool mirrorFilled = false,
      bool repaired = false,
    }) => SamplerCell(
      fact: f,
      family: pack.ownerOf(f),
      started: started,
      rung: rung,
      phase: phase,
      dueNow: dueNow,
      mirrorFilled: mirrorFilled,
      repaired: repaired,
    );

    // x2: fully hatched, twins confirmed; two due a visit.
    for (final f in pack.ownedBy(Family.x2)) {
      cells[f] = cell(
        f,
        rung: Rung.bare,
        phase: Phase.automatic,
        mirrorFilled: true,
        dueNow: f == const Fact(2, 6) || f == const Fact(2, 9),
      );
    }
    // x10: hatched but mirrors still incubating.
    for (final f in pack.ownedBy(Family.x10)) {
      cells[f] = cell(f, rung: Rung.bare, phase: Phase.automatic);
    }
    // x5: labeled trays, derived.
    for (final f in pack.ownedBy(Family.x5)) {
      cells[f] = cell(f, rung: Rung.labeled, phase: Phase.derived);
    }
    // x1: bundled cartons.
    for (final f in pack.ownedBy(Family.x1)) {
      cells[f] = cell(f, rung: Rung.bundled);
    }
    // x0: open grid, just started.
    for (final f in pack.ownedBy(Family.x0)) {
      cells[f] = cell(f);
    }
    // Frontier untouched: x4 onward stays unstarted (honest muslin).
    for (final family in [
      Family.x4,
      Family.x3,
      Family.x9,
      Family.x6,
      Family.x7,
      Family.x8,
    ]) {
      for (final f in pack.ownedBy(family)) {
        cells[f] = cell(f, started: false);
      }
    }
    return SamplerView(cells: cells);
  }

  Future<void> pump(WidgetTester tester, {required bool dark}) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 400);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: dark ? AppColors.plumDark : AppColors.cream,
          body: Center(
            child: RepaintBoundary(
              child: ColoredBox(
                color: dark ? AppColors.plumDark : AppColors.cream,
                child: SizedBox(
                  width: 352,
                  height: 352,
                  child: CustomPaint(
                    painter: AlbumPainter(view: midJourney(), dark: dark),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('album mid-journey, light', (tester) async {
    await pump(tester, dark: false);
    await expectLater(
      find.byType(RepaintBoundary).last,
      matchesGoldenFile('goldens/album_mid_journey_light.png'),
    );
  });

  testWidgets('album mid-journey, dark', (tester) async {
    await pump(tester, dark: true);
    await expectLater(
      find.byType(RepaintBoundary).last,
      matchesGoldenFile('goldens/album_mid_journey_dark.png'),
    );
  });
}
