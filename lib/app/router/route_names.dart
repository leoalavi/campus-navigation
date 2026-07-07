/// Named route constants used throughout the app.
abstract final class RouteNames {
  static const String meet = 'meet';
  static const String notifications = 'notifications';
  static const String openDay = 'open-day';
  static const String yourDay = 'your-day';
  static const String onboarding = 'onboarding';

  // Shell tabs
  static const String home = 'home';
  static const String map = 'map';
  static const String settings = 'settings';

  // Detail screens (pushed on top of shell)
  static const String buildingDetail = 'building-detail';

  // Safety
  static const String safetyToolkit = 'safety';

  // Favorites
  static const String favorites = 'favorites';

  // QR scan
  static const String scan = 'scan';
  static const String locationDetail = 'location-detail';
  static const String locationAr = 'location-ar';
  static const String indoorPreview = 'indoor-preview';

  // Open Day stamps passport
  static const String stamps = 'stamps';
}

/// Bottom-nav branch indices for the `StatefulShellRoute` in
/// `app_router.dart`. Single source of truth for the branch order — several
/// widgets outside the router need a specific branch's index to switch to
/// it programmatically (`ScanPage` pausing its camera when its branch isn't
/// active; Home's "Scan QR" CTA jumping straight to the Scan tab via
/// `StatefulNavigationShell.goBranch`).
abstract final class ShellBranchIndex {
  static const int home = 0;
  static const int map = 1;
  static const int scan = 2;
  static const int settings = 3;
}
