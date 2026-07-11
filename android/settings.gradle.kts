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

// Force Built-in Kotlin onto the file_picker plugin module.
//
// file_picker 11.x ships Kotlin sources but deliberately skips applying the
// Kotlin Gradle Plugin on AGP 9 (its build.gradle guards with `isAgp9OrAbove`),
// so its `FilePickerPlugin.kt` is never compiled and the app fails with
// "cannot find symbol class FilePickerPlugin".
//
// Registered here — BEFORE the flutter-plugin-loader includes plugins — so the
// hook fires while file_picker is being *configured* (not after it is already
// evaluated), letting the Kotlin plugin apply in time.
gradle.allprojects {
    if (name == "file_picker" && !plugins.hasPlugin("org.jetbrains.kotlin.android")) {
        plugins.apply("org.jetbrains.kotlin.android")
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")
