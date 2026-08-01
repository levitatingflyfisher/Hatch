import 'package:flutter/material.dart';
import 'package:mastery_core/mastery_core.dart';

import '../../../shared/answer/answer_input.dart';
import '../../../shared/critters/critters.dart';
import '../../../shared/painters/cell_fill_sweep.dart';
import '../../../shared/painters/shortfall_overflow.dart';
import '../../../shared/painters/tray_painter.dart';
import '../../../shared/scene/seeded.dart';
import '../../../shared/theme/app_colors.dart';
import '../domain/construct_plan.dart';
import '../domain/miss_copy.dart';
import '../domain/nursery_controller.dart';
import 'scene_widgets.dart';

/// The tray's hue everywhere in the Nursery is the critter's hue, so the
/// tray a child builds and the critter it will hatch read as one thing.
Color factHue(Fact fact) => CritterSpec.of(fact).hue;

/// How long one part of the Nursery takes to hand over to the next — the
/// stage cross-fade, and any panel that resizes under it. Short enough to
/// feel like the same screen breathing, long enough not to be a cut.
const stageFade = Duration(milliseconds: 220);

/// The bare symbolic ask: a big tag, numerals and symbols only.
///
/// It carries weight deliberately. This rung has no tray by design — it is
/// the top of the concrete→pictorial→abstract ladder — but arriving on it
/// straight off a screen full of eggs made the app look like it had lost its
/// content. So the tag lands: it grows into place and sits like a card on the
/// table, rather than appearing as small print on an empty screen.
class PromptTag extends StatelessWidget {
  const PromptTag({super.key, required this.a, required this.b});

  final int a;
  final int b;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.88, end: 1),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 32),
          decoration: BoxDecoration(
            color: AppColors.creamCard,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.yolk, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.speckle.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            '$a×$b = ?',
            style: Theme.of(context).textTheme.displayMedium,
          ),
        ),
      ),
    );
  }
}

/// A fact's tray at a rung, sized by the unit-canvas law.
class TrayView extends StatelessWidget {
  const TrayView({
    super.key,
    required this.a,
    required this.b,
    required this.rung,
    required this.hue,
    required this.seed,
  });

  final int a;
  final int b;
  final Rung rung;
  final Color hue;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return UnitCanvas(
      cols: b,
      rows: a,
      builder: (size) => CustomPaint(
        painter: TrayPainter(a: a, b: b, rung: rung, hue: hue, seed: seed),
      ),
    );
  }
}

/// Non-construct asks: prompt per rung on top, the matching answer surface
/// below. Bare rungs (probes, automatic reviews) get the tag + numpad;
/// grid/bundled reviews get the tray + choice buttons; labeled gets the
/// closed tray + numpad. Remediation re-asks keep the taught route's
/// partial-product scaffold visible.
class AnswerStage extends StatelessWidget {
  const AnswerStage({super.key, required this.controller});

  final NurseryController controller;

  @override
  Widget build(BuildContext context) {
    final spec = controller.current;
    if (spec == null) return const SizedBox.shrink();
    final (a, b) = controller.displayFactors(spec);
    final hue = factHue(spec.fact);
    final seed = seedFor(spec.fact.a, spec.fact.b);
    final choice = controller.isChoice(spec);
    final hint = spec.strategyHint;
    final scaffoldText =
        spec.kind == EventKind.remediation &&
            hint != null &&
            hint != StrategyRoute.skipCount
        ? ConstructPlan.forFactRoute(spec.fact, hint).scaffoldText
        : '';
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: spec.rung == Rung.bare
                ? PromptTag(a: a, b: b)
                : TrayView(a: a, b: b, rung: spec.rung, hue: hue, seed: seed),
          ),
        ),
        if (scaffoldText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              scaffoldText,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: choice
              ? ChoiceButtons(
                  options: controller.choiceOptions(spec),
                  onFirstKey: controller.answerKeyPressed,
                  onChoose: (value) =>
                      controller.submitAnswer(value, production: false),
                )
              : HatchNumPad(
                  onFirstKey: controller.answerKeyPressed,
                  onSubmit: (value) =>
                      controller.submitAnswer(value, production: true),
                ),
        ),
      ],
    );
  }
}

/// Plays the answer's choreography, then hands the round back:
/// correct → the tray's rows crack open in a sweep (tier follows the
/// child's tempo); wrong → the shortfall/overflow teaching moment at the
/// presented rung.
///
/// Neither ending is a hard cut any more. A correct sweep settles for a beat
/// before the round moves on. A miss *stops*: the choreography holds at its
/// last frame, the fact says what it is in numerals, and the child taps when
/// she has looked at it. Auto-advancing off a miss is how a teaching moment
/// becomes a flicker — and a child who is already frustrated is exactly the
/// one who needs the screen to wait for her.
class FeedbackStage extends StatefulWidget {
  const FeedbackStage({super.key, required this.controller});

  /// The beat a correct sweep is allowed to sit at full before advancing.
  static const correctHold = Duration(milliseconds: 420);

  final NurseryController controller;

  @override
  State<FeedbackStage> createState() => _FeedbackStageState();
}

class _FeedbackStageState extends State<FeedbackStage>
    with TickerProviderStateMixin {
  late final AnimationController _progress;
  late final AnimationController _hold;

  /// A miss whose choreography has finished and is now waiting on the child.
  bool _waiting = false;

  bool get _correct => widget.controller.phase == NurseryPhase.feedbackCorrect;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(
      vsync: this,
      duration: _correct
          ? widget.controller.sweepTier.duration
          : ShortfallOverflow.duration,
    );
    // An AnimationController, not a Timer: it keeps scheduling frames, so the
    // hold is part of the normal settle and never leaves a pending timer.
    _hold = AnimationController(
      vsync: this,
      duration: FeedbackStage.correctHold,
    );
    _progress.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      if (_correct) {
        _hold.forward();
      } else {
        setState(() => _waiting = true);
      }
    });
    _hold.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.controller.feedbackDone();
      }
    });
    _progress.forward();
  }

  @override
  void dispose() {
    _progress.dispose();
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final spec = controller.current;
    if (spec == null) return const SizedBox.shrink();
    final (a, b) = controller.displayFactors(spec);
    final hue = factHue(spec.fact);
    final seed = seedFor(spec.fact.a, spec.fact.b);
    final shortfall = controller.shortfall;
    // The miss choreography is the engine's teaching moment; say what it is
    // showing while it shows it, the same way a vignette names its move.
    final missText = _correct || shortfall == null
        ? null
        : missLabel(shortfall.kind);
    final stage = Column(
      children: [
        if (missText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(
              missText,
              key: const ValueKey('nursery-miss-label'),
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: AnimatedBuilder(
              animation: _progress,
              builder: (context, _) => _correct
                  ? UnitCanvas(
                      key: const ValueKey('nursery-sweep'),
                      cols: b,
                      rows: a,
                      builder: (size) => CustomPaint(
                        painter: CellFillSweepPainter(
                          a: a,
                          b: b,
                          progress: _progress.value,
                          hue: hue,
                          seed: seed,
                        ),
                      ),
                    )
                  : shortfall == null
                  ? const SizedBox.shrink()
                  : UnitCanvas(
                      key: const ValueKey('nursery-shortfall'),
                      cols: b,
                      rows: a,
                      builder: (size) => CustomPaint(
                        painter: ShortfallOverflowPainter(
                          choreography: shortfall,
                          rung: spec.rung,
                          progress: _progress.value,
                          hue: hue,
                          seed: seed,
                        ),
                      ),
                    ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          // The truth panel is much shorter than the numpad it replaces, so
          // without this the tray above jumps taller in a single frame —
          // exactly the kind of pop this whole change set exists to remove.
          child: AnimatedSize(
            duration: stageFade,
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _waiting
                ? _TruthPanel(a: a, b: b, product: spec.fact.product)
                : controller.isChoice(spec)
                ? const SizedBox(height: 88)
                : HatchNumPad(
                    enabled: false,
                    onFirstKey: () {},
                    onSubmit: (_) {},
                  ),
          ),
        ),
      ],
    );
    if (!_waiting) return stage;
    return GestureDetector(
      key: const ValueKey('nursery-miss-continue'),
      behavior: HitTestBehavior.opaque,
      onTap: controller.feedbackDone,
      child: stage,
    );
  }
}

/// What the fact actually is, in numerals, held under the finished teaching
/// choreography. No prose: the app has never asked a child to read, and a
/// seven-year-old who just missed one is the worst possible audience for a
/// sentence. The tap chevron is the only instruction.
class _TruthPanel extends StatelessWidget {
  const _TruthPanel({required this.a, required this.b, required this.product});

  final int a;
  final int b;
  final int product;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 88,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$a×$b='),
                TextSpan(
                  text: '$product',
                  style: const TextStyle(color: AppColors.yolkDark),
                ),
              ],
            ),
            key: const ValueKey('nursery-truth'),
            style: text.displaySmall,
          ),
          const SizedBox(height: 4),
          const Icon(
            Icons.touch_app_rounded,
            size: 26,
            color: AppColors.speckle,
          ),
        ],
      ),
    );
  }
}
