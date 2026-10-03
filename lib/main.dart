import 'package:campus_navigation/app/bootstrap/bootstrap.dart';
import 'package:campus_navigation/app/campus_navigation_app.dart';

/// Main entry point for the Campus Navigation application.
/// Delegates immediately to the bootstrap layer which handles all asynchronous
/// setup before the Flutter framework starts building widgets.
void main() {
  bootstrap(() => const CampusNavigationApp());
}
