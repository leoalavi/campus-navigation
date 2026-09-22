import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks how many focused surfaces (modal sheets, map bottom sheets) are
/// currently open, so [AppShell] can hide its persistent bottom navigation
/// while one is up.
///
/// A counter rather than a bool: sheets can legitimately overlap (a map
/// category sheet opening a building sheet on top of it), and the nav must
/// only come back once the *last* one closes. A bool would let the inner
/// sheet's dismissal restore the nav underneath the outer one.
class ShellChromeNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Call when a focused surface opens. Always pair with [release] — the
  /// safest way is `ref.read(...).guard(showMySheet())`.
  void acquire() => state = state + 1;

  void release() {
    final next = state - 1;
    // Clamp: a double-release (e.g. a sheet popped twice by a race) must not
    // drive the count negative and permanently hide the nav.
    state = next < 0 ? 0 : next;
  }

  /// Holds the nav hidden for the lifetime of [operation], releasing even if
  /// it throws or the sheet is dismissed by a gesture rather than a button.
  Future<T> guard<T>(Future<T> operation) async {
    acquire();
    try {
      return await operation;
    } finally {
      release();
    }
  }
}

final shellChromeProvider = NotifierProvider<ShellChromeNotifier, int>(
  ShellChromeNotifier.new,
);

/// Set while the map has a docked sheet up (category list, route panel).
///
/// Separate from [shellChromeProvider]'s counter because the map sheet isn't a
/// modal route with a lifetime to wrap — it is inline state that comes and
/// goes with the map's own selection, so it is mirrored rather than guarded.
class MapSheetOpenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) {
    // Callers fire this from post-frame callbacks (the map shell reports its
    // sheet state after layout, and clears it on the way out), by which point
    // the whole scope may already be torn down — e.g. leaving the tab, or a
    // widget test ending. Writing then throws UnmountedRefException.
    if (!ref.mounted) return;
    if (state != value) state = value;
  }
}

final mapSheetOpenProvider = NotifierProvider<MapSheetOpenNotifier, bool>(
  MapSheetOpenNotifier.new,
);

/// Whether the persistent bottom navigation should currently be visible.
final bottomNavVisibleProvider = Provider<bool>(
  (ref) => ref.watch(shellChromeProvider) == 0 && !ref.watch(mapSheetOpenProvider),
);
