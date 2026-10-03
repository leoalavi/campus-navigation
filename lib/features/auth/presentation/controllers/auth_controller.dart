import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_navigation/features/auth/data/repositories/auth_repository.dart';
import 'package:mq_navigation/features/auth/domain/services/auth_service.dart';

/// Provides the AuthRepository instance.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabase = Supabase.instance.client;
  final authService = AuthService(supabase: supabase);
  return AuthRepository(authService: authService);
});

/// Tracks auth UI state — login status, loading, and error messages.
/// Named AuthScreenState to avoid conflict with supabase_flutter's AuthState.
class AuthController extends Notifier<AuthScreenState> {
  @override
  AuthScreenState build() {
    final repository = _repository;
    if (repository.isAuthenticated) {
      return AuthScreenState.authenticated(userId: repository.userId!);
    }
    return AuthScreenState.initial();
  }

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthScreenState>(AuthController.new);

/// Auth screen UI state model.
class AuthScreenState {
  const AuthScreenState._({
    required this.isAuthenticated,
    required this.isLoading,
    this.userId,
    this.error,
  });

  factory AuthScreenState.initial() =>
      const AuthScreenState._(isAuthenticated: false, isLoading: false);

  factory AuthScreenState.authenticated({required String userId}) =>
      AuthScreenState._(
        isAuthenticated: true,
        isLoading: false,
        userId: userId,
      );

  final bool isAuthenticated;
  final bool isLoading;
  final String? userId;
  final String? error;

  AuthScreenState copyWith({bool? isLoading, String? error}) {
    return AuthScreenState._(
      isAuthenticated: isAuthenticated,
      userId: userId,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
