import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mq_navigation/core/logging/app_logger.dart';

/// Provider for the session guard function.
///
/// Override in tests to avoid requiring a real Supabase instance.
final sessionGuardProvider = Provider<Future<bool> Function()>((ref) {
  return _ensureSessionBeforeWrite;
});

/// Ensures a Supabase auth session exists before a write operation.
///
/// On first launch with no network, the bootstrap anonymous sign-in may
/// fail. This guard retries once before the write so the operation
/// succeeds when connectivity is restored.
///
/// Returns `true` if a session is available after the attempt.
Future<bool> _ensureSessionBeforeWrite() async {
  try {
    final auth = Supabase.instance.client.auth;
    if (auth.currentSession != null) return true;
    try {
      await auth.signInAnonymously().timeout(const Duration(seconds: 8));
      AppLogger.info('Anonymous session established on write retry');
      return true;
    } on Exception catch (e, st) {
      AppLogger.warning('Anonymous sign-in retry failed', e, st);
      return false;
    }
  } on AssertionError {
    return false;
  }
}
