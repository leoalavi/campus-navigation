import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mq_navigation/features/auth/data/repositories/auth_repository.dart';
import 'package:mq_navigation/features/auth/presentation/controllers/auth_controller.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

ProviderContainer makeContainer(AuthRepository repository) {
  return ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
  );
}

void main() {
  late MockAuthRepository mockRepository;

  setUp(() {
    mockRepository = MockAuthRepository();
  });

  group('build', () {
    test('emits authenticated state when user is authenticated', () async {
      when(() => mockRepository.isAuthenticated).thenReturn(true);
      when(() => mockRepository.userId).thenReturn('anon-123');

      final container = makeContainer(mockRepository);
      addTearDown(() => container.dispose());

      final state = container.read(authControllerProvider);
      expect(state.isAuthenticated, isTrue);
      expect(state.userId, 'anon-123');
      expect(state.isLoading, isFalse);
    });

    test('emits initial state when not authenticated', () async {
      when(() => mockRepository.isAuthenticated).thenReturn(false);
      when(() => mockRepository.userId).thenReturn(null);

      final container = makeContainer(mockRepository);
      addTearDown(() => container.dispose());

      final state = container.read(authControllerProvider);
      expect(state.isAuthenticated, isFalse);
      expect(state.userId, isNull);
      expect(state.isLoading, isFalse);
    });
  });

  group('clearError', () {
    test('clears error state', () async {
      when(() => mockRepository.isAuthenticated).thenReturn(false);

      final container = makeContainer(mockRepository);
      addTearDown(() => container.dispose());
      final controller = container.read(authControllerProvider.notifier);

      controller.clearError();

      expect(container.read(authControllerProvider).error, isNull);
    });

    test('keeps isAuthenticated unchanged after clear', () async {
      when(() => mockRepository.isAuthenticated).thenReturn(true);
      when(() => mockRepository.userId).thenReturn('anon-123');

      final container = makeContainer(mockRepository);
      addTearDown(() => container.dispose());
      final controller = container.read(authControllerProvider.notifier);

      controller.clearError();

      expect(container.read(authControllerProvider).isAuthenticated, isTrue);
    });
  });
}
