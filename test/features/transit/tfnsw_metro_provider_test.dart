import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_journey/features/transit/presentation/providers/tfnsw_provider.dart';
import 'package:mq_journey/shared/models/user_preferences.dart';

class _FakeSettingsController extends SettingsController {
  _FakeSettingsController(this._prefs);
  final UserPreferences _prefs;

  @override
  Future<UserPreferences> build() async => _prefs;
}

void main() {
  test('tfnswMetroProvider yields an empty list immediately when no commute '
      'mode is configured, without touching location or network', () async {
    // commuteMode 'none' is the early-return branch in tfnswMetroProvider —
    // the only piece of this provider testable without an http client or
    // location-source injection seam (see the rest of tfnsw_provider.dart,
    // which calls http.get() directly with no DI point).
    final container = ProviderContainer(
      overrides: [
        settingsControllerProvider.overrideWith(
          () => _FakeSettingsController(
            const UserPreferences(commuteMode: 'none'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    // tfnswMetroProvider is autoDispose — an active listener is required
    // to keep it alive across the async gap, otherwise it tears itself
    // down before the stream emits its first value.
    final sub = container.listen(tfnswMetroProvider, (_, _) {});
    addTearDown(sub.close);

    final departures = await container.read(tfnswMetroProvider.future);

    expect(departures, isEmpty);
  });
}
