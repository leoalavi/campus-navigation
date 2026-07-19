import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mq_journey/app/router/active_shell_branch_index_provider.dart';
import 'package:mq_journey/app/router/route_names.dart';
import 'package:mq_journey/features/map/data/datasources/location_source.dart';
import 'package:mq_journey/features/map/domain/entities/route_leg.dart';
import 'package:mq_journey/features/transit/domain/entities/metro_departure.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_journey/features/transit/presentation/providers/tfnsw_provider.dart';
import 'package:mq_journey/shared/models/user_preferences.dart';

class _FakeSettingsController extends SettingsController {
  _FakeSettingsController(this._prefs);
  final UserPreferences _prefs;

  @override
  Future<UserPreferences> build() async => _prefs;
}

class _FakeLocationSource extends LocationSource {
  int requestCount = 0;

  @override
  Future<LocationSample?> getCurrentLocation() async {
    requestCount += 1;
    return const LocationSample(
      latitude: -33.7738,
      longitude: 151.1127,
      accuracy: 5,
    );
  }
}

void main() {
  test('tfnswMetroProvider yields an empty list immediately when no commute '
      'mode is configured, without touching location or network', () async {
    // commuteMode 'none' is an important early-return branch: it must avoid
    // both location acquisition and the injectable network fetcher.
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

  test('polling stops off-screen and resumes when Home returns', () async {
    final locationSource = _FakeLocationSource();
    var fetchCount = 0;
    Future<List<MetroDeparture>> fetchDepartures({
      required String favoriteDirection,
      required String favoriteRoute,
      required String favoriteStopId,
      required String mode,
      required double? latitude,
      required double? longitude,
    }) async {
      fetchCount += 1;
      return const [];
    }

    final container = ProviderContainer(
      overrides: [
        settingsControllerProvider.overrideWith(
          () => _FakeSettingsController(
            const UserPreferences(commuteMode: 'metro'),
          ),
        ),
        locationSourceProvider.overrideWithValue(locationSource),
        tfnswDeparturesFetcherProvider.overrideWithValue(fetchDepartures),
        tfnswPollIntervalProvider.overrideWithValue(
          const Duration(milliseconds: 10),
        ),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(tfnswMetroProvider, (_, _) {});
    addTearDown(sub.close);

    await _waitUntil(() => fetchCount >= 2);

    container
        .read(activeShellBranchIndexProvider.notifier)
        .setIndex(ShellBranchIndex.settings);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final settledOffScreenFetches = fetchCount;
    final settledOffScreenLocations = locationSource.requestCount;
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(fetchCount, settledOffScreenFetches);
    expect(locationSource.requestCount, settledOffScreenLocations);

    container
        .read(activeShellBranchIndexProvider.notifier)
        .setIndex(ShellBranchIndex.home);
    await _waitUntil(() => fetchCount > settledOffScreenFetches);

    expect(locationSource.requestCount, greaterThan(settledOffScreenLocations));
  });

  test(
    'a stalled departures request finishes at the configured bound',
    () async {
      final pendingResponse = Completer<http.Response>();
      var requestCount = 0;
      final client = MockClient((request) {
        requestCount += 1;
        return pendingResponse.future;
      });
      final container = ProviderContainer(
        overrides: [
          settingsControllerProvider.overrideWith(
            () => _FakeSettingsController(
              const UserPreferences(commuteMode: 'metro'),
            ),
          ),
          locationSourceProvider.overrideWithValue(_FakeLocationSource()),
          tfnswHttpClientProvider.overrideWithValue(client),
          tfnswAuthHeadersProvider.overrideWithValue(const {
            'Authorization': 'Bearer test',
            'apikey': 'test',
          }),
          tfnswRequestTimeoutProvider.overrideWithValue(
            const Duration(milliseconds: 10),
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(tfnswMetroProvider, (_, _) {});
      addTearDown(sub.close);
      addTearDown(() {
        if (!pendingResponse.isCompleted) {
          pendingResponse.complete(http.Response('[]', 200));
        }
      });

      final completedWithinBound = await container
          .read(tfnswMetroProvider.future)
          .then((_) => true)
          .timeout(const Duration(milliseconds: 100), onTimeout: () => false);

      expect(requestCount, 1);
      expect(completedWithinBound, isTrue);
    },
  );
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Condition was not reached before the test deadline');
}
