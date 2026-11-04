import FirebaseCore
import Flutter
import GoogleMaps
import UIKit

/// App delegate for Campus Navigation.
///
/// Plugin registration is performed by calling
/// `GeneratedPluginRegistrant.register(with: self)` at the top of
/// `application(_:didFinishLaunchingWithOptions:)`, before `super`.
///
/// Why this ordering is correct for the UIScene / `FlutterSceneDelegate`
/// architecture used by this project:
///
///   1. `GeneratedPluginRegistrant.register(with: self)` — stores plugin
///      registrars in `FlutterAppDelegate`'s registry; does **not** create
///      or run an engine at this point.
///   2. Native SDKs (Firebase, Google Maps) are configured.
///   3. `super.application(…)` triggers UIScene creation.
///   4. iOS calls `SceneDelegate.scene(_:willConnectToSession:options:)`
///      synchronously inside `super`.
///   5. `FlutterSceneDelegate` loads `Main.storyboard`, instantiating
///      `FlutterViewController`; the engine pulls pre-registered plugins from
///      the app-delegate registry so every channel is live before Dart runs.
///   6. Dart bootstrap executes.
@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register Flutter plugins before the scene is created.
    GeneratedPluginRegistrant.register(with: self)

    // ── Firebase (optional) ───────────────────────────────────────────────
    // Firebase is used exclusively for FCM push notifications.
    // Campus Navigation's primary backend is Supabase; Firebase can be absent when
    // GoogleService-Info.plist is not in the bundle (dev builds / CI without
    // secrets). The file-existence guard prevents a fatal crash so the app
    // launches normally even without a Firebase config.
    if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil,
      FirebaseApp.app() == nil
    {
      FirebaseApp.configure()
    }

    // ── Google Maps ───────────────────────────────────────────────────────
    let mapsApiKey = Self.infoPlistMapsKey()
    if !mapsApiKey.isEmpty {
      GMSServices.provideAPIKey(mapsApiKey)
    }

    // Lets Dart ask which key the SDK was actually given (mirrors Android's
    // MainActivity). Without it the Dart gate cannot tell a keyed build from
    // an unkeyed one, and an unkeyed build crashes with GMSServicesException
    // as soon as the Google Maps tab creates a map view.
    if let registrar = registrar(forPlugin: "CampusNavigationMapsConfig") {
      FlutterMethodChannel(
        name: "campus_navigation/maps_config",
        binaryMessenger: registrar.messenger()
      ).setMethodCallHandler { call, result in
        switch call.method {
        case "resolveMapsApiKey":
          result(mapsApiKey)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// `GMSApiKey` from Info.plist, filled from `$(GOOGLE_MAPS_IOS_API_KEY)` in the
  /// gitignored `ios/Flutter/Secrets.xcconfig` (written by `scripts/run.sh`).
  /// An unexpanded `$(...)` placeholder means no key was supplied.
  private static func infoPlistMapsKey() -> String {
    let raw = (Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return raw.hasPrefix("$(") ? "" : raw
  }
}
