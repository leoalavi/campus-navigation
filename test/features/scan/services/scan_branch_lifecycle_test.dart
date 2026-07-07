import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/scan/domain/services/scan_branch_lifecycle.dart';

void main() {
  const scanIndex = 2;

  test('pauses when the active branch moves away from Scan', () {
    expect(
      scanBranchLifecycleAction(
        previousIndex: scanIndex,
        nextIndex: 0,
        scanBranchIndex: scanIndex,
      ),
      ScanBranchLifecycleAction.pause,
    );
  });

  test('resumes when the active branch moves back to Scan', () {
    expect(
      scanBranchLifecycleAction(
        previousIndex: 0,
        nextIndex: scanIndex,
        scanBranchIndex: scanIndex,
      ),
      ScanBranchLifecycleAction.resume,
    );
  });

  test('does nothing when the change does not involve Scan', () {
    expect(
      scanBranchLifecycleAction(
        previousIndex: 0,
        nextIndex: 1,
        scanBranchIndex: scanIndex,
      ),
      ScanBranchLifecycleAction.none,
    );
  });

  test('does nothing on the very first index emission (no previous value)', () {
    expect(
      scanBranchLifecycleAction(
        previousIndex: null,
        nextIndex: scanIndex,
        scanBranchIndex: scanIndex,
      ),
      ScanBranchLifecycleAction.none,
    );
  });

  test('does nothing when already active and staying active', () {
    expect(
      scanBranchLifecycleAction(
        previousIndex: scanIndex,
        nextIndex: scanIndex,
        scanBranchIndex: scanIndex,
      ),
      ScanBranchLifecycleAction.none,
    );
  });
}
