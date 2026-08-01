import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/core_providers.dart';

part 'active_profile.g.dart';

/// Which hatcher is at the nest right now, persisted in SharedPreferences
/// (device-local UI state — deliberately NOT in the backup payload: restoring
/// a backup on a new device should land on the picker, not impersonate a
/// profile). Null means no one is selected and the router keeps the app on
/// the picker.
@riverpod
class ActiveProfile extends _$ActiveProfile {
  static const _prefsKey = 'active_profile_id';

  @override
  int? build() => ref.watch(sharedPreferencesProvider).getInt(_prefsKey);

  Future<void> select(int profileId) async {
    state = profileId;
    await ref.read(sharedPreferencesProvider).setInt(_prefsKey, profileId);
  }

  Future<void> clear() async {
    state = null;
    await ref.read(sharedPreferencesProvider).remove(_prefsKey);
  }
}
