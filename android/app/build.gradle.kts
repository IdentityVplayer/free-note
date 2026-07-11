plugins {
    id("com.android.application")
    // Built-in Kotlin: required so AGP 9 plugins (e.g. file_picker) ship Kotlin sources.
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.note.apps"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.note.apps"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val keystorePropertiesFile = rootProject.file("key.properties")
            if (keystorePropertiesFile.exists()) {
                // Parse key.properties with plain Kotlin (no java.util/java.io
                // imports, which Gradle's Kotlin DSL does not expose here).
                val props = keystorePropertiesFile.readLines()
                    .map { it.split("=", limit = 2) }
                    .filter { it.size == 2 }
                    .associate { it[0].trim() to it[1].trim() }
                keyAlias = props["keyAlias"]
                keyPassword = props["keyPassword"]
                storeFile = file(props["storeFile"]!!)
                storePassword = props["storePassword"]
            }
        }
    }

    buildTypes {
        release {
            // Sign release builds with the upload key (android/key.properties).
            signingConfig = signingConfigs.getByName("release")
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
