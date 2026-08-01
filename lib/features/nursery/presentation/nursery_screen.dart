import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mastery_core/mastery_core.dart';

import '../../../core/engine/engine_providers.dart';
import '../../../core/engine/engine_service.dart';
import '../../../shared/audio/sound_cue.dart';
import '../../../shared/critters/critters.dart';
import '../../../shared/painters/hatch_moment.dart';
import '../../../shared/painters/spark_particles.dart';
import '../../../shared/theme/app_colors.dart';
import '../domain/nursery_controller.dart';
import 'answer_stage.dart';
import 'construct_stage.dart';
import 'vignette_stage.dart';

/// The Nursery: piecing rounds where the child builds egg trays and the
/// derived-fact strategies are taught wordlessly. Portrait thirds — round
/// progress up top, the hoop in the middle, dispenser/answer surface
/// bottom-weighted for thumbs. No scores, no timers, numerals only.
class NurseryScreen extends ConsumerWidget {
  const NurseryScreen({super.key, required this.profileId});

  final int profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(engineServiceProvider(profileId));
    final audio = ref.watch(audioServiceProvider);
    return switch (engine) {
      AsyncData(:final value) => NurseryFlow(
        service: value,
        playCue: audio.play,
      ),
      AsyncError() => Scaffold(
        body: Center(
          child: IconButton(
            iconSize: 44,
            onPressed: () => ref.invalidate(engineServiceProvider(profileId)),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
      ),
      _ => const Scaffold(body: SizedBox.shrink()),
    };
  }
}

/// The playing surface once the profile's engine is loaded. Public so tests
/// can reach the live [controller]; routing stays the coordinator's job.
class NurseryFlow extends StatefulWidget {
  const NurseryFlow({super.key, required this.service, required this.playCue});

  final EngineService service;
  final void Function(SoundCue cue) playCue;

  @override
  State<NurseryFlow> createState() => NurseryFlowState();
}

class NurseryFlowState extends State<NurseryFlow> {
  late final NurseryController controller;

  @override
  void initState() {
    super.initState();
    controller = NurseryController(widget.service, playCue: widget.playCue)
      ..startRound();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// Every branch carries a stable key, because [AnimatedSwitcher] decides
  /// "is this a new stage?" from the child's type and key. Construct
  /// deliberately keeps ONE key across building→answering: the tray the child
  /// filled lives in that widget's state, and a key change would throw it
  /// away and re-empty the frame mid-round.
  Widget _stage() {
    final current = controller.current;
    switch (controller.phase) {
      case NurseryPhase.idle:
        return const SizedBox.shrink(key: ValueKey('idle'));
      case NurseryPhase.vignette:
        return VignetteStage(
          key: const ValueKey('vignette'),
          controller: controller,
          playCue: widget.playCue,
        );
      case NurseryPhase.building:
      case NurseryPhase.answering:
        if (current == null) return const SizedBox.shrink(key: ValueKey('gap'));
        return controller.needsConstruction(current)
            ? ConstructStage(
                key: ValueKey('construct-${controller.eventIndex}'),
                controller: controller,
                playCue: widget.playCue,
              )
            : AnswerStage(
                key: ValueKey('answer-${controller.eventIndex}'),
                controller: controller,
              );
      case NurseryPhase.feedbackCorrect:
      case NurseryPhase.feedbackMiss:
        return FeedbackStage(
          key: ValueKey(
            'feedback-${controller.eventIndex}-${controller.phase.name}',
          ),
          controller: controller,
        );
      case NurseryPhase.strategyOffer:
        return StrategyOfferStage(
          key: ValueKey('offer-${controller.eventIndex}'),
          controller: controller,
        );
      case NurseryPhase.strategyPlaying:
        return StrategyPlayStage(
          key: ValueKey('play-${controller.eventIndex}'),
          controller: controller,
          playCue: widget.playCue,
        );
      case NurseryPhase.celebrating:
        return _CelebrationStage(
          key: const ValueKey('celebration'),
          controller: controller,
        );
      case NurseryPhase.hatching:
        final fact = controller.currentHatch;
        if (fact == null) return const SizedBox.shrink(key: ValueKey('gap'));
        return HatchStage(
          key: ValueKey('hatch-${controller.hatchIndex}'),
          fact: fact,
          playCue: widget.playCue,
          onContinue: controller.advanceHatch,
        );
      case NurseryPhase.done:
        return _DoneStage(key: const ValueKey('done'), controller: controller);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => Column(
                children: [
                  _TopStrip(controller: controller),
                  // Stages used to swap in a single frame, which read as the
                  // screen blinking out from under a gesture. A short fade
                  // costs nothing and makes one stage hand over to the next.
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: stageFade,
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: _stage(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round progress as egg-dots (never a bar that drains) + the close button.
class _TopStrip extends StatelessWidget {
  const _TopStrip({required this.controller});

  final NurseryController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 20,
              child: CustomPaint(
                painter: _EggDotsPainter(
                  total: controller.events.length,
                  done: controller.completedCount,
                ),
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('nursery-close'),
            tooltip: 'Close',
            iconSize: 28,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _EggDotsPainter extends CustomPainter {
  const _EggDotsPainter({required this.total, required this.done});

  final int total;
  final int done;

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    final spacing = (size.width / total).clamp(8.0, 24.0);
    final r = (spacing * 0.32).clamp(2.5, 6.0);
    final donePaint = Paint()..color = AppColors.yolk;
    final currentPaint = Paint()
      ..color = AppColors.yolkDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final pendingPaint = Paint()..color = AppColors.speckle;
    for (var i = 0; i < total; i++) {
      final center = Offset(spacing * (i + 0.5), size.height / 2);
      final oval = Rect.fromCenter(
        center: center,
        width: r * 1.7,
        height: r * 2.1,
      );
      if (i < done) {
        canvas.drawOval(oval, donePaint);
      } else if (i == done) {
        canvas.drawOval(oval.inflate(1), currentPaint);
      } else {
        canvas.drawOval(oval.deflate(r * 0.25), pendingPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_EggDotsPainter oldDelegate) =>
      oldDelegate.total != total || oldDelegate.done != done;
}

/// Tray complete: one spark burst, then on to the hatch queue. Brief on
/// purpose — the hatch moments are the signature, this is the doorway.
class _CelebrationStage extends StatefulWidget {
  const _CelebrationStage({super.key, required this.controller});

  final NurseryController controller;

  @override
  State<_CelebrationStage> createState() => _CelebrationStageState();
}

class _CelebrationStageState extends State<_CelebrationStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burst;

  @override
  void initState() {
    super.initState();
    _burst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _burst.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.controller.celebrationDone();
      }
    });
    _burst.forward();
  }

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _burst,
        builder: (context, _) => CustomPaint(
          size: const Size.square(280),
          painter: SparkBurstPainter(
            progress: _burst.value,
            seed: 7,
            count: 14,
          ),
        ),
      ),
    );
  }
}

/// THE signature moment: the fired fact's egg rocks, cracks, splits and its
/// critter pops out — full 1.2s, never rushed; tap moves to the next one.
///
/// Public because it is the payoff the whole app is built toward, and its
/// three cues (crack → hatch → chirp) are the hardest thing in here to reach
/// by playing: a fact only fires after fast, typed recall on separate
/// calendar days. Reaching it through the round is days of work, so the one
/// moment a child is promised gets a direct test instead of no test.
class HatchStage extends StatefulWidget {
  const HatchStage({
    super.key,
    required this.fact,
    required this.playCue,
    required this.onContinue,
  });

  final Fact fact;
  final void Function(SoundCue cue) playCue;
  final VoidCallback onContinue;

  @override
  State<HatchStage> createState() => HatchStageState();
}

class HatchStageState extends State<HatchStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _moment;
  var _hatchCued = false;
  var _chirpCued = false;
  var _finished = false;

  @override
  void initState() {
    super.initState();
    _moment = AnimationController(vsync: this, duration: HatchMoment.duration);
    _moment.addListener(_cueForProgress);
    _moment.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _finished = true);
      }
    });
    widget.playCue(SoundCue.crack);
    _moment.forward();
  }

  void _cueForProgress() {
    if (!_hatchCued && _moment.value >= HatchMoment.crackEnd) {
      _hatchCued = true;
      widget.playCue(SoundCue.hatch);
    }
    if (!_chirpCued && _moment.value >= 0.8) {
      _chirpCued = true;
      final chirps = [SoundCue.chirp1, SoundCue.chirp2, SoundCue.chirp3];
      widget.playCue(chirps[widget.fact.product % chirps.length]);
    }
  }

  @override
  void dispose() {
    _moment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('nursery-hatch'),
      behavior: HitTestBehavior.opaque,
      onTap: _finished ? widget.onContinue : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _moment,
            builder: (context, _) => CustomPaint(
              painter: HatchMomentPainter(
                spec: CritterSpec.of(widget.fact),
                progress: _moment.value,
              ),
            ),
          ),
          if (_finished)
            const Align(
              alignment: Alignment(0, 0.9),
              child: Icon(
                Icons.touch_app_rounded,
                size: 36,
                color: AppColors.yolkDark,
              ),
            ),
        ],
      ),
    );
  }
}

/// The round is over. A completed tray and any hatches were the whole
/// report — no scores, no stars, no tallies. Just: again, or done.
class _DoneStage extends StatelessWidget {
  const _DoneStage({super.key, required this.controller});

  final NurseryController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(flex: 3),
          SizedBox(
            height: 96,
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('nursery-again'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.yolk,
                foregroundColor: AppColors.ink,
              ),
              onPressed: controller.startRound,
              child: Text(
                'Hatch another?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            key: const ValueKey('nursery-done'),
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Done'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
