import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mastery_core/mastery_core.dart';

import '../../../shared/audio/sound_cue.dart';
import '../../../shared/painters/egg_art.dart';
import '../../../shared/painters/ghost_cursor.dart';
import '../../../shared/painters/incubator_frame_painter.dart';
import '../../../shared/scene/seeded.dart';
import '../../../shared/theme/app_colors.dart';
import '../domain/construct_plan.dart';
import '../domain/nursery_controller.dart';
import '../domain/vignette_scripts.dart';
import 'answer_stage.dart';
import 'scene_widgets.dart';

/// Replays a ghost-cursor script over the plan's frame, then commits the
/// move choreography, then reports finished. One template engine — the
/// script and plan are data; this player is the only playback code.
class GuidedMovePlayer extends StatefulWidget {
  const GuidedMovePlayer({
    super.key,
    required this.plan,
    required this.script,
    required this.playCue,
    required this.onFinished,
  });

  final ConstructPlan plan;
  final GhostCursorScript script;
  final void Function(SoundCue cue) playCue;
  final VoidCallback onFinished;

  @override
  State<GuidedMovePlayer> createState() => _GuidedMovePlayerState();
}

class _GuidedMovePlayerState extends State<GuidedMovePlayer>
    with TickerProviderStateMixin {
  late final AnimationController _script;
  late final AnimationController _move;
  var _finished = false;

  @override
  void initState() {
    super.initState();
    final total = widget.script.totalDuration;
    _script = AnimationController(
      vsync: this,
      duration: total > Duration.zero ? total : const Duration(milliseconds: 1),
    );
    _move = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _script.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.playCue(switch (widget.plan.verb) {
          ConstructVerb.fold => SoundCue.fold,
          ConstructVerb.slice || ConstructVerb.trim => SoundCue.slice,
          ConstructVerb.addRow || ConstructVerb.stack => SoundCue.plink,
        });
        _move.forward();
      }
    });
    _move.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_finished) {
        _finished = true;
        widget.onFinished();
      }
    });
    _script.forward();
  }

  @override
  void dispose() {
    _script.dispose();
    _move.dispose();
    super.dispose();
  }

  /// The fact this move derives (the added row completes one more group).
  Fact get _derivedFact => Fact.folded(
    widget.plan.frameA + (widget.plan.verb == ConstructVerb.addRow ? 1 : 0),
    widget.plan.frameB,
  );

  @override
  Widget build(BuildContext context) {
    final spec = widget.plan;
    final fact = _derivedFact;
    return AnimatedBuilder(
      animation: Listenable.merge([_script, _move]),
      builder: (context, _) {
        final elapsed = widget.script.totalDuration * _script.value;
        final showGhost = _script.isAnimating || _script.value < 1;
        return GuidedScene(
          plan: spec,
          hue: factHue(fact),
          seed: seedFor(fact.a, fact.b),
          stackRows: spec.verb == ConstructVerb.stack
              ? (_move.value * spec.frameA).ceil()
              : 0,
          moveProgress: _move.value,
          ghost: showGhost ? widget.script.stateAt(elapsed) : null,
        );
      },
    );
  }
}

/// The family-unlock vignette: the strategy taught wordlessly on the child's
/// own mastered tray, one short label allowed, replayable by tapping the
/// scene, completion recorded only when she taps onward (interruption-safe).
class VignetteStage extends StatefulWidget {
  const VignetteStage({
    super.key,
    required this.controller,
    required this.playCue,
  });

  final NurseryController controller;
  final void Function(SoundCue cue) playCue;

  @override
  State<VignetteStage> createState() => _VignetteStageState();
}

class _VignetteStageState extends State<VignetteStage> {
  var _done = false;
  var _run = 0;

  void _replay() => setState(() {
    _done = false;
    _run++;
  });

  @override
  Widget build(BuildContext context) {
    final spec = widget.controller.vignette;
    if (spec == null) return const SizedBox.shrink();
    final vignette = NurseryVignette.forSpec(spec);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            vignette.label,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _done ? _replay : null,
              child: GuidedMovePlayer(
                key: ValueKey('vignette-run-$_run'),
                plan: vignette.plan,
                script: vignette.script,
                playCue: widget.playCue,
                onFinished: () => setState(() => _done = true),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 104,
          child: _done
              ? Center(
                  child: FilledButton(
                    key: const ValueKey('nursery-continue'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(160, 72),
                      backgroundColor: AppColors.yolk,
                      foregroundColor: AppColors.ink,
                    ),
                    onPressed: widget.controller.vignetteFinished,
                    child: const Icon(Icons.check_rounded, size: 40),
                  ),
                )
              : null,
        ),
      ],
    );
  }
}

/// The 3rd-miss pause: the tag unfolds to its labeled tray and the child
/// picks her own way through — a derivation route (seam thumbnails) or the
/// free flash-count reveal. Her choice, always.
class StrategyOfferStage extends StatelessWidget {
  const StrategyOfferStage({super.key, required this.controller});

  final NurseryController controller;

  @override
  Widget build(BuildContext context) {
    final offer = controller.strategyOffer;
    if (offer == null) return const SizedBox.shrink();
    final (a, b) = offer.direction == AskDirection.forward
        ? (offer.fact.a, offer.fact.b)
        : (offer.fact.b, offer.fact.a);
    final routes = [
      offer.offered,
      if (offer.alternate != null) offer.alternate!,
    ];
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TrayView(
              a: a,
              b: b,
              rung: Rung.labeled,
              hue: factHue(offer.fact),
              seed: seedFor(offer.fact.a, offer.fact.b),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < routes.length; i++)
                Expanded(
                  child: _SeamThumb(
                    key: ValueKey('nursery-route-$i'),
                    fact: offer.fact,
                    route: routes[i],
                    onTap: () => controller.chooseStrategy(routes[i]),
                  ),
                ),
              Expanded(
                child: _RoundAction(
                  key: const ValueKey('nursery-show-me'),
                  icon: Icons.visibility_outlined,
                  label: 'Show me',
                  onTap: controller.chooseShowMe,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SeamThumb extends StatelessWidget {
  const _SeamThumb({
    super.key,
    required this.fact,
    required this.route,
    required this.onTap,
  });

  final Fact fact;
  final StrategyRoute route;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final plan = ConstructPlan.forFactRoute(fact, route);
    return _OfferChoice(
      label: vignetteLabel(route),
      onTap: onTap,
      art: CustomPaint(
        painter: IncubatorFramePainter(
          a: plan.frameA,
          b: plan.frameB,
          seam: plan.seam,
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _OfferChoice(
      label: label,
      onTap: onTap,
      art: Icon(icon, size: 40, color: AppColors.yolkDark),
    );
  }
}

/// One choice in the strategy offer: the art with the move named underneath.
///
/// The label used to appear only *after* she had chosen — which made the
/// app's single real decision a guess between two wordless pictures, taken at
/// the moment she is most confused (a third consecutive miss). The name of a
/// choice belongs on the choice.
class _OfferChoice extends StatelessWidget {
  const _OfferChoice({
    required this.label,
    required this.art,
    required this.onTap,
  });

  final String label;
  final Widget art;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: AppColors.creamCard,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: SizedBox(height: 74, child: Center(child: art)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Plays the chosen remediation: the picked route as a quick vignette on the
/// missed fact's own tray, or the flash-count reveal. Ends by handing the
/// controller its re-ask.
class StrategyPlayStage extends StatelessWidget {
  const StrategyPlayStage({
    super.key,
    required this.controller,
    required this.playCue,
  });

  final NurseryController controller;
  final void Function(SoundCue cue) playCue;

  @override
  Widget build(BuildContext context) {
    final offer = controller.strategyOffer;
    if (offer == null) return const SizedBox.shrink();
    if (controller.showMeReveal) {
      final (a, b) = offer.direction == AskDirection.forward
          ? (offer.fact.a, offer.fact.b)
          : (offer.fact.b, offer.fact.a);
      return Padding(
        padding: const EdgeInsets.all(16),
        child: FlashCountReveal(
          a: a,
          b: b,
          hue: factHue(offer.fact),
          seed: seedFor(offer.fact.a, offer.fact.b),
          onFinished: controller.strategyPlayed,
        ),
      );
    }
    final route = controller.playingRoute;
    if (route == null) return const SizedBox.shrink();
    final plan = ConstructPlan.forFactRoute(offer.fact, route);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            vignetteLabel(route),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GuidedMovePlayer(
              plan: plan,
              script: ghostScriptFor(plan),
              playCue: playCue,
              onFinished: controller.strategyPlayed,
            ),
          ),
        ),
      ],
    );
  }
}

/// The "show me" reveal: the tray's cells count themselves up to the total,
/// numeral rising with them. Free, kind, and always followed by the re-ask.
class FlashCountReveal extends StatefulWidget {
  const FlashCountReveal({
    super.key,
    required this.a,
    required this.b,
    required this.hue,
    required this.seed,
    required this.onFinished,
  });

  final int a;
  final int b;
  final Color hue;
  final int seed;
  final VoidCallback onFinished;

  @override
  State<FlashCountReveal> createState() => _FlashCountRevealState();
}

class _FlashCountRevealState extends State<FlashCountReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress;

  @override
  void initState() {
    super.initState();
    final capacity = widget.a * widget.b;
    _progress = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (500 + capacity * 90).clamp(900, 3200)),
    );
    _progress.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onFinished();
    });
    _progress.forward();
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final capacity = widget.a * widget.b;
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        // Cells fill over the first 85%; the final count holds for the rest.
        final filled = math.min(
          (_progress.value / 0.85 * capacity).floor(),
          capacity,
        );
        return Column(
          children: [
            Expanded(
              child: UnitCanvas(
                cols: widget.b,
                rows: widget.a,
                builder: (size) => CustomPaint(
                  painter: _CountRevealPainter(
                    a: widget.a,
                    b: widget.b,
                    filled: filled,
                    hue: widget.hue,
                    seed: widget.seed,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 72,
              child: Center(
                child: Text(
                  '$filled',
                  key: const ValueKey('nursery-count'),
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Tray grid with the first [filled] eggs placed — TrayPainter's open-tray
/// geometry, fill-order row-major.
class _CountRevealPainter extends CustomPainter {
  const _CountRevealPainter({
    required this.a,
    required this.b,
    required this.filled,
    required this.hue,
    required this.seed,
  });

  final int a;
  final int b;
  final int filled;
  final Color hue;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final margin = size.shortestSide * 0.03;
    final area =
        Offset(margin, margin) &
        Size(size.width - margin * 2, size.height - margin * 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(area, Radius.circular(area.shortestSide * 0.08)),
      Paint()..color = Color.lerp(hue, Colors.white, 0.30)!,
    );
    if (a == 0 || b == 0) return;
    final cellW = area.width / b;
    final cellH = area.height / a;
    final wellPaint = Paint()..color = Color.lerp(hue, AppColors.ink, 0.32)!;
    final wellR = Radius.circular(math.min(cellW, cellH) * 0.28);
    for (var i = 0; i < a * b; i++) {
      final cell = Rect.fromLTWH(
        area.left + (i % b) * cellW,
        area.top + (i ~/ b) * cellH,
        cellW,
        cellH,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(cell.deflate(cellW * 0.09), wellR),
        wellPaint,
      );
      if (i < filled) {
        EggArt.paintEgg(
          canvas,
          Rect.fromCenter(
            center: cell.center + seededOffset(seed, i, cellW * 0.03),
            width: cellW * 0.62,
            height: cellH * 0.74,
          ),
          seed: seededInt(seed, i),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CountRevealPainter oldDelegate) =>
      oldDelegate.a != a ||
      oldDelegate.b != b ||
      oldDelegate.filled != filled ||
      oldDelegate.hue != hue ||
      oldDelegate.seed != seed;
}
