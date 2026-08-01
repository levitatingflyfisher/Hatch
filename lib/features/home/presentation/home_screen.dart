import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/engine/engine_providers.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/storage/app_database.dart';
import '../../profiles/domain/active_profile.dart';
import '../../profiles/domain/profile_rules.dart';
import '../../profiles/presentation/egg_avatar.dart';

/// The per-profile home: identity up top, the three big mode buttons
/// bottom-heavy and thumb-reachable, Habitats as the quieter fourth door.
/// The parent corner and settings sit small in the top row — present, never
/// competing with the child's surfaces.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeId = ref.watch(activeProfileProvider);
    final profilesAsync = ref.watch(profilesProvider);
    final profiles = profilesAsync.valueOrNull;
    final index = profiles?.indexWhere((p) => p.id == activeId) ?? -1;
    final Profile? profile = index >= 0 ? profiles![index] : null;

    // A stale active id (e.g. after a restore replaced the profiles) sends
    // the app back to the picker rather than rendering a ghost hatcher.
    if (profiles != null && profile == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ref.read(activeProfileProvider.notifier).clear();
        context.go('/profiles');
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Parent corner',
                    iconSize: 28,
                    onPressed: () => context.push('/parent'),
                    icon: const Icon(Icons.supervisor_account_outlined),
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    iconSize: 28,
                    onPressed: () => context.push('/settings'),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
              const Spacer(flex: 2),
              Text(
                'Hatch',
                style: Theme.of(context).textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (profile != null)
                _HatcherBadge(profile: profile, index: index),
              const Spacer(flex: 3),
              if (profile != null) _FreshNudgeNursery(profileId: profile.id),
              const SizedBox(height: 16),
              _ModeButton(
                label: 'Hatch Rush',
                subtitle: 'a quick race against yourself',
                onPressed: () => context.push('/rush'),
              ),
              const SizedBox(height: 16),
              _ModeButton(
                label: 'The Album',
                subtitle: 'every critter so far',
                onPressed: () => context.push('/album'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 56,
                child: OutlinedButton(
                  onPressed: () => context.push('/habitats'),
                  child: Text(
                    'Habitats',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Nursery button, with the one nudge the home allows itself: a brand-new
/// hatcher (nothing started yet) sees "start here" so the first tap lands on
/// the surface that teaches. Never a lock, never a badge — just a subtitle.
class _FreshNudgeNursery extends ConsumerWidget {
  const _FreshNudgeNursery({required this.profileId});

  final int profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serviceAsync = ref.watch(engineServiceProvider(profileId));
    final service = serviceAsync.valueOrNull;
    Widget button(String subtitle) => _ModeButton(
      label: 'The Nursery',
      subtitle: subtitle,
      onPressed: () => context.push('/nursery'),
    );
    if (service == null) return button('build & hatch');
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) => button(
        service.stats().startedCount == 0
            ? 'start here — an egg is waiting'
            : 'build & hatch',
      ),
    );
  }
}

class _HatcherBadge extends StatelessWidget {
  final Profile profile;
  final int index;

  const _HatcherBadge({required this.profile, required this.index});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Switch hatcher',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/profiles'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EggAvatar(
              glyphSeed: profile.glyphSeed,
              paletteIndex: profile.paletteIndex,
              size: 88,
            ),
            const SizedBox(height: 8),
            Text(
              profileDisplayName(profile, index),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final VoidCallback onPressed;

  const _ModeButton({
    required this.label,
    required this.subtitle,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: FilledButton.tonal(
        onPressed: onPressed,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleLarge),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
