import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/core/network/session_guard.dart';

void main() {
  test('sessionGuardProvider resolves to false instead of throwing when '
      'Supabase has not been initialized', () async {
    // No Supabase.initialize() call anywhere in this test file — this
    // pins the AssertionError-catch path in _ensureSessionBeforeWrite so
    // a write attempted before bootstrap completes fails soft instead of
    // crashing the caller.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final guard = container.read(sessionGuardProvider);
    final result = await guard();

    expect(result, isFalse);
  });
}
