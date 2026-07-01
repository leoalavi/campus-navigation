import 'package:mq_journey/features/scan/domain/contracts/visited_state.dart';
import 'package:mq_journey/features/scan/domain/contracts/visit_event.dart';

abstract class ProgressApi {
  Stream<VisitedState> watch(String locationId);

  /// Records a visit. Returns `true` only when this is a confirmed *new*
  /// visit (the location wasn't already recorded), so callers can trigger
  /// a celebration exactly once per location. Idempotent: repeat calls for
  /// an already-visited location return `false` and do not re-write.
  Future<bool> recordVisit(VisitEvent event);
}
