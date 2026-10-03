import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mq_navigation/features/auth/domain/services/auth_service.dart';
import 'package:mq_navigation/features/auth/data/repositories/auth_repository.dart';

class MockAuthService extends Mock implements AuthService {}

final _fakeResponse = AuthResponse(user: null, session: null);

void main() {
  late MockAuthService mockAuthService;
  late AuthRepository authRepository;

  setUp(() {
    mockAuthService = MockAuthService();
    authRepository = AuthRepository(authService: mockAuthService);
  });

  group('signInAnonymously', () {
    test('returns success on success', () async {
      when(
        () => mockAuthService.signInAnonymously(),
      ).thenAnswer((_) async => _fakeResponse);

      final result = await authRepository.signInAnonymously();

      expect(result.success, isTrue);
      expect(result.error, isNull);
    });

    test('returns error on AuthException', () async {
      when(() => mockAuthService.signInAnonymously()).thenThrow(
        const AuthException('Anonymous sign-in disabled', statusCode: '422'),
      );

      final result = await authRepository.signInAnonymously();

      expect(result.success, isFalse);
      expect(result.error, 'Anonymous sign-in disabled');
    });
  });

  group('isAuthenticated', () {
    test('delegates to auth service', () {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      expect(authRepository.isAuthenticated, isTrue);

      when(() => mockAuthService.isAuthenticated).thenReturn(false);
      expect(authRepository.isAuthenticated, isFalse);
    });
  });

  group('userId', () {
    test('returns userId when authenticated', () {
      final mockUser = MockUser();
      when(() => mockUser.id).thenReturn('anon-123');
      when(() => mockAuthService.currentUser).thenReturn(mockUser);

      expect(authRepository.userId, 'anon-123');
    });

    test('returns null when not authenticated', () {
      when(() => mockAuthService.currentUser).thenReturn(null);
      expect(authRepository.userId, isNull);
    });
  });

  group('userEmail', () {
    test('returns email from currentUser', () {
      final mockUser = MockUser();
      when(() => mockUser.email).thenReturn('test@mq.edu.au');
      when(() => mockAuthService.currentUser).thenReturn(mockUser);

      expect(authRepository.userEmail, 'test@mq.edu.au');
    });

    test('returns null for anonymous user', () {
      final mockUser = MockUser();
      when(() => mockUser.email).thenReturn(null);
      when(() => mockAuthService.currentUser).thenReturn(mockUser);

      expect(authRepository.userEmail, isNull);
    });
  });
}

class MockUser extends Mock implements User {}
