{{flutter_js}}
{{flutter_build_config}}

// Loads the Google Maps JavaScript API before Flutter starts, so
// google_maps_flutter_web finds window.google.maps when the map is built.
//
// The key comes from the gitignored web/google_maps_config.js (written by
// scripts/run.sh from GOOGLE_MAPS_API_KEY in .env), loaded by index.html.
// With no key the app starts straight away on the OpenStreetMap fallback.
//
// A key that loads the script can still be refused when a map is created
// (Maps JavaScript API not enabled, wrong website restriction, billing off).
// Google then paints a grey "Sorry! Something went wrong" box. To keep the
// fallback instead, a hidden probe map is created first: if Google reports
// an auth failure, or no tiles arrive in time, the key is cleared and the
// app uses OpenStreetMap. The Dart side reads the outcome from
// window.CAMPUS_NAV_WEB_MAPS (see web_maps_key.dart).
(function () {
  const PROBE_TIMEOUT_MS = 6000;
  const mapsApiKey = (window.GOOGLE_MAPS_API_KEY || "").trim();
  let started = false;

  function startFlutter(status) {
    if (started) return;
    started = true;
    window.CAMPUS_NAV_WEB_MAPS = status;
    if (status !== "ready") {
      // Never hand google_maps_flutter_web a key Google has refused.
      window.GOOGLE_MAPS_API_KEY = "";
      if (status !== "no-key") {
        console.warn(
          "Google Maps JavaScript API unavailable (" + status + "); " +
            "using the OpenStreetMap map.",
        );
      }
    }
    _flutter.loader.load();
  }

  if (!mapsApiKey) {
    startFlutter("no-key");
    return;
  }

  // Google calls this global when the key is refused for a map.
  window.gm_authFailure = function () {
    startFlutter("auth-failed");
  };

  function probe() {
    const holder = document.createElement("div");
    holder.setAttribute("aria-hidden", "true");
    // Inside the viewport but invisible: Google skips rendering (and so
    // never fires tilesloaded or the auth check) for maps placed off-screen.
    holder.style.cssText =
      "position:fixed;left:0;top:0;width:64px;height:64px;" +
      "opacity:0;pointer-events:none;z-index:-1;";
    document.body.appendChild(holder);
    const timer = setTimeout(function () {
      startFlutter("timeout");
    }, PROBE_TIMEOUT_MS);
    try {
      const map = new google.maps.Map(holder, {
        center: { lat: -33.77388, lng: 151.11275 },
        zoom: 16,
        disableDefaultUI: true,
      });
      google.maps.event.addListenerOnce(map, "tilesloaded", function () {
        clearTimeout(timer);
        // Give a late auth failure a moment to win before declaring success.
        setTimeout(function () {
          holder.remove();
          startFlutter("ready");
        }, 300);
      });
    } catch (error) {
      clearTimeout(timer);
      startFlutter("probe-error");
    }
  }

  // Classic (non-async) loader: google_maps_flutter_web needs
  // google.maps.Map and friends available synchronously. Do NOT add
  // "loading=async", which switches to the incompatible lazy-import API.
  const script = document.createElement("script");
  script.src =
    "https://maps.googleapis.com/maps/api/js" +
    "?key=" + encodeURIComponent(mapsApiKey) +
    "&libraries=geometry&language=en&region=AU";
  script.async = true;
  script.defer = true;
  script.dataset.googleMapsSdk = "true";
  script.onload = function () {
    if (document.body) {
      probe();
    } else {
      window.addEventListener("DOMContentLoaded", probe);
    }
  };
  script.onerror = function () {
    startFlutter("script-error");
  };
  document.head.appendChild(script);
})();
