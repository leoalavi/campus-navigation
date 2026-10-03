import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class PendingStampNotice {
  const PendingStampNotice({
    required this.locationId,
    required this.isNewVisit,
    this.saveFailed = false,
    this.awaitingRetry = false,
  });

  final String locationId;
  final bool isNewVisit;
  final bool saveFailed;

  /// True once delivery failed and the award is parked waiting for the user
  /// to retry.
  ///
  /// The location card auto-delivers a pending award from a post-frame
  /// callback in `build`. Keeping a failed award pending (so it is not lost)
  /// therefore re-armed that callback on every rebuild, which hammered the
  /// catalog and re-raised the error forever. This flag parks the award:
  /// still pending, but no longer auto-retried — only the explicit Retry
  /// action clears it.
  final bool awaitingRetry;

  PendingStampNotice copyWith({bool? awaitingRetry}) => PendingStampNotice(
    locationId: locationId,
    isNewVisit: isNewVisit,
    saveFailed: saveFailed,
    awaitingRetry: awaitingRetry ?? this.awaitingRetry,
  );
}

class PendingStampAwardController extends Notifier<PendingStampNotice?> {
  @override
  PendingStampNotice? build() => null;

  void setNotice(PendingStampNotice notice) => state = notice;

  /// Reads the pending notice for [locationId] without clearing it.
  ///
  /// The award flow needs to know what is pending *before* it can load the
  /// stamp catalog, but the catalog load can fail. Consuming up front meant a
  /// failed load silently threw the award away with no way to get it back, so
  /// callers peek first and only [consume] once they can actually show it.
  PendingStampNotice? peek(String locationId) {
    final current = state;
    if (current == null || current.locationId != locationId) return null;
    return current;
  }

  /// Parks a pending award after a failed delivery: kept, but not auto-retried.
  void markAwaitingRetry(String locationId) {
    final current = state;
    if (current == null || current.locationId != locationId) return;
    if (current.awaitingRetry) return;
    state = current.copyWith(awaitingRetry: true);
  }

  /// Re-arms a parked award so the delivery flow will try it again.
  void resumeRetry(String locationId) {
    final current = state;
    if (current == null || current.locationId != locationId) return;
    if (!current.awaitingRetry) return;
    state = current.copyWith(awaitingRetry: false);
  }

  PendingStampNotice? consume(String locationId) {
    final current = state;
    if (current == null || current.locationId != locationId) return null;
    state = null;
    return current;
  }
}

final pendingStampAwardProvider =
    NotifierProvider<PendingStampAwardController, PendingStampNotice?>(
      PendingStampAwardController.new,
    );
