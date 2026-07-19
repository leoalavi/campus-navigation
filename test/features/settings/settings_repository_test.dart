import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mq_journey/core/security/secure_storage_service.dart';
import 'package:mq_journey/features/settings/data/repositories/settings_repository.dart';
import 'package:mq_journey/shared/models/user_preferences.dart';

class MockSecureStorageService extends Mock implements SecureStorageService {}

void main() {
  late MockSecureStorageService storage;
  late LocalSettingsRepository repository;

  setUp(() {
    storage = MockSecureStorageService();
    repository = LocalSettingsRepository(storage: storage);
    when(() => storage.readAll()).thenAnswer((_) async => const {});
    when(() => storage.write(any(), any())).thenAnswer((_) async {});
    when(() => storage.delete(any())).thenAnswer((_) async {});
  });

  group('LocalSettingsRepository commute persistence', () {
    test('saves favorite stop id and name', () async {
      const preferences = UserPreferences(
        commuteMode: 'metro',
        favoriteDirection: 'Tallawong',
        favoriteRoute: 'M1',
        favoriteStopId: '10101403',
        favoriteStopName: 'Macquarie University Station',
      );

      final saved = await repository.savePreferences(preferences);

      expect(saved, preferences);
      verify(
        () => storage.write('settings.favorite_direction', 'Tallawong'),
      ).called(1);
      verify(
        () => storage.write('settings.favorite_stop_id', '10101403'),
      ).called(1);
      verify(
        () => storage.write(
          'settings.favorite_stop_name',
          'Macquarie University Station',
        ),
      ).called(1);
    });

    test('loads favorite stop id and name', () async {
      when(() => storage.readAll()).thenAnswer(
        (_) async => const {
          'settings.commute_mode': 'bus',
          'settings.favorite_direction': 'Tallawong',
          'settings.favorite_route': '525',
          'settings.favorite_stop_id': '10101403',
          'settings.favorite_stop_name': 'Macquarie University Station',
        },
      );

      final preferences = await repository.loadPreferences();

      expect(preferences.commuteMode, 'bus');
      expect(preferences.favoriteDirection, 'Tallawong');
      expect(preferences.favoriteRoute, '525');
      expect(preferences.favoriteStopId, '10101403');
      expect(preferences.favoriteStopName, 'Macquarie University Station');
      verify(() => storage.readAll()).called(1);
      verifyNever(() => storage.read(any()));
    });

    test('normalizes invalid stored commute mode to none', () async {
      when(
        () => storage.readAll(),
      ).thenAnswer((_) async => const {'settings.commute_mode': 'ferry'});

      final preferences = await repository.loadPreferences();

      expect(preferences.commuteMode, 'none');
    });
  });
}
