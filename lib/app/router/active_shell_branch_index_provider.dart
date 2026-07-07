import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks which `StatefulShellRoute` branch index is currently active.
///
/// `AppShell` is the sole writer, updated whenever `navigationShell.currentIndex`
/// changes. Branch-root pages that stay mounted offstage in the shell's
/// `IndexedStack` (e.g. `ScanPage`) read it to detect when they've been
/// switched away from or back to.
class ActiveShellBranchIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    if (state != index) state = index;
  }
}

final activeShellBranchIndexProvider =
    NotifierProvider<ActiveShellBranchIndexNotifier, int>(
      ActiveShellBranchIndexNotifier.new,
    );
