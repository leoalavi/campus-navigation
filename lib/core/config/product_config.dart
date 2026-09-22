/// Ownership, support and legal identity for Campus Navigation.
///
/// Campus Navigation is an independent product. It is not affiliated with,
/// endorsed by, or published by any university — it displays real-world campus
/// place names the way any map app does, and nothing more is implied.
///
/// Every ownership-, support- or policy-facing string in the app reads from
/// here, so there is one place to change when contact details or the published
/// policy URL are finalised.
abstract final class ProductConfig {
  /// Public product name. Must match the store listings and the native
  /// display names (CFBundleDisplayName / android:label).
  static const String appName = 'Campus Navigation';

  /// Developers, in the order they are credited publicly.
  static const List<String> developers = [
    'Leo Alavi',
    'Mohammad Raouf Abedini',
  ];

  static String get developersLine => developers.join(' and ');

  /// Year the product was first published. Used to build the copyright line.
  static const int copyrightYear = 2026;

  static String get copyright => '© $copyrightYear $developersLine';

  /// Support address shown in-app and submitted as the store support contact.
  ///
  static const String supportEmail = 'leo@leoalavi.dev';

  /// Secondary ecosystem attribution shown only in Settings → About.
  static const String ecosystemTitle = 'Part of the Syllabus Sync ecosystem';
  static const String ecosystemDescription =
      'Campus Navigation is part of the Syllabus Sync ecosystem.';
  static const String ecosystemIntegrationDescription =
      'Built to work seamlessly with Syllabus Sync through shared navigation and deep-linking.';

  /// Where the About → ecosystem row opens when tapped. Campus Navigation
  /// itself has no web app; this points at Syllabus Sync's own site, not us.
  static const String ecosystemUrl = 'https://syllabus-sync.app';

  /// Canonical privacy-policy URL.
  ///
  /// `null` until the policy is actually hosted. The UI must degrade to
  /// showing the bundled policy text rather than opening a URL that 404s, and
  /// the store listings cannot be submitted until this is set — see
  /// [isPrivacyPolicyPublished].
  static const String? privacyPolicyUrl = null;

  static bool get isPrivacyPolicyPublished =>
      privacyPolicyUrl != null && privacyPolicyUrl!.isNotEmpty;
}
