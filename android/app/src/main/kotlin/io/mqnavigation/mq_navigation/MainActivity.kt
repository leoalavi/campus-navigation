package io.mqnavigation.mq_navigation

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Lets Dart read the Maps key the *platform* was built with, rather
        // than requiring the same key to be repeated as a --dart-define.
        // Without this, a correctly-keyed build launched by a plain
        // `flutter run` reports "no key" and silently falls back to the
        // OpenStreetMap renderer while the UI still says "Google Maps".
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MAPS_CONFIG_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "resolveMapsApiKey" -> result.success(readManifestMapsKey())
                    else -> result.notImplemented()
                }
            }
    }

    /// The key Gradle injected into the manifest placeholder. Returns "" when
    /// the build supplied none, which the Dart side treats as "unconfigured".
    private fun readManifestMapsKey(): String = try {
        val appInfo = packageManager.getApplicationInfo(
            packageName,
            PackageManager.GET_META_DATA,
        )
        appInfo.metaData?.getString(MAPS_MANIFEST_KEY).orEmpty()
    } catch (_: PackageManager.NameNotFoundException) {
        ""
    }

    private companion object {
        const val MAPS_CONFIG_CHANNEL = "campus_navigation/maps_config"
        const val MAPS_MANIFEST_KEY = "com.google.android.geo.API_KEY"
    }
}
