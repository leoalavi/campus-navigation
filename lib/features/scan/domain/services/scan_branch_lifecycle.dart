/// What the Scan bottom-nav branch's camera should do in response to an
/// active-branch-index change.
enum ScanBranchLifecycleAction { none, pause, resume }

/// Decides whether the Scan branch's camera should pause or resume when the
/// shell's active branch index changes.
///
/// The Scan tab lives inside a `StatefulShellRoute.indexedStack`, which keeps
/// every branch's widget tree mounted (just offstage) when another tab is
/// selected — unlike a pushed route, `dispose()` never runs on a tab switch.
/// This maps an index transition to the action needed to keep the camera
/// off while the tab is offstage.
ScanBranchLifecycleAction scanBranchLifecycleAction({
  required int? previousIndex,
  required int nextIndex,
  required int scanBranchIndex,
}) {
  // No known prior state (e.g. the very first emission) — nothing to react
  // to, since we can't tell whether the camera was already active or not.
  if (previousIndex == null) return ScanBranchLifecycleAction.none;
  final wasActive = previousIndex == scanBranchIndex;
  final isActive = nextIndex == scanBranchIndex;
  if (wasActive && !isActive) return ScanBranchLifecycleAction.pause;
  if (!wasActive && isActive) return ScanBranchLifecycleAction.resume;
  return ScanBranchLifecycleAction.none;
}
