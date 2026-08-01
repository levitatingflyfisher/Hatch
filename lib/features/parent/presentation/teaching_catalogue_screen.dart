import 'package:flutter/material.dart';
import 'package:mastery_core/mastery_core.dart';

import '../../../shared/painters/incubator_frame_painter.dart';
import '../../../shared/painters/shortfall_overflow.dart';
import '../../../shared/painters/tray_painter.dart';
import '../../../shared/theme/app_colors.dart';
import '../../nursery/domain/construct_plan.dart';
import '../../nursery/domain/ladder_copy.dart';
import '../../nursery/domain/miss_copy.dart';
import '../../nursery/domain/vignette_scripts.dart';
import '../../nursery/presentation/vignette_stage.dart';

/// Everything Hatch teaches, on one screen, playable on demand.
///
/// This exists because the app's teaching is gated behind weeks of real play.
/// "Double it!" needs four families satisfied, a fifth unlocked, and the fact
/// climbed to the labeled rung — so a parent deciding whether to hand Hatch to
/// their child, or a developer checking their own work, could not see what the
/// app actually does without grinding to it.
///
/// It takes no profile and no engine on purpose: every plan, tray and miss
/// shape here is constructible from pure painters, which is exactly what lets
/// it show all of them at once. Nothing on this screen reads or writes a
/// child's data, so ADR-0004 is satisfied trivially — there is no data here.
class TeachingCatalogueScreen extends StatefulWidget {
  const TeachingCatalogueScreen({super.key});

  @override
  State<TeachingCatalogueScreen> createState() =>
      _TeachingCatalogueScreenState();
}

/// One demonstrable move: the route, and factors that show it honestly.
/// `familyFactor` is the factor the route decomposes — 4 for "double it",
/// 9 for "trim a row" — so each card reads the way the child will meet it.
typedef _Move = ({StrategyRoute route, int familyFactor, int other});

const _moves = <_Move>[
  (route: StrategyRoute.skipCount, familyFactor: 2, other: 6),
  (route: StrategyRoute.foldDouble, familyFactor: 4, other: 7),
  (route: StrategyRoute.addAGroup, familyFactor: 3, other: 7),
  (route: StrategyRoute.trimAGroup, familyFactor: 9, other: 7),
  (route: StrategyRoute.fiveAnchorSplit, familyFactor: 7, other: 6),
  (route: StrategyRoute.nearSquare, familyFactor: 6, other: 6),
];

/// Where in the miss choreography the still frame is taken: past placing,
/// partway through the teach, so the gap and its direction are both visible.
const missFrame = 0.72;

class _TeachingCatalogueScreenState extends State<TeachingCatalogueScreen> {
  /// The move currently playing, if any. One at a time: a wall of moving
  /// trays teaches nobody anything.
  StrategyRoute? _playing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('How Hatch teaches')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Text(
            'Hatch never asks a child to memorise a fact she cannot yet '
            'build. Every fact is first constructed out of eggs, then derived '
            'from one she already owns, and only then asked bare. This is '
            'everything the app will teach, shown here without waiting weeks '
            'to reach it.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 28),

          Text('The six moves', style: text.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Each one turns a fact your child does not know into one she '
            'does. Tap a card to watch it play.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 12),
          for (final move in _moves) _moveCard(context, move),

          const SizedBox(height: 28),
          Text('The weaning ladder', style: text.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Every fact climbs these four rungs, one at a time, and only on '
            'evidence. The support is designed to disappear.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 12),
          for (final rung in Rung.values) _rungCard(context, rung),

          const SizedBox(height: 28),
          Text('When an answer is wrong', style: text.titleLarge),
          const SizedBox(height: 4),
          Text(
            'A wrong answer is never marked wrong. It is built — her number '
            'of eggs, against the tray the fact actually needs — so she sees '
            'the size of the gap rather than a cross.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 12),
          _missCard(context, const ShortfallOverflow(a: 4, b: 7, answer: 21)),
          _missCard(context, const ShortfallOverflow(a: 4, b: 7, answer: 33)),
        ],
      ),
    );
  }

  Widget _moveCard(BuildContext context, _Move move) {
    final text = Theme.of(context).textTheme;
    final plan = ConstructPlan.forRoute(
      move.route,
      familyFactor: move.familyFactor,
      other: move.other,
    );
    final families = familiesUsing(move.route).map(familyLabel).join(', ');
    final playing = _playing == move.route;
    return Card(
      key: ValueKey('catalogue-move-${move.route.name}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: playing ? null : () => setState(() => _playing = move.route),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: playing
                    ? GuidedMovePlayer(
                        key: ValueKey('catalogue-play-${move.route.name}'),
                        plan: plan,
                        script: ghostScriptFor(plan),
                        playCue: (_) {},
                        onFinished: () {
                          if (mounted) setState(() => _playing = null);
                        },
                      )
                    : CustomPaint(
                        painter: IncubatorFramePainter(
                          a: plan.frameA,
                          b: plan.frameB,
                          seam: plan.seam,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vignetteLabel(move.route), style: text.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      // '=' not '→': the bundled Nunito has no U+2192 and
                      // rendered it as tofu. It is also just true.
                      '${move.familyFactor}×${move.other}'
                      '${plan.scaffoldText.isEmpty ? '' : ' = '
                                '${plan.scaffoldText}'}',
                      style: text.bodyLarge,
                    ),
                    const SizedBox(height: 4),
                    Text('Used for $families', style: text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rungCard(BuildContext context, Rung rung) {
    final text = Theme.of(context).textTheme;
    return Card(
      key: ValueKey('catalogue-rung-${rung.name}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: CustomPaint(
                painter: TrayPainter(
                  a: 4,
                  b: 7,
                  rung: rung,
                  hue: AppColors.critterPalette[rung.index],
                  seed: 11 + rung.index,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rungLabel(rung), style: text.titleMedium),
                  const SizedBox(height: 4),
                  Text(rungBlurb(rung), style: text.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _missCard(BuildContext context, ShortfallOverflow miss) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Clipped: the ghost eggs slide in from beyond the tray and the
            // extras roll off it. On a full nursery screen that has room; in
            // a 96px card it lands on top of the description.
            SizedBox(
              width: 96,
              height: 96,
              child: ClipRect(
                child: CustomPaint(
                  painter: ShortfallOverflowPainter(
                    choreography: miss,
                    rung: Rung.grid,
                    // Mid-teach, not the last frame: at progress 1 the ghost
                    // eggs have finished sliding in and a shortfall reads as
                    // a *full* tray — the opposite of what it teaches.
                    progress: missFrame,
                    hue: AppColors.sky,
                    seed: 5,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(missLabel(miss.kind) ?? '', style: text.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'She answered ${miss.answer} for '
                    '${miss.a}×${miss.b}. '
                    '${miss.kind == ShortfallOverflowKind.shortfall ? 'The tray keeps the wells she left empty, then '
                              'slides in the eggs that were missing.' : 'The eggs that will not fit roll off the edge of '
                              'the tray.'}',
                    style: text.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
