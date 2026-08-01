import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/engine/engine_providers.dart';
import '../../../core/engine/engine_service.dart';
import '../../../core/providers/core_providers.dart';
import '../../../shared/painters/album_painter.dart';
import '../../../shared/theme/app_colors.dart';
import '../../album/presentation/poster_share.dart';
import '../../profiles/domain/profile_rules.dart';
import 'hold_to_open_gate.dart';
import 'teaching_catalogue_screen.dart';

/// The parent corner, behind the hold-to-open gate: the child's album as a
/// mastery heatmap, engine stats in plain language, and an honest note on
/// the method.
///
/// ADR-0004 is binding here: this screen shows MASTERY STATES ONLY. Never
/// latency, never speed, never per-answer data — the engine measures those
/// invisibly and no UI, present or future, may surface them. If you are
/// adding a number to this screen, reread that ADR first.
class ParentScreen extends ConsumerWidget {
  const ParentScreen({super.key, required this.profileId});

  final int profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parent corner')),
      body: HoldToOpenGate(child: _ParentBody(profileId: profileId)),
    );
  }
}

class _ParentBody extends ConsumerWidget {
  const _ParentBody({required this.profileId});

  final int profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serviceAsync = ref.watch(engineServiceProvider(profileId));
    return switch (serviceAsync) {
      AsyncData(:final value) => _loaded(context, ref, value),
      AsyncError() => const Center(
        child: Text('Could not load progress — close and reopen the app.'),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  Widget _loaded(BuildContext context, WidgetRef ref, EngineService service) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final stats = service.stats();
        // 66 folded facts; "growing" = started but not yet automatic.
        const total = 66;
        final growing = stats.startedCount - stats.automaticCount;
        final notStarted = total - stats.startedCount;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('The album as a heatmap', style: textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Same picture your child sees: hatched critters are automatic '
              'facts, trays are facts in progress, plain cells are not '
              'started, sleepy critters are due for review.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: CustomPaint(
                    key: const Key('parent-heatmap'),
                    painter: AlbumPainter(
                      view: service.samplerView(),
                      dark: dark,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Right now', style: textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _StatLine(
                      stats.automaticCount == 1
                          ? '1 of $total facts is automatic'
                          : '${stats.automaticCount} of $total facts are '
                                'automatic',
                    ),
                    _StatLine(
                      growing == 1 ? '1 is growing' : '$growing are growing',
                    ),
                    _StatLine('$notStarted not started yet'),
                    _StatLine(
                      stats.dueCount == 0
                          ? 'No reviews waiting today'
                          : stats.dueCount == 1
                          ? '1 review waiting today'
                          : '${stats.dueCount} reviews waiting today',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('How Hatch works', style: textTheme.titleLarge),
            const SizedBox(height: 8),
            // Three sentences, honest — no miracle claims (VISION scorecard
            // language, not marketing).
            Text(
              'Hatch spreads practice across calendar days: a fact only '
              'counts as automatic after quick, correct answers on several '
              'different days, so one big session cannot fake durable '
              'memory. Sleepy critters mark facts ready for another visit — '
              'waiting is never punished and nothing decays. The schedule '
              'follows spaced-practice research, which points to steady '
              'gains over weeks, not overnight mastery.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            // Every teaching move is gated behind weeks of play — "Double
            // it!" needs four families satisfied and a fifth unlocked. A
            // parent evaluating Hatch has minutes, so the catalogue shows all
            // of it on demand. It takes no profile: there is no child data on
            // that screen at all.
            SizedBox(
              height: 56,
              child: OutlinedButton.icon(
                key: const Key('parent-teaching-catalogue'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TeachingCatalogueScreen(),
                  ),
                ),
                icon: const Icon(Icons.school_outlined),
                label: const Text('See how Hatch teaches'),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: () => _sharePoster(ref, service),
                icon: const Icon(Icons.ios_share_outlined),
                label: const Text('Share album poster'),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Backups live in Settings — a backup carries every profile on '
              'this device.',
              style: textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }

  Future<void> _sharePoster(WidgetRef ref, EngineService service) async {
    final profiles = ref.read(profilesProvider).valueOrNull ?? const [];
    final index = profiles.indexWhere((p) => p.id == profileId);
    final name = index >= 0 ? profileDisplayName(profiles[index], index) : '';
    await shareAlbumPoster(view: service.samplerView(), childName: name);
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: AppColors.yolk),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
