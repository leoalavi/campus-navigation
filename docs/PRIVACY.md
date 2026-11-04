# Campus Navigation — Privacy Policy

**Last reviewed:** 4 November 2026
**Developers:** Leo Alavi and Mohammad Raouf Abedini

**Publication status:** Draft for review before public release. Backend and provider retention practices, including service logs, need a final verification.

Campus Navigation is an independent mobile app for finding your way around a
university campus. It is not affiliated with, endorsed by, or published by any
university.

This draft summarises the app's current data flows. Review SDK and provider
behaviour before publishing it as a complete policy.

## The short version

* **No account.** There is no sign-up, login, password or profile.
* **No advertising.** The app contains no ads and no ad SDKs.
* **No tracking or analytics.** No analytics, attribution or crash-reporting
  SDK is bundled.
* **No sale of personal information.** Requested directions and nearby-transport lookups send coordinates to the relevant service and provider as described below.
* **No in-app location-history feature.** Coordinates leave the device for
  requested directions or nearby-stop lookups — see [Location](#location).

## What the app stores on your device

All of this stays on your phone and is deleted when you uninstall the app:

| Data | Why |
|---|---|
| Saved buildings ("favourites") | So your saved places are there next time |
| Preferences — theme, language, map style, travel mode, accessibility options | To keep the app the way you set it |
| Reminders you create | So the app can notify you at the right time |
| Cached map tiles and campus data | So the map works offline and loads quickly |

There is no account, so none of this is uploaded, backed up to us, or linked to
an identity.

## Location

Location access is **optional**. The app asks for it only when you use a
feature that needs it, and it works without it — you can browse the map, search
buildings, open 360° tours and read directions with location switched off.

When you grant it, your coordinates are used on your device to show where you
are and to orient walking directions. Requested features can also transmit
location-related information:

* **Directions** — when you ask for a route, your starting point is sent to our
  routing service, which passes it to the routing provider to calculate the
  route and returns the result.
* **Nearby stops** — when you look up transport near you, your position is sent
  to our transport service, which queries Transport for NSW Open Data.
* **Google Maps renderer** — map tile and viewport requests are handled by the
  Google Maps SDK. This review did not verify every field sent by that SDK.

The app does not save a location history. The external services' own retention
and privacy practices apply to the requests they receive; this review did not
verify a zero-retention guarantee for them. You can revoke permission in your
device settings; the map, search and 360° tours still work without it.

## Camera

The camera is used only to read Open Day QR codes, on your device. No photo or
video is captured, stored or sent anywhere.

## Network requests the app makes

The current app has no login UI, but network services can receive normal request
metadata such as IP address. Main request categories include:

* **Campus data and map tiles** — to load building information and map imagery.
* **Route directions** — when you ask for a route, start and end points are
  sent to a routing service and its provider for the selected mode.
* **Public transport times** — timetable lookups for nearby stops.

Opening "Navigate with Google Maps" hands off to the Google Maps app or
website, which is governed by Google's own privacy policy.

## Notifications

Reminders you create are scheduled and delivered **locally by your device**.
The app does not register a push token and cannot send you messages remotely.
You can turn notifications off in your device settings.

## 360° imagery

The panoramic tours are bundled with the app and shown from local files.
Authorship and reuse permissions for each image require a separate provenance
check before public distribution.

## Children

The app is intended for general audiences and does not knowingly collect
personal information from anyone, including children.

## Your choices

* Revoke location or notification permission in your device settings.
* Clear saved buildings and preferences from within the app's Settings screen.
* Uninstall the app to remove all locally stored data.

There is no user account or server-side profile in the current app flow. Service
logs and provider retention still require a final review before this policy is
published.

## Changes

The public policy URL is pending. A reviewed version should be published before
any store submission and revised when practices change.

## Contact

Questions about this policy: **leo@leoalavi.dev**
