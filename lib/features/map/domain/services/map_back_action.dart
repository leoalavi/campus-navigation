/// What a Back gesture should do while the Campus Map is showing.
///
/// The visible Back control and the platform's own Back (Android button,
/// browser history, iOS edge swipe) must agree. Without this the system Back
/// popped the whole route while the on-screen control stepped one panel level,
/// so the same intent produced two different outcomes.
enum MapBackAction {
  /// Dismiss the location status message and nothing else.
  dismissStatusMessage,

  /// Clear the selected location, revealing the list it was opened from.
  closeLocationDetail,

  /// Leave a sub-group (e.g. Faculty of Arts) for its parent category.
  closeSubgroup,

  /// Close the root category/search panel, returning to the plain map.
  closeCategoryPanel,

  /// Nothing temporary is open — let the route pop as normal.
  popRoute,
}

/// Resolves a Back gesture against the map's current temporary state.
///
/// Ordered outermost-first, so Back peels exactly one layer per press and the
/// user can always reach [MapBackAction.popRoute] by repeating it — there is
/// no state in which the map traps them.
///
/// [hasSelectionFromList] is deliberately narrower than "something is
/// selected": a detail reached directly (a deep link, or a QR/Your Day entry
/// that *pushed* the map) has no list behind it, so Back there must fall
/// through to [MapBackAction.popRoute] and return the user to the page they
/// came from. That is the same rule the visible Back control uses to decide
/// whether to appear at all.
MapBackAction mapBackAction({
  required bool hasStatusMessage,
  required bool hasSelectionFromList,
  required bool hasSubgroup,
  required bool hasCategoryPanel,
}) {
  if (hasStatusMessage) return MapBackAction.dismissStatusMessage;
  if (hasSelectionFromList) return MapBackAction.closeLocationDetail;
  if (hasSubgroup) return MapBackAction.closeSubgroup;
  if (hasCategoryPanel) return MapBackAction.closeCategoryPanel;
  return MapBackAction.popRoute;
}
