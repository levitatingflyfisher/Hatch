import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/storage/app_database.dart';
import '../domain/active_profile.dart';
import '../domain/profile_rules.dart';
import 'egg_avatar.dart';

/// The front door: "Who's hatching today?" Up to four large egg avatars plus
/// an add egg. Tap selects and goes home; long-press manages (rename/remove).
/// Eggs sit in the lower half of the screen — one-handed, child-reachable —
/// and every target is far above the 48dp floor. No typing is ever required
/// to get playing.
class ProfilePickerScreen extends ConsumerWidget {
  const ProfilePickerScreen({super.key});

  static const _squareSize = 116.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profilesProvider);

    return Scaffold(
      body: SafeArea(
        // Stretch: the Scaffold hands the body loose constraints, and a
        // default (center) Column would shrink-wrap to its widest child and
        // sit top-left on wide screens. Stretch + textAlign keeps the picker
        // on the horizontal center at every width (pinned by a widget test).
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(flex: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                "Who's hatching today?",
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const Spacer(flex: 1),
            Expanded(
              flex: 6,
              child: profilesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => Center(
                  child: Text(
                    'Something went wrong opening the nest.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                data: (profiles) => _PickerGrid(profiles: profiles),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerGrid extends ConsumerWidget {
  final List<Profile> profiles;

  const _PickerGrid({required this.profiles});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      // Center, not bare Column: a scroll view places a shrink-wrapped child
      // at the start, which reads as left-aligned on tablet/desktop.
      child: Center(
        child: Column(
          children: [
            Wrap(
              spacing: 24,
              runSpacing: 24,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < profiles.length; i++)
                  _ProfileSquare(profile: profiles[i], index: i),
                if (profiles.length < kMaxProfiles) const _AddSquare(),
              ],
            ),
            if (profiles.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'Tap the egg to start hatching.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSquare extends ConsumerWidget {
  final Profile profile;
  final int index;

  const _ProfileSquare({required this.profile, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = profileDisplayName(profile, index);
    return Semantics(
      button: true,
      label: name,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await ref.read(activeProfileProvider.notifier).select(profile.id);
          if (context.mounted) context.go('/home');
        },
        onLongPress: () => _showManageDialog(context, ref, name),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EggAvatar(
                glyphSeed: profile.glyphSeed,
                paletteIndex: profile.paletteIndex,
                size: ProfilePickerScreen._squareSize,
              ),
              const SizedBox(height: 8),
              Text(name, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showManageDialog(
    BuildContext context,
    WidgetRef ref,
    String name,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(name),
        children: [
          SimpleDialogOption(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _showRenameDialog(context, ref, name);
            },
            child: const Text('Rename'),
          ),
          SimpleDialogOption(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _showRemoveDialog(context, ref, name);
            },
            child: Text(
              'Remove',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    String currentName,
  ) async {
    final controller = TextEditingController(text: profile.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Rename $currentName'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          decoration: const InputDecoration(hintText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName != null) {
      await ref.read(profilesDaoProvider).rename(profile.id, newName);
    }
  }

  Future<void> _showRemoveDialog(
    BuildContext context,
    WidgetRef ref,
    String name,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove $name?'),
        content: Text(
          "This deletes $name's critters and all of their practice history "
          'from this device. There is no undo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      // A removed profile can't stay active — clear before deleting so the
      // router never points home at a missing row.
      if (ref.read(activeProfileProvider) == profile.id) {
        await ref.read(activeProfileProvider.notifier).clear();
      }
      await ref.read(profilesDaoProvider).remove(profile.id);
    }
  }
}

class _AddSquare extends ConsumerWidget {
  const _AddSquare();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outline = Theme.of(context).colorScheme.outline;
    return Semantics(
      button: true,
      label: 'New hatcher',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        // Creating never requires typing: the egg appears immediately as
        // "Hatcher N" and can be renamed later from a long-press.
        onTap: () => ref.read(profilesDaoProvider).createProfile(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: ProfilePickerScreen._squareSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: outline, width: 1.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.add, size: 48, color: outline),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'New hatcher',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
