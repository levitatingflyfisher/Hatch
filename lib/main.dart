// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanctuary_auth_core/sanctuary_auth_core.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hatch/core/engine/engine_providers.dart';
import 'package:hatch/core/providers/core_providers.dart';
import 'package:hatch/core/router/app_router.dart';
import 'package:hatch/features/sanctuary_backup/data/backup_serializer.dart';
import 'package:hatch/shared/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Encrypted-backup wiring (sanctuary_backup_ui). Hatch is new
        // to the feature, so it gets its own isolated key material
        // (appDomain 'hatch') and its own AEAD context — no
        // legacy-compat constraint.
        sanctuaryAppDomainProvider.overrideWithValue('hatch'),
        sanctuaryBackupConfigProvider.overrideWithValue(
          SanctuaryBackupConfig(
            appId: 'hatch',
            aadContext: 'hatch-backup/v1',
            appDisplayName: 'Hatch',
            // Restore is a full destructive replace; the dialog copy says
            // exactly that, per-app rather than the package's generic line.
            confirmTitle: 'Replace every nest?',
            confirmActionLabel: 'Replace everything',
            restoreReplaceConsequence:
                'Restoring will delete every hatcher profile, their critters '
                'and hatching progress, and all practice history on this '
                'device, then replace them with the data in the backup file.',
            // Screens watch Drift streams that self-refresh on table writes
            // through the same appDatabaseProvider singleton; soundMuted
            // derives from the settings table the restore just replaced.
            // The active-profile selection lives in SharedPreferences and
            // may now point at a profile the backup doesn't contain —
            // HomeScreen detects the stale id and returns to the picker.
            onAfterRestore: (ref) {
              ref.invalidate(profilesProvider);
              ref.invalidate(soundMutedProvider);
            },
          ),
        ),
        backupSerializerProvider.overrideWith(
          (ref) => HatchBackupSerializer(ref.watch(appDatabaseProvider)),
        ),
      ],
      child: const HatchApp(),
    ),
  );
}

class HatchApp extends ConsumerStatefulWidget {
  const HatchApp({super.key});

  @override
  ConsumerState<HatchApp> createState() => _HatchAppState();
}

class _HatchAppState extends ConsumerState<HatchApp> {
  @override
  void initState() {
    super.initState();
    // Silent freshness snapshot: if a key exists and the newest vault
    // snapshot is stale, take one. Post-first-frame + fire-and-forget —
    // never blocks boot, never surfaces errors (the same hook the rest of
    // the fleet runs at startup).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(backupControllerProvider.notifier).runStartupMaintenance();
      // Kick the audio preload now so cues are warm before the first play;
      // the service itself is never load-bearing (ADR-0003).
      ref.read(audioServiceProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Hatch',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      // On wide screens keep the single-column app centered at a comfortable
      // width rather than stretching edge-to-edge (phones pass through).
      builder: (context, child) {
        Widget inner = child ?? const SizedBox.shrink();
        if (MediaQuery.of(context).size.width > 760) {
          inner = ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Center(child: SizedBox(width: 760, child: inner)),
          );
        }
        // Web autoplay unlock: prime the audio context inside the first user
        // gesture, app-wide. Retries until a cue is loaded, then latches.
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) =>
              ref.read(audioServiceProvider).unlockOnFirstGesture(),
          child: inner,
        );
      },
    );
  }
}
