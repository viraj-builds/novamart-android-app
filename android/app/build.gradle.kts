plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

import java.util.Properties
import java.io.FileInputStream

// Load .env from the Flutter project root so CLEVERTAP_* keys are available.
// `rootProject` is the `android/` Gradle project, so the repo root is one level
// up — `rootProject.file(".env")` would resolve to android/.env, which does not
// exist and silently leaves every CLEVERTAP_* placeholder empty.
val envFile = rootProject.file("../.env")
val properties = Properties()
if (envFile.exists()) {
    properties.load(FileInputStream(envFile))
} else {
    throw GradleException(
        "Missing .env at ${envFile.absolutePath}. CleverTap credentials cannot be " +
        "resolved, which silently disables all event and profile delivery."
    )
}

// Fail fast rather than shipping a build that cannot reach CleverTap.
listOf("CLEVERTAP_ACCOUNT_ID", "CLEVERTAP_TOKEN", "CLEVERTAP_REGION").forEach { key ->
    if (properties.getProperty(key).isNullOrBlank()) {
        throw GradleException("$key is missing or empty in ${envFile.absolutePath}")
    }
}

android {
    namespace = "com.example.sportsphere"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.sportsphere"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        manifestPlaceholders["clevertapAccountId"] = properties.getProperty("CLEVERTAP_ACCOUNT_ID") ?: ""
        manifestPlaceholders["clevertapRegion"] = properties.getProperty("CLEVERTAP_REGION") ?: ""
        manifestPlaceholders["clevertapToken"] = properties.getProperty("CLEVERTAP_TOKEN") ?: ""
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
    // Required by the CleverTap App Inbox UI (CTInboxActivity renders a
    // ViewPager2 of RecyclerViews inside a Fragment) and by the In-App
    // Header/Footer templates.
    // https://developer.clevertap.com/docs/flutter-app-inbox
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.recyclerview:recyclerview:1.3.2")
    implementation("androidx.viewpager2:viewpager2:1.1.0")
    implementation("com.google.android.material:material:1.12.0")

    // Image loading for inbox / in-app / native display media.
    implementation("com.github.bumptech.glide:glide:4.16.0")

    // Video and audio inbox messages. Media3 replaces ExoPlayer from
    // CleverTap Flutter SDK v2.5.0 onwards.
    implementation("androidx.media3:media3-exoplayer:1.3.1")
    implementation("androidx.media3:media3-exoplayer-hls:1.3.1")
    implementation("androidx.media3:media3-ui:1.3.1")
    
    // Explicitly add firebase-messaging so the app module can access RemoteMessage
    // and FirebaseMessagingService natively in MyFcmMessageListenerService.
    implementation("com.google.firebase:firebase-messaging:23.4.1")

    // CleverTap geofence and location dependencies.
    implementation("com.clevertap.android:clevertap-geofence-sdk:1.4.0")
    implementation("com.google.android.gms:play-services-location:21.0.0")
    implementation("androidx.work:work-runtime:2.7.1")
    implementation("androidx.concurrent:concurrent-futures:1.1.0")
}
