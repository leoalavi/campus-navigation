import Flutter
import UIKit

/// Scene lifecycle delegate for MQ Journey.
///
/// `FlutterSceneDelegate` (Flutter 3.24+) handles:
///   • Creating the `UIWindow` and loading `Main.storyboard`.
///   • Forwarding `UIWindowScene` lifecycle events to registered Flutter plugins
///     via `FlutterPluginSceneLifeCycleDelegate`.
///
/// Plugin registration is intentionally in `AppDelegate`, NOT here.
/// `FlutterSceneDelegate` does not conform to `FlutterImplicitEngineDelegate`
/// (it conforms to `FlutterSceneLifeCycleEngineRegistration`), so overriding
/// `didInitializeImplicitFlutterEngine` on this class would be a no-op — Flutter
/// only invokes that callback on `UIApplication.shared.delegate`.
class SceneDelegate: FlutterSceneDelegate {}
