import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mq_navigation/features/auth/domain/services/auth_service.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockSession extends Mock implements Session {}

void main() {
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockGoTrue;
  late AuthService authService;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockGoTrue = MockGoTrueClient();
    when(() => mockSupabase.auth).thenReturn(mockGoTrue);
    authService = AuthService(supabase: mockSupabase);
  });

  group('AuthService', () {
    test('signInAnonymously calls supabase auth.signInAnonymously', () async {
      final fakeResponse = AuthResponse(user: null, session: null);
      when(
        () => mockGoTrue.signInAnonymously(),
      ).thenAnswer((_) async => fakeResponse);

      await authService.signInAnonymously();

      verify(() => mockGoTrue.signInAnonymously()).called(1);
    });

    test('isAuthenticated returns true when session exists', () {
      when(() => mockGoTrue.currentSession).thenReturn(MockSession());
      expect(authService.isAuthenticated, isTrue);
    });

    test('isAuthenticated returns false when no session', () {
      when(() => mockGoTrue.currentSession).thenReturn(null);
      expect(authService.isAuthenticated, isFalse);
    });

    test('currentUser returns user when session exists', () {
      final mockUser = MockUser();
      when(() => mockGoTrue.currentUser).thenReturn(mockUser);
      expect(authService.currentUser, mockUser);
    });

    test('currentUser returns null when no session', () {
      when(() => mockGoTrue.currentUser).thenReturn(null);
      expect(authService.currentUser, isNull);
    });
  });
}

class MockUser extends Mock implements User {}
