import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Test-only companion package. Flutter passes --dart-define as Base64 values.
val sulfiDefines = (project.findProperty("dart-defines") as String?).orEmpty()
    .split(",").filter { it.isNotEmpty() }.map {
        String(Base64.getDecoder().decode(it))
    }.toSet()
val sulfiClientTest = sulfiDefines.contains("SULFI_EDITION=client")
val sulfiTransferProbe = sulfiDefines.contains("SULFI_TRANSFER_PROBE=true")

android {
    namespace = "ru.sulfi.sulfi_hypnotherapy"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Keep this ID stable to preserve the on-device library across upgrades.
        applicationId = (if (sulfiClientTest) "ru.sulfi.sulfi_hypnotherapy.clienttest" else "ru.sulfi.sulfi_hypnotherapy") + (if (sulfiTransferProbe) ".transferprobe" else "")
        manifestPlaceholders["sulfiAppLabel"] = if (sulfiClientTest) "Сульфи — клиент (тест)" else "Сульфи"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    if (sulfiTransferProbe) {
        sourceSets.getByName("main").java.srcDir("../../test_driver/android")
        sourceSets.getByName("debug").manifest.srcFile("../../test_driver/android/AndroidManifest.xml")
    }

    buildTypes {
        debug {
            // CI restores the EXISTING test key from a protected repository
            // secret. Never create a fresh key per user build.
            System.getenv("SULFI_SIGNING_STORE_FILE")?.let { keyPath ->
                signingConfigs.getByName("debug").apply {
                    storeFile = file(keyPath)
                    storePassword = System.getenv("SULFI_SIGNING_STORE_PASSWORD")
                    keyAlias = System.getenv("SULFI_SIGNING_KEY_ALIAS")
                    keyPassword = System.getenv("SULFI_SIGNING_KEY_PASSWORD")
                }
            }
        }
        release {
            // Official release signing will be configured separately. Never
            // distribute a release variant silently signed with a debug key.
            signingConfig = null
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    testImplementation("junit:junit:4.13.2")
}
