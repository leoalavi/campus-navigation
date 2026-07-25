/// Whether the AR / 3D indoor viewer should reset to its building picker in
/// response to the shell's active-branch-index changing.
///
/// The Map tab lives inside a `StatefulShellRoute.indexedStack`, so switching
/// to another tab does NOT dispose the Map branch — it only goes offstage, and
/// `dispose()` never runs. The indoor viewer hosts an `InAppWebView` platform
/// view, whose native surface does not survive being detached and reattached:
/// coming back to the tab re-showed the same scene as an all-black frame.
///
/// Resetting to the picker on the way *out* means the webview is torn down
/// while offstage and a fresh one is built when the user picks a scene again,
/// so the viewer is never re-shown in a dead state.
bool shouldResetIndoorViewerOnBranchChange({
  required int? previousIndex,
  required int nextIndex,
  required int mapBranchIndex,
  required bool viewerOpen,
}) {
  // No known prior state (first emission) — we can't tell that the user is
  // leaving, so there is nothing to reset.
  if (previousIndex == null) return false;
  // Nothing to tear down unless a scene is actually open.
  if (!viewerOpen) return false;
  final wasActive = previousIndex == mapBranchIndex;
  final isActive = nextIndex == mapBranchIndex;
  return wasActive && !isActive;
}
