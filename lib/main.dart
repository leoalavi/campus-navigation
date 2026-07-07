import 'package:mq_journey/app/bootstrap/bootstrap.dart';
import 'package:mq_journey/app/mq_journey_app.dart';

/// Main entry point for the MQ Journey application.
/// Delegates immediately to the bootstrap layer which handles all asynchronous
/// setup before the Flutter framework starts building widgets.
void main() {
  bootstrap(() => const MqJourneyApp());
}
