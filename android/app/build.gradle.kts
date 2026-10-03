import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val hasGoogleServicesJson = file("google-services.json").exists()

// Load secrets from secrets.properties if it exists
val secretsFile = rootProject.file("secrets.properties")
val secrets = Properties()
if (secretsFile.exists()) {
    secretsFile.inputStream().use { secrets.load(it) }
}

// Also load local.properties for IDE / direct flutter run fallback
val localPropertiesFile = rootProject.file("local.properties")
val localProps = Properties()
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProps.load(it) }
}

// Also load the repo-root `.env` — the single gitignored file the Flutter side
// reads via `--dart-define-from-file=.env`, so one file keys both the Dart
// build and this native manifest placeholder (same workflow as the Astronomy
// Open Night project). Parsed as KEY=VALUE, ignoring blanks and `#` comments.
val dotEnvFile = rootProject.file("../.env")
val dotEnv = Properties()
if (dotEnvFile.exists()) {
    dotEnvFile.readLines()
        .map { it.trim() }
        .filter { it.isNotEmpty() && !it.startsWith("#") && it.contains("=") }
        .forEach { line ->
            val key = line.substringBefore("=").trim()
            val value = line.substringAfter("=").trim().trim('"', '\'')
            if (key.isNotEmpty()) dotEnv.setProperty(key, value)
        }
}

val googleMapsApiKey: String =
    (secrets.getProperty("GOOGLE_MAPS_API_KEY"))
        ?: (localProps.getProperty("GOOGLE_MAPS_API_KEY"))
        ?: (dotEnv.getProperty("GOOGLE_MAPS_API_KEY"))
        ?: (project.findProperty("GOOGLE_MAPS_API_KEY") as String?).takeIf { !it.isNullOrEmpty() }
        ?: System.getenv("GOOGLE_MAPS_API_KEY").orEmpty().ifEmpty { null }
        ?: ""

if (hasGoogleServicesJson) {
    apply(plugin = "com.google.gms.google-services")
}

// ── Release-signing inputs (see the signingConfigs block below) ──────────
val keyPropertiesFile = rootProject.file("key.properties")
val keyProps = Properties()
if (keyPropertiesFile.exists()) {
    keyPropertiesFile.inputStream().use { keyProps.load(it) }
}

fun signingValue(name: String, keyPropertiesName: String): String? =
    (project.findProperty(name) as String?)?.takeIf { it.isNotBlank() }
        ?: System.getenv(name)?.takeIf { it.isNotBlank() }
        ?: keyProps.getProperty(keyPropertiesName)?.takeIf { it.isNotBlank() }

data class ReleaseSigning(
    val storeFile: String,
    val storePassword: String,
    val keyAlias: String,
    val keyPassword: String,
)

val releaseSigning: ReleaseSigning? = run {
    val storeFilePath = signingValue("RELEASE_KEYSTORE_FILE", "storeFile")
        ?: return@run null
    val storePassword = signingValue("RELEASE_KEYSTORE_PASSWORD", "storePassword")
    val keyAlias = signingValue("RELEASE_KEY_ALIAS", "keyAlias")
    val keyPassword = signingValue("RELEASE_KEY_PASSWORD", "keyPassword") ?: storePassword
    // Report missing NAMES only — never echo a secret value.
    val missing = buildList {
        if (!file(storeFilePath).exists()) add("RELEASE_KEYSTORE_FILE (file not found)")
        if (storePassword == null) add("RELEASE_KEYSTORE_PASSWORD")
        if (keyAlias == null) add("RELEASE_KEY_ALIAS")
    }
    if (missing.isNotEmpty()) {
        throw GradleException(
            "Release signing is partially configured. Missing/invalid: " +
                missing.joinToString() + ". See docs/store/ANDROID_RELEASE_SIGNING.md.",
        )
    }
    ReleaseSigning(storeFilePath, storePassword!!, keyAlias!!, keyPassword!!)
}

val allowDebugSignedRelease =
    (project.findProperty("ALLOW_DEBUG_SIGNED_RELEASE") as String?) == "true"

android {
    namespace = "io.mqnavigation.mq_navigation"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "io.mqnavigation.mq_navigation"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["googleMapsApiKey"] = googleMapsApiKey
    }

    // ── Release signing (Play upload key) ─────────────────────────────────
    // Google Play uses Play App Signing: Google holds the app-signing key and
    // this build signs with YOUR UPLOAD KEY. Nothing secret lives in the repo.
    // Each value is resolved, first match wins, from:
    //   1. Gradle property  (-PRELEASE_KEYSTORE_FILE=…, ~/.gradle/gradle.properties,
    //                         or ORG_GRADLE_PROJECT_RELEASE_KEYSTORE_FILE env var)
    //   2. plain environment variable (CI secrets): RELEASE_KEYSTORE_FILE, …
    //   3. android/key.properties (gitignored; Flutter's documented convention):
    //        storeFile=/abs/path/upload-keystore.jks
    //        storePassword=…   keyAlias=upload   keyPassword=…
    // Names: RELEASE_KEYSTORE_FILE, RELEASE_KEYSTORE_PASSWORD, RELEASE_KEY_ALIAS,
    //        RELEASE_KEY_PASSWORD (defaults to the store password if omitted).
    signingConfigs {
        create("release") {
            if (releaseSigning != null) {
                storeFile = file(releaseSigning.storeFile)
                storePassword = releaseSigning.storePassword
                keyAlias = releaseSigning.keyAlias
                keyPassword = releaseSigning.keyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = when {
                releaseSigning != null -> signingConfigs.getByName("release")
                // Explicit local opt-in only (e.g. installing a release build
                // on your own phone). Never the default: a debug-signed
                // "release" is rejected by Play and looks deceptively valid.
                allowDebugSignedRelease -> signingConfigs.getByName("debug")
                else -> {
                    logger.warn(
                        "\n⚠️  Release signing is NOT configured: this release build " +
                            "will be UNSIGNED and cannot be uploaded to Google Play.\n" +
                            "    Provide RELEASE_KEYSTORE_FILE, RELEASE_KEYSTORE_PASSWORD, " +
                            "RELEASE_KEY_ALIAS (and RELEASE_KEY_PASSWORD) — see " +
                            "docs/store/ANDROID_RELEASE_SIGNING.md.\n",
                    )
                    null
                }
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// Suppress obsolete Java source/target warnings emitted by the Flutter engine JAR (Java 8 bytecode)
tasks.withType<JavaCompile>().configureEach {
    options.compilerArgs.addAll(listOf("-Xlint:-options"))
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
