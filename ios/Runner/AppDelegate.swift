import FirebaseCore
import Flutter
import UIKit

/// App delegate for MQ Journey.
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
    // MQ Journey's primary backend is Supabase; Firebase can be absent when
    // GoogleService-Info.plist is not in the bundle (dev builds / CI without
    // secrets). The file-existence guard prevents a fatal crash so the app
    // launches normally even without a Firebase config.
    if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil,
      FirebaseApp.app() == nil
    {
      FirebaseApp.configure()
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
