# Android release signing (Google Play)

Campus Navigation ships to Google Play with **Play App Signing**, which is
mandatory for new apps:

* **App-signing key**: held by Google. You never handle it.
* **Upload key**: yours. Every AAB you upload must be signed with it. Google
  verifies the upload signature, then re-signs the app for delivery.

The repository contains **no keystore and no passwords**. Release builds read
the upload key from your machine or from CI secrets at build time.

## What Leo / Raouf need to provide

| Name | What it is |
|---|---|
| `RELEASE_KEYSTORE_FILE` | Absolute path to the upload keystore (`.jks`) |
| `RELEASE_KEYSTORE_PASSWORD` | Keystore (store) password |
| `RELEASE_KEY_ALIAS` | Alias of the upload key inside the keystore (often `upload`) |
| `RELEASE_KEY_PASSWORD` | Key password. Optional: defaults to the store password |

If the app has **never been uploaded** to Play: create an upload keystore once
on a trusted machine, back it up (password manager / secure vault), and keep it
out of the repository:

```bash
keytool -genkeypair -v -keystore ~/keys/campus-navigation-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

If the app **already exists** in Play Console, use the upload key already
registered there (Play Console → Test and release → App integrity → App
signing shows its certificate). A lost upload key can be reset from that
page; the app-signing key is never at risk.

## Providing the values

Any one of these works (first match wins, per value):

1. **Your Gradle properties** (recommended locally), `~/.gradle/gradle.properties`:
   ```properties
   RELEASE_KEYSTORE_FILE=/Users/you/keys/campus-navigation-upload.jks
   RELEASE_KEYSTORE_PASSWORD=…
   RELEASE_KEY_ALIAS=upload
   RELEASE_KEY_PASSWORD=…
   ```
2. **Environment variables** (CI): the same four names as secrets, or
   `ORG_GRADLE_PROJECT_<NAME>`.
3. **`android/key.properties`** (gitignored, Flutter's convention):
   `storeFile=…`, `storePassword=…`, `keyAlias=…`, `keyPassword=…`.

Then build:

```bash
flutter build appbundle --release
```

## What the build does

* **Fully configured**: the AAB is signed with your upload key.
* **Partially configured** (e.g. the file path is wrong or the alias is
  missing): the build **fails** and names what is missing, never a value.
* **Not configured**: the build succeeds but the AAB is **unsigned**, with a
  warning. It cannot be uploaded. It is no longer silently debug-signed.
* **Local device testing only**: `-PALLOW_DEBUG_SIGNED_RELEASE=true` signs a
  release build with the debug key. Never upload that.

Check a bundle before uploading:

```bash
jarsigner -verify -certs build/app/outputs/bundle/release/app-release.aab
```

It should print `jar verified` and must not show `CN=Android Debug`. The
`fastlane deploy_internal` lane runs this check and refuses to upload
otherwise.

## Also required for fastlane uploads

`android/fastlane/Appfile` → `json_key_file`: a Google Play service-account
JSON with release permissions, provided via CI secrets (never committed).
