import 'package:hatch/core/providers/core_providers.dart';
import 'package:hatch/features/profiles/domain/active_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> makeContainer() async {
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('starts with no active profile on a fresh device', () async {
    final container = await makeContainer();
    expect(container.read(activeProfileProvider), isNull);
  });

  test('select persists across a controller restart', () async {
    final container = await makeContainer();
    await container.read(activeProfileProvider.notifier).select(3);
    expect(container.read(activeProfileProvider), 3);

    // A second container over the same prefs = a fresh app launch.
    final relaunched = await makeContainer();
    expect(relaunched.read(activeProfileProvider), 3);
  });

  test('clear returns to the no-profile state and persists it', () async {
    final container = await makeContainer();
    await container.read(activeProfileProvider.notifier).select(2);
    await container.read(activeProfileProvider.notifier).clear();
    expect(container.read(activeProfileProvider), isNull);

    final relaunched = await makeContainer();
    expect(relaunched.read(activeProfileProvider), isNull);
  });
}
