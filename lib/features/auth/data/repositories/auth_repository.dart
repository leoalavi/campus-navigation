import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mq_navigation/features/auth/domain/services/auth_service.dart';

class AuthRepository {
  AuthRepository({required AuthService authService})
    : _authService = authService;

  final AuthService _authService;

  String? get userId => _authService.currentUser?.id;
  String? get userEmail => _authService.currentUser?.email;
  bool get isAuthenticated => _authService.isAuthenticated;
  Stream<AuthState> get authStateChanges => _authService.authStateChanges;

  Future<AuthResult> signInAnonymously() async {
    try {
      await _authService.signInAnonymously();
      return const AuthResult(success: true);
    } on AuthException catch (e) {
      return AuthResult(success: false, error: _mapAuthError(e));
    }
  }

  String? _mapAuthError(AuthException e) {
    return e.message;
  }
}

class AuthResult {
  const AuthResult({required this.success, this.error});
  final bool success;
  final String? error;
}
