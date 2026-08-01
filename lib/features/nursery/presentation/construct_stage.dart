import 'package:flutter/material.dart';

import '../../../shared/answer/answer_input.dart';
import '../../../shared/audio/sound_cue.dart';
import '../../../shared/scene/seeded.dart';
import '../../../shared/theme/app_colors.dart';
import '../domain/construct_plan.dart';
import '../domain/nursery_controller.dart';
import 'answer_stage.dart';
import 'scene_widgets.dart';

/// The toy. STACK is fully interactive: a dispenser of row-strips the child
/// drags (or tap-taps) into the incubator frame, each snap firing the
/// skip-count plink and the running total. The seam verbs (fold / slice /
/// trim / add-a-row) are guided one-tap moves: the seam glows, one tap plays
/// the choreographed decomposition. Either way the event ends in symbolic
/// production — the numpad — with the partial-product scaffold left visible.
class ConstructStage extends StatefulWidget {
  const ConstructStage({
    super.key,
    required this.controller,
    required this.playCue,
  });

  final NurseryController controller;
  final void Function(SoundCue cue) playCue;

  @override
  State<ConstructStage> createState() => _ConstructStageState();
}

class _ConstructStageState extends State<ConstructStage>
    with TickerProviderStateMixin {
  late final ConstructPlan _plan;
  late final int _seed;
  late final Color _hue;
  int _stackRows = 0;
  bool _stripSelected = false;
  bool _movePlayed = false;
  late final AnimationController _move;
  late final AnimationController _settle;

  /// The beat between "the tray is full" and "now answer". Without it the
  /// last row's plink, the snap, and the numpad all land in the same frame,
  /// and the tray a child just built is snatched away mid-gesture — the
  /// single most jarring cut in the whole round.
  static const settleDuration = Duration(milliseconds: 520);

  @override
  void initState() {
    super.initState();
    final spec = widget.controller.current!;
    _plan = ConstructPlan.forSpec(spec);
    _seed = seedFor(spec.fact.a, spec.fact.b);
    _hue = factHue(spec.fact);
    _move = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _settle = AnimationController(vsync: this, duration: settleDuration);
    for (final done in [_move, _settle]) {
      done.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.controller.constructionComplete();
        }
      });
    }
    if (_plan.verb == ConstructVerb.stack && _plan.frameA == 0) {
      // The ×0 toy-joke: an empty tray needs no stacking.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.controller.constructionComplete();
      });
    }
  }

  @override
  void dispose() {
    _move.dispose();
    _settle.dispose();
    super.dispose();
  }

  bool get _building => widget.controller.phase == NurseryPhase.building;

  bool get _trayFull =>
      _plan.verb == ConstructVerb.stack && _stackRows >= _plan.frameA;

  /// The running total swells once as the tray fills — the beat that says
  /// "that is the whole thing" before the question arrives.
  late final Animation<double> _totalPop = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.22), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.22, end: 1.0), weight: 60),
  ]).animate(CurvedAnimation(parent: _settle, curve: Curves.easeOut));

  void _placeRow() {
    if (!_building || _plan.verb != ConstructVerb.stack) return;
    if (_stackRows >= _plan.frameA) return;
    setState(() => _stackRows++);
    widget.playCue(SoundCue.plink);
    if (_stackRows >= _plan.frameA) {
      widget.playCue(SoundCue.snap);
      // Let the child see the tray she just filled, and its total, before the
      // numpad takes the screen. constructionComplete() fires when this ends.
      _settle.forward();
    }
  }

  void _playSeamMove() {
    if (!_building || _movePlayed) return;
    setState(() => _movePlayed = true);
    widget.playCue(switch (_plan.verb) {
      ConstructVerb.fold => SoundCue.fold,
      ConstructVerb.slice || ConstructVerb.trim => SoundCue.slice,
      ConstructVerb.addRow => SoundCue.plink,
      ConstructVerb.stack => SoundCue.snap,
    });
    _move.forward();
  }

  void _onFrameTap() {
    if (_plan.verb == ConstructVerb.stack) {
      if (_stripSelected) _placeRow();
    } else {
      _playSeamMove();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final spec = controller.current;
    if (spec == null) return const SizedBox.shrink();
    final (a, b) = controller.displayFactors(spec);
    final stack = _plan.verb == ConstructVerb.stack;
    final answering = controller.phase == NurseryPhase.answering;

    final scene = AnimatedBuilder(
      animation: _move,
      builder: (context, _) => GuidedScene(
        plan: _plan,
        hue: _hue,
        seed: _seed,
        stackRows: stack ? _stackRows : 0,
        moveProgress: stack ? 0 : (answering ? 1 : _move.value),
      ),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            answering ? '$a×$b = ?' : '$a×$b',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: DragTarget<int>(
              onAcceptWithDetails: (_) => _placeRow(),
              builder: (context, candidates, rejected) => GestureDetector(
                key: const ValueKey('nursery-frame'),
                behavior: HitTestBehavior.opaque,
                onTap: _building ? _onFrameTap : null,
                child: scene,
              ),
            ),
          ),
        ),
        if (_building && stack) ...[
          SizedBox(
            height: 40,
            child: _stackRows > 0
                ? ScaleTransition(
                    scale: _totalPop,
                    child: Text(
                      '${_stackRows * b}',
                      key: const ValueKey('nursery-running-total'),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  )
                : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            // Once the frame is full the dispenser has nothing left to give;
            // it holds the layout so the tray above does not jump.
            child: _trayFull
                ? const SizedBox(height: 72)
                : _Dispenser(
                    count: b,
                    hue: _hue,
                    seed: _seed,
                    selected: _stripSelected,
                    onTap: () => setState(() => _stripSelected = true),
                  ),
          ),
        ] else if (_building) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 48),
            child: Icon(
              Icons.touch_app_rounded,
              size: 44,
              color: AppColors.yolkDark,
            ),
          ),
        ] else ...[
          if (_plan.scaffoldText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                _plan.scaffoldText,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: HatchNumPad(
              onFirstKey: controller.answerKeyPressed,
              onSubmit: (value) =>
                  controller.submitAnswer(value, production: true),
            ),
          ),
        ],
      ],
    );
  }
}

/// The row-strip source. Tap to pick it up (tap-tap mode) or drag it onto
/// the frame; both grammars place one row.
class _Dispenser extends StatelessWidget {
  const _Dispenser({
    required this.count,
    required this.hue,
    required this.seed,
    required this.selected,
    required this.onTap,
  });

  final int count;
  final Color hue;
  final int seed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strip = SizedBox(
      height: 64,
      child: CustomPaint(
        painter: RowStripPainter(count: count, hue: hue, seed: seed),
        child: const SizedBox.expand(),
      ),
    );
    return Draggable<int>(
      data: 1,
      feedback: SizedBox(
        width: 200,
        height: 52,
        child: CustomPaint(
          painter: RowStripPainter(count: count, hue: hue, seed: seed),
        ),
      ),
      child: Material(
        color: selected
            ? AppColors.yolk.withValues(alpha: 0.35)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: const ValueKey('nursery-dispenser'),
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(4), child: strip),
        ),
      ),
    );
  }
}
