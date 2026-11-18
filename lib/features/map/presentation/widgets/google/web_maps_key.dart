import 'dart:js_interop';

/// Reads `window.GOOGLE_MAPS_API_KEY` injected by `google_maps_config.js`.
@JS('GOOGLE_MAPS_API_KEY')
external JSString? get _jsGoogleMapsApiKey;

/// Outcome of the Maps JavaScript API probe in `web/flutter_bootstrap.js`:
/// `ready`, `no-key`, `auth-failed`, `timeout`, `script-error` or
/// `probe-error`.
@JS('CAMPUS_NAV_WEB_MAPS')
external JSString? get _jsWebMapsStatus;

bool hasWebGoogleMapsApiKey() {
  try {
    final key = _jsGoogleMapsApiKey;
    return key != null && key.toDart.trim().isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// True only when the Maps JavaScript API loaded AND Google accepted the key
/// for a real map. A loaded script alone is not enough: a refused key still
/// loads it, then paints Google's grey error box over the map.
bool isWebGoogleMapsReady() {
  try {
    return _jsWebMapsStatus?.toDart == 'ready' && hasWebGoogleMapsApiKey();
  } catch (_) {
    return false;
  }
}
