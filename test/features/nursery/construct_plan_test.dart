import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/features/nursery/domain/construct_plan.dart';
import 'package:hatch/features/nursery/domain/vignette_scripts.dart';
import 'package:hatch/shared/painters/incubator_frame_painter.dart';
import 'package:mastery_core/mastery_core.dart';

RoundEventSpec spec(
  Fact fact, {
  AskDirection direction = AskDirection.forward,
  Rung rung = Rung.grid,
  StrategyRoute? hint,
}) => RoundEventSpec(
  fact: fact,
  direction: direction,
  kind: EventKind.construct,
  rung: rung,
  choiceDistractors: const [],
  strategyHint: hint,
);

void main() {
  group('ConstructPlan', () {
    test('no hint → STACK in display orientation', () {
      final plan = ConstructPlan.forSpec(spec(const Fact(3, 8)));
      expect(plan.verb, ConstructVerb.stack);
      expect((plan.frameA, plan.frameB), (3, 8));
      expect(plan.seam, isNull);
      expect(plan.prefilledRows, 0);
      expect(plan.scaffoldText, isEmpty);
    });

    test('reversed direction flips the STACK frame', () {
      final plan = ConstructPlan.forSpec(
        spec(const Fact(3, 8), direction: AskDirection.reversed),
      );
      expect((plan.frameA, plan.frameB), (8, 3));
    });

    test(
      'foldDouble: family factor rows, split at half, mirrored partials',
      () {
        final plan = ConstructPlan.forSpec(
          spec(
            const Fact(4, 7),
            rung: Rung.labeled,
            hint: StrategyRoute.foldDouble,
          ),
        );
        expect(plan.verb, ConstructVerb.fold);
        expect((plan.frameA, plan.frameB), (4, 7));
        expect((plan.seam as SplitSeam).afterRow, 2);
        expect(plan.partialProducts, [14, 14]);
        expect(plan.prefilledRows, 2);
        expect(plan.scaffoldText, '14+14');
        expect(plan.product, 28);
      },
    );

    test('fiveAnchorSplit: split at the 5-line', () {
      final plan = ConstructPlan.forSpec(
        spec(
          const Fact(7, 8),
          rung: Rung.labeled,
          hint: StrategyRoute.fiveAnchorSplit,
        ),
      );
      expect(plan.verb, ConstructVerb.slice);
      expect((plan.frameA, plan.frameB), (7, 8));
      expect((plan.seam as SplitSeam).afterRow, 5);
      expect(plan.scaffoldText, '40+16');
      expect(plan.extraRows, 0);
    });

    test('trimAGroup: the ×10 bolt loses its overhang row', () {
      final plan = ConstructPlan.forSpec(
        spec(
          const Fact(7, 9),
          rung: Rung.labeled,
          hint: StrategyRoute.trimAGroup,
        ),
      );
      expect(plan.verb, ConstructVerb.trim);
      expect((plan.frameA, plan.frameB), (9, 7));
      expect(plan.seam, isA<TrimRowSeam>());
      expect(plan.scaffoldText, '70−7');
      expect(plan.extraRows, 1);
      expect(plan.sceneRows, 10);
      expect(plan.product, 63);
    });

    test('addAGroup: one ghost row under the smaller frame', () {
      final plan = ConstructPlan.forSpec(
        spec(
          const Fact(3, 6),
          rung: Rung.labeled,
          hint: StrategyRoute.addAGroup,
        ),
      );
      expect(plan.verb, ConstructVerb.addRow);
      expect((plan.frameA, plan.frameB), (2, 6));
      expect(plan.seam, isA<GhostRowSeam>());
      expect(plan.scaffoldText, '12+6');
      expect(plan.product, 18);
    });

    test('nearSquare: n×n grows out of (n−1)×n', () {
      final plan = ConstructPlan.forFactRoute(
        const Fact(6, 6),
        StrategyRoute.nearSquare,
      );
      expect(plan.verb, ConstructVerb.addRow);
      expect((plan.frameA, plan.frameB), (5, 6));
      expect(plan.scaffoldText, '30+6');
      expect(plan.product, 36);
    });
  });

  group('ghost scripts', () {
    test('every verb has a finite script that reaches done', () {
      for (final route in StrategyRoute.values) {
        final plan = ConstructPlan.forFactRoute(const Fact(6, 7), route);
        final script = ghostScriptFor(plan);
        expect(script.steps, isNotEmpty, reason: '$route');
        expect(script.totalDuration, greaterThan(Duration.zero));
        expect(script.stateAt(script.totalDuration).done, isTrue);
      }
    });

    test('vignette resolves the derived frame from the engine anchor', () {
      const vignette = VignetteSpec(
        family: Family.x4,
        route: StrategyRoute.foldDouble,
        anchor: Fact(2, 7),
      );
      final resolved = NurseryVignette.forSpec(vignette);
      expect((resolved.plan.frameA, resolved.plan.frameB), (4, 7));
      expect(resolved.plan.verb, ConstructVerb.fold);
      expect(resolved.label, 'Double it!');
    });

    test('squares vignette anchors on the diagonal fact itself', () {
      const vignette = VignetteSpec(
        family: Family.squares,
        route: StrategyRoute.nearSquare,
        anchor: Fact(5, 5),
      );
      final resolved = NurseryVignette.forSpec(vignette);
      expect((resolved.plan.frameA, resolved.plan.frameB), (4, 5));
      expect(resolved.plan.product, 25);
    });
  });
}
