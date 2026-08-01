import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mastery_core/mastery_core.dart';

import '../../../core/engine/engine_providers.dart';
import '../../../core/engine/engine_service.dart';
import '../../../core/providers/core_providers.dart';
import '../../../shared/answer/answer_input.dart';
import '../../../shared/critters/critters.dart';
import '../../../shared/painters/painters.dart';
import '../../../shared/scene/scene.dart';
import '../../../shared/theme/app_colors.dart';
import '../data/rush_best_store.dart';
import '../domain/rush_copy.dart';
import 'rush_controller.dart';

/// HATCH RUSH — the arcade speed round. Center: the current prompt tag with
/// its sweep/teach overlays; below: the numpad; under the hoop: the racing
/// caterpillar (self vs ghost); top-right: event dots (position in the
/// round — there is no timer, no countdown, no clock face anywhere).
class RushScreen extends ConsumerWidget {
  const RushScreen({super.key, required this.profileId});

  final int profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(engineServiceProvider(profileId));
    return engine.when(
      loading: () => const Scaffold(body: SizedBox.shrink()),
      // A broken engine load is a parent-debugging moment, not a child one:
      // stay kind, offer the way back, blame nobody.
      error: (_, _) => Scaffold(
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'The nest is napping.',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
      data: (service) => _RushBody(service: service),
    );
  }
}

class _RushBody extends ConsumerStatefulWidget {
  const _RushBody({required this.service});

  final EngineService service;

  @override
  ConsumerState<_RushBody> createState() => _RushBodyState();
}

class _RushBodyState extends ConsumerState<_RushBody>
    with TickerProviderStateMixin {
  late final RushController _controller;
  late final AnimationController _juice;
  late final ChoreographyClock _race;
  late final Ticker _ticker;
  RushPhase _seenPhase = RushPhase.assembling;

  @override
  void initState() {
    super.initState();
    _controller = RushController(
      engine: widget.service,
      bestStore: RushBestStore(ref.read(appDatabaseProvider)),
      playCue: ref.read(audioServiceProvider).play,
    )..addListener(_onControllerChange);
    _juice = AnimationController(vsync: this)..addStatusListener(_onJuiceDone);
    _race = ChoreographyClock()..start();
    _ticker = createTicker((_) => _race.tick())..start();
    // Deferred past the first build: begin() may notify synchronously (the
    // empty-round path has no await before its first notification).
    Future.microtask(_controller.begin);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChange);
    _ticker.dispose();
    _race.dispose();
    _juice.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChange() {
    final phase = _controller.phase;
    if (phase != _seenPhase) {
      _seenPhase = phase;
      switch (phase) {
        case RushPhase.sweep:
          _juice.duration = _controller.sweepTier.duration;
          _juice.forward(from: 0);
        case RushPhase.teach:
          _juice.duration = RushController.teachDuration;
          _juice.forward(from: 0);
        case RushPhase.prompt:
          // The ghost crawls in real time, so the race repaints every frame
          // while prompts are live.
          if (!_ticker.isActive) _ticker.start();
        case RushPhase.done:
          _ticker.stop();
          if (_controller.outcome != RushOutcome.goodRush) {
            _juice.duration = const Duration(milliseconds: 900);
            _juice.forward(from: 0);
          }
        case RushPhase.empty:
          _ticker.stop();
        case RushPhase.assembling:
          break;
      }
    }
    setState(() {});
  }

  void _onJuiceDone(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final phase = _controller.phase;
    if (phase == RushPhase.sweep || phase == RushPhase.teach) {
      _controller.advance();
    }
  }

  void _pop() => Navigator.of(context).maybePop();

  Color get _caterpillarHue =>
      AppColors.critterPalette[widget.service.profileId %
          AppColors.critterPalette.length];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: switch (_controller.phase) {
              RushPhase.assembling => const SizedBox.shrink(),
              RushPhase.empty => _EmptyNest(onDone: _pop),
              RushPhase.done => _TallyCard(
                controller: _controller,
                juice: _juice,
                hue: _caterpillarHue,
                onAgain: _controller.again,
                onDone: _pop,
              ),
              _ => _buildRound(context),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRound(BuildContext context) {
    final c = _controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: IconButton(
                  tooltip: 'Done',
                  iconSize: 28,
                  onPressed: _pop,
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              const Spacer(),
              _EventDots(filled: c.hatched, total: c.target),
            ],
          ),
        ),
        Expanded(child: Center(child: _buildPrompt(c))),
        // The racing line under the hoop: fills toward the finish, never
        // drains (no clock-that-drains law).
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            height: 52,
            child: ListenableBuilder(
              listenable: _race,
              builder: (_, _) => CustomPaint(
                painter: CaterpillarProgressPainter(
                  progress: c.selfProgress,
                  ghostProgress: c.ghostProgress,
                  hue: _caterpillarHue,
                  seed: widget.service.profileId,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 2),
          child: Text(
            rushGhostCopy(hasGhost: c.ghost != null),
            key: const ValueKey('rush-ghost-caption'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
          child: HatchNumPad(
            onFirstKey: c.onFirstKey,
            onSubmit: (value) => c.submit(value),
            enabled: c.phase == RushPhase.prompt,
          ),
        ),
      ],
    );
  }

  Widget _buildPrompt(RushController c) {
    final spec = c.current;
    if (spec == null) return const SizedBox.shrink();
    final look = CritterSpec.of(spec.fact);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Semantics(
          label: 'egg tag ${c.promptA} times ${c.promptB}',
          child: AnimatedBuilder(
            animation: _juice,
            builder: (_, _) => CustomPaint(
              painter: switch (c.phase) {
                RushPhase.sweep => CellFillSweepPainter(
                  a: c.promptA,
                  b: c.promptB,
                  progress: _juice.value,
                  hue: look.hue,
                  seed: look.seed,
                ),
                RushPhase.teach => ShortfallOverflowPainter(
                  choreography: c.teach!,
                  rung: c.teachRung,
                  progress: _juice.value,
                  hue: look.hue,
                  seed: look.seed,
                ),
                _ => TrayPainter(
                  a: c.promptA,
                  b: c.promptB,
                  rung: spec.rung,
                  hue: look.hue,
                  seed: look.seed,
                ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Round position as filled dots — deliberately countable, never a bar that
/// could read as time.
class _EventDots extends StatelessWidget {
  const _EventDots({required this.filled, required this.total});

  final int filled;
  final int total;

  @override
  Widget build(BuildContext context) {
    final empty = Theme.of(context).colorScheme.outlineVariant;
    return Semantics(
      label: '$filled of $total eggs hatched',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Wrap(
          spacing: 5,
          runSpacing: 5,
          alignment: WrapAlignment.end,
          children: [
            for (var i = 0; i < total; i++)
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < filled ? AppColors.yolk : empty,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TallyCard extends StatelessWidget {
  const _TallyCard({
    required this.controller,
    required this.juice,
    required this.hue,
    required this.onAgain,
    required this.onDone,
  });

  final RushController controller;
  final Animation<double> juice;
  final Color hue;
  final VoidCallback onAgain;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final outcome = controller.outcome ?? RushOutcome.goodRush;
    final celebrate = outcome != RushOutcome.goodRush;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(flex: 2),
        SizedBox(
          height: 150,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (celebrate)
                AnimatedBuilder(
                  animation: juice,
                  builder: (_, _) => CustomPaint(
                    painter: SparkBurstPainter(
                      progress: juice.value,
                      seed: 5,
                      count: 14,
                    ),
                  ),
                ),
              Center(
                child: SizedBox(
                  width: 260,
                  height: 56,
                  child: CustomPaint(
                    painter: CaterpillarProgressPainter(
                      progress: 1,
                      hue: hue,
                      seed: 5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            rushTallyCopy(outcome),
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
        ),
        const Spacer(flex: 3),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            height: 72,
            child: FilledButton(
              onPressed: onAgain,
              child: Text(
                'Again?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: onDone, child: const Text('Done')),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Not enough symbolic-ready eggs for a rush yet. Friendly redirection to
/// the Nursery — no locks, no shame, just a critter pointing the way.
class _EmptyNest extends StatelessWidget {
  const _EmptyNest({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 108,
          height: 108,
          child: CustomPaint(
            painter: CritterPainter(CritterSpec.of(const Fact(2, 3))),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            rushEmptyCopy,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        TextButton(onPressed: onDone, child: const Text('Done')),
      ],
    );
  }
}
