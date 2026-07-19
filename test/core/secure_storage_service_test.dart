import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mq_journey/core/security/secure_storage_service.dart';

void main() {
  test('readAll delegates to one encrypted-storage operation', () async {
    final storage = _MockFlutterSecureStorage();
    when(
      () => storage.readAll(),
    ).thenAnswer((_) async => const {'settings.theme_mode': 'dark'});
    final service = SecureStorageService(storage);

    final values = await service.readAll();

    expect(values, const {'settings.theme_mode': 'dark'});
    verify(() => storage.readAll()).called(1);
    verifyNever(() => storage.read(key: any(named: 'key')));
  });
}

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}
