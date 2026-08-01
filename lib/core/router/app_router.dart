// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/album/presentation/album_screen.dart';
import '../../features/habitats/presentation/habitats_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/nursery/presentation/nursery_screen.dart';
import '../../features/parent/presentation/parent_screen.dart';
import '../../features/profiles/domain/active_profile.dart';
import '../../features/profiles/presentation/profile_picker_screen.dart';
import '../../features/rush/presentation/rush_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

part 'app_router.g.dart';

CustomTransitionPage<T> _fade<T>({
  required LocalKey key,
  required Widget child,
}) => CustomTransitionPage<T>(
  key: key,
  child: child,
  transitionDuration: const Duration(milliseconds: 350),
  transitionsBuilder: (_, a, __, c) => FadeTransition(
    opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
    child: c,
  ),
);

CustomTransitionPage<T> _slideUp<T>({
  required LocalKey key,
  required Widget child,
}) => CustomTransitionPage<T>(
  key: key,
  child: child,
  transitionDuration: const Duration(milliseconds: 320),
  transitionsBuilder: (_, a, __, c) => SlideTransition(
    position: Tween(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
    child: c,
  ),
);

/// Locations that only make sense with a hatcher selected.
const _perProfile = {
  '/home',
  '/nursery',
  '/rush',
  '/album',
  '/habitats',
  '/parent',
};

@riverpod
GoRouter appRouter(Ref ref) {
  // Guarded by the redirect: builders for per-profile routes only run with a
  // profile active, so the bang is safe.
  int pid() => ref.read(activeProfileProvider)!;
  return GoRouter(
    initialLocation: '/profiles',
    redirect: (context, state) {
      // Per-profile surfaces go back to the picker when no hatcher is
      // selected. /profiles and /settings stay reachable profile-less on
      // purpose — a fresh install restores a backup from Settings before any
      // profile exists. Read (not watch): rebuilding the router on profile
      // change would reset navigation to the initial location.
      final active = ref.read(activeProfileProvider);
      if (active == null && _perProfile.contains(state.matchedLocation)) {
        return '/profiles';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/profiles',
        pageBuilder: (c, s) =>
            _fade(key: s.pageKey, child: const ProfilePickerScreen()),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (c, s) => _fade(key: s.pageKey, child: const HomeScreen()),
      ),
      GoRoute(
        path: '/nursery',
        pageBuilder: (c, s) => _fade(
          key: s.pageKey,
          child: NurseryScreen(profileId: pid()),
        ),
      ),
      GoRoute(
        path: '/rush',
        pageBuilder: (c, s) => _fade(
          key: s.pageKey,
          child: RushScreen(profileId: pid()),
        ),
      ),
      GoRoute(
        path: '/album',
        pageBuilder: (c, s) => _fade(
          key: s.pageKey,
          child: AlbumScreen(profileId: pid()),
        ),
      ),
      GoRoute(
        path: '/habitats',
        pageBuilder: (c, s) => _fade(
          key: s.pageKey,
          child: HabitatsScreen(profileId: pid()),
        ),
      ),
      GoRoute(
        path: '/parent',
        pageBuilder: (c, s) => _slideUp(
          key: s.pageKey,
          child: ParentScreen(profileId: pid()),
        ),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (c, s) =>
            _slideUp(key: s.pageKey, child: const SettingsScreen()),
      ),
    ],
  );
}
