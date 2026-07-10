import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class PendingStampNotice {
  const PendingStampNotice({
    required this.locationId,
    required this.isNewVisit,
    this.saveFailed = false,
  });

  final String locationId;
  final bool isNewVisit;
  final bool saveFailed;
}

class PendingStampAwardController extends Notifier<PendingStampNotice?> {
  @override
  PendingStampNotice? build() => null;

  void setNotice(PendingStampNotice notice) => state = notice;

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
