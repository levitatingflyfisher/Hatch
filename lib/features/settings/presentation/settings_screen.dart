import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../sanctuary_backup/presentation/backup_section.dart';

/// The parent-facing settings surface: sound, then the encrypted-backup
/// section. Deliberately reachable without an active profile — a fresh
/// install restores from here before any hatcher exists.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mutedAsync = ref.watch(soundMutedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Sound'),
            subtitle: const Text('Egg plinks and hatch chirps'),
            // The stored flag is "muted"; the switch reads as "sound on".
            value: !(mutedAsync.valueOrNull ?? false),
            onChanged: mutedAsync.hasValue
                ? (soundOn) => ref
                      .read(settingsRepositoryProvider)
                      .setSoundMuted(!soundOn)
                : null,
          ),
          const BackupSection(),
        ],
      ),
    );
  }
}
