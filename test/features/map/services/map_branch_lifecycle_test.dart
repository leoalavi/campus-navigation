import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/map/domain/services/map_branch_lifecycle.dart';

void main() {
  const mapBranch = 1;

  bool reset({required int? from, required int to, bool viewerOpen = true}) =>
      shouldResetIndoorViewerOnBranchChange(
        previousIndex: from,
        nextIndex: to,
        mapBranchIndex: mapBranch,
        viewerOpen: viewerOpen,
      );

  test('resets when leaving the map tab with a scene open', () {
    // The reported bug: open a 3D scene, switch to Home, come back → black
    // frame. Tearing the viewer down on the way out is what prevents it.
    expect(reset(from: mapBranch, to: 0), isTrue);
    expect(reset(from: mapBranch, to: 2), isTrue);
    expect(reset(from: mapBranch, to: 3), isTrue);
  });

  test('does nothing when no scene is open', () {
    // Browsing the campus map or the AR picker itself — nothing to reset, and
    // resetting would needlessly clear the user's selected building.
    expect(reset(from: mapBranch, to: 0, viewerOpen: false), isFalse);
  });

  test('does nothing while staying on the map tab', () {
    // Re-tapping Journey, or any rebuild that re-emits the same index, must
    // not yank the user out of a scene they are still looking at.
    expect(reset(from: mapBranch, to: mapBranch), isFalse);
  });

  test('does nothing when arriving at the map tab', () {
    expect(reset(from: 0, to: mapBranch), isFalse);
  });

  test('does nothing on moves between two other tabs', () {
    expect(reset(from: 0, to: 3), isFalse);
  });

  test('does nothing on the first emission, when there is no prior index', () {
    expect(reset(from: null, to: 0), isFalse);
    expect(reset(from: null, to: mapBranch), isFalse);
  });
}
