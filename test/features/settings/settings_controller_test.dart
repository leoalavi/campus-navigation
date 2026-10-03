import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:campus_navigation/features/settings/data/repositories/settings_repository.dart';
import 'package:campus_navigation/features/settings/presentation/controllers/settings_controller.dart';
import 'package:campus_navigation/shared/models/user_preferences.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late MockSettingsRepository repository;

  setUp(() {
    repository = MockSettingsRepository();
    when(
      () => repository.loadPreferences(),
    ).thenAnswer((_) async => const UserPreferences());
    registerFallbackValue(const UserPreferences());
    when(() => repository.savePreferences(any())).thenAnswer(
      (invocation) async =>
          invocation.positionalArguments[0] as UserPreferences,
    );
    when(() => repository.wipeAllLocalData()).thenAnswer((_) async {});
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('SettingsController wiring tests', () {
    test('updateHapticsEnabled updates state and repository', () async {
      final container = createContainer();
      final controller = container.read(settingsControllerProvider.notifier);

      await controller.updateHapticsEnabled(false);

      final state = container.read(settingsControllerProvider).value;
      expect(state?.hapticsEnabled, isFalse);
      verify(
        () => repository.savePreferences(
          any(
            that: isA<UserPreferences>().having(
              (p) => p.hapticsEnabled,
              'hapticsEnabled',
              isFalse,
            ),
          ),
        ),
      ).called(1);
    });

    test('updateHighContrastMap updates state and repository', () async {
      final container = createContainer();
      final controller = container.read(settingsControllerProvider.notifier);

      await controller.updateHighContrastMap(true);

      final state = container.read(settingsControllerProvider).value;
      expect(state?.highContrastMap, isTrue);
      verify(
        () => repository.savePreferences(
          any(
            that: isA<UserPreferences>().having(
              (p) => p.highContrastMap,
              'highContrastMap',
              isTrue,
            ),
          ),
        ),
      ).called(1);
    });

    test('updateCommutePreferences updates state and repository', () async {
      final container = createContainer();
      final controller = container.read(settingsControllerProvider.notifier);

      await controller.updateCommutePreferences(
        commuteMode: 'metro',
        favoriteDirection: 'Tallawong',
        favoriteRoute: 'M1',
        favoriteStopId: '10101403',
        favoriteStopName: 'Macquarie University Station',
      );

      final state = container.read(settingsControllerProvider).value;
      expect(state?.commuteMode, 'metro');
      expect(state?.favoriteDirection, 'Tallawong');
      expect(state?.favoriteRoute, 'M1');
      expect(state?.favoriteStopId, '10101403');
      expect(state?.favoriteStopName, 'Macquarie University Station');
      verify(
        () => repository.savePreferences(
          any(
            that: isA<UserPreferences>()
                .having((p) => p.commuteMode, 'commuteMode', 'metro')
                .having(
                  (p) => p.favoriteDirection,
                  'favoriteDirection',
                  'Tallawong',
                )
                .having((p) => p.favoriteRoute, 'favoriteRoute', 'M1')
                .having((p) => p.favoriteStopId, 'favoriteStopId', '10101403')
                .having(
                  (p) => p.favoriteStopName,
                  'favoriteStopName',
                  'Macquarie University Station',
                ),
          ),
        ),
      ).called(1);
    });

    test(
      'updateCommutePreferences normalizes unsupported commute mode',
      () async {
        final container = createContainer();
        final controller = container.read(settingsControllerProvider.notifier);

        await controller.updateCommutePreferences(commuteMode: 'ferry');

        final state = container.read(settingsControllerProvider).value;
        expect(state?.commuteMode, 'none');
        verify(
          () => repository.savePreferences(
            any(
              that: isA<UserPreferences>().having(
                (p) => p.commuteMode,
                'commuteMode',
                'none',
              ),
            ),
          ),
        ).called(1);
      },
    );

    test('updateQuietHours settings updates state and repository', () async {
      final container = createContainer();
      final controller = container.read(settingsControllerProvider.notifier);

      await controller.updateQuietHoursEnabled(true);
      await controller.updateQuietHoursStart('22:00');
      await controller.updateQuietHoursEnd('07:00');

      final state = container.read(settingsControllerProvider).value;
      expect(state?.quietHoursEnabled, isTrue);
      expect(state?.quietHoursStart, '22:00');
      expect(state?.quietHoursEnd, '07:00');

      verify(() => repository.savePreferences(any())).called(3);
    });

    test('wipeAllLocalData calls repository and resets state', () async {
      final container = createContainer();
      final controller = container.read(settingsControllerProvider.notifier);

      await controller.updateLowDataMode(true);
      expect(
        container.read(settingsControllerProvider).value?.lowDataMode,
        isTrue,
      );

      when(
        () => repository.loadPreferences(),
      ).thenAnswer((_) async => const UserPreferences());

      await controller.wipeAllLocalData();

      verify(() => repository.wipeAllLocalData()).called(1);
      final state = container.read(settingsControllerProvider).value;
      expect(state?.lowDataMode, isFalse);
    });

    test('updateShowSuggestedStops updates state', () async {
      final container = createContainer();
      final controller = container.read(settingsControllerProvider.notifier);

      await controller.updateShowSuggestedStops(false);

      expect(
        container.read(settingsControllerProvider).value?.showSuggestedStops,
        isFalse,
      );
    });

    test('toggleSavedOpenDayEvent adds then removes an event', () async {
      final container = createContainer();
      final controller = container.read(settingsControllerProvider.notifier);

      await controller.toggleSavedOpenDayEvent('evt-comp-1030');
      expect(
        container.read(settingsControllerProvider).value?.savedOpenDayEventIds,
        ['evt-comp-1030'],
      );

      await controller.toggleSavedOpenDayEvent('evt-comp-1030');
      expect(
        container.read(settingsControllerProvider).value?.savedOpenDayEventIds,
        isEmpty,
      );
    });

    test('toggleSavedStop adds then removes a stop', () async {
      final container = createContainer();
      final controller = container.read(settingsControllerProvider.notifier);

      await controller.toggleSavedStop('stop-computing');
      expect(container.read(settingsControllerProvider).value?.savedStopIds, [
        'stop-computing',
      ]);

      await controller.toggleSavedStop('stop-computing');
      expect(
        container.read(settingsControllerProvider).value?.savedStopIds,
        isEmpty,
      );
    });

    test('recordLocationVisit awards once and dedupes repeat scans', () async {
      final container = createContainer();
      final controller = container.read(settingsControllerProvider.notifier);

      final first = await controller.recordLocationVisit('4rpd');
      expect(first, isTrue, reason: 'first visit is new');
      expect(
        container.read(settingsControllerProvider).value?.visitedLocationCodes,
        ['4RPD'],
        reason: 'stored upper-cased',
      );

      final second = await controller.recordLocationVisit('4RPD');
      expect(second, isFalse, reason: 'repeat scan is not new');
      expect(
        container
            .read(settingsControllerProvider)
            .value
            ?.visitedLocationCodes
            .length,
        1,
        reason: 'no duplicate visit recorded',
      );
    });

    test('clearSavedOpenDayEvents empties the itinerary', () async {
      final container = createContainer();
      final controller = container.read(settingsControllerProvider.notifier);

      await controller.toggleSavedOpenDayEvent('evt-a');
      await controller.toggleSavedOpenDayEvent('evt-b');
      expect(
        container
            .read(settingsControllerProvider)
            .value
            ?.savedOpenDayEventIds
            .length,
        2,
      );

      await controller.clearSavedOpenDayEvents();
      expect(
        container.read(settingsControllerProvider).value?.savedOpenDayEventIds,
        isEmpty,
      );
    });
  });
}
