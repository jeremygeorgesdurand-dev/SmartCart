pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version("4.4.2") apply false
    id("com.google.firebase.crashlytics") version("3.0.2") apply false
    // END: FlutterFire Configuration
    // Toujours déclaré ici (apply false) même si plus appliqué directement
    // dans android/app/build.gradle.kts (migration "built-in Kotlin" de
    // Flutter) : sans cette ligne, Gradle résout une version de Kotlin plus
    // ancienne (2.0.0, tirée des plugins tiers qui appliquent encore KGP
    // eux-mêmes) au lieu de celle-ci, redéclenchant l'avertissement
    // "Kotlin version too old" que cette migration doit justement éviter.
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
