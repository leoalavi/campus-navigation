/// Stub for non-web targets. Google Maps web key is never present on native.
bool hasWebGoogleMapsApiKey() => false;

/// Stub for non-web targets: the Maps JavaScript API only exists on web.
bool isWebGoogleMapsReady() => false;
