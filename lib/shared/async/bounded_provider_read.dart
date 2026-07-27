import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reads an async provider's value, returning null if it cannot answer in time.
///
/// **Why not `await provider.future`.** Verified against the vendored
/// Riverpod: a `FutureProvider`/`AsyncNotifier` whose create function throws
/// never transitions to `AsyncError` — it stays `AsyncLoading` and its
/// `.future` never completes. Awaiting it directly leaves the caller pending
/// for the life of the app, which is how a failed bundled asset turned into a
/// dead button and a scanner that silently stopped working.
///
/// Watching the [AsyncValue] instead resolves the moment the provider reaches
/// data (fast path) or error (should Riverpod ever report it), and [timeout]
/// bounds the failure mode it actually has.
///
/// Returns the value on success, or null for "could not answer" — a *transient*
/// condition callers should distinguish from a successful empty result.
/// Typed to [FutureProvider] because that is what both call sites use and
/// because Riverpod does not publicly export the broader listenable type.
Future<T?> readProviderBounded<T>(
  ProviderContainer container,
  FutureProvider<T> provider, {
  required Duration timeout,
}) async {
  final result = Completer<T?>();
  final sub = container.listen<AsyncValue<T>>(provider, (_, next) {
    if (result.isCompleted) return;
    next.whenOrNull(
      data: result.complete,
      error: (_, _) => result.complete(null),
    );
  }, fireImmediately: true);
  try {
    return await result.future.timeout(timeout, onTimeout: () => null);
  } finally {
    sub.close();
  }
}
