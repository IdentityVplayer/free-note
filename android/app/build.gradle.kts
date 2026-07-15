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
            // Secret injection: prefer environment variables (CI repository
            // secrets, or a local `export` before `flutter build`). Falls back
            // to the untracked, gitignored `android/key.properties` for local
            // dev. Never commit keystore passwords — see .gitignore.
            val envAlias = System.getenv("UPLOAD_KEY_ALIAS")
            val envKeyPass = System.getenv("UPLOAD_KEY_PASSWORD")
            val envStorePass = System.getenv("UPLOAD_STORE_PASSWORD")
            val envStoreFile = System.getenv("UPLOAD_STORE_FILE")

            val props = if (envAlias != null && envKeyPass != null &&
                envStorePass != null && envStoreFile != null
            ) {
                mapOf(
                    "keyAlias" to envAlias,
                    "keyPassword" to envKeyPass,
                    "storePassword" to envStorePass,
                    "storeFile" to envStoreFile,
                )
            } else {
                val keystorePropertiesFile = rootProject.file("key.properties")
                if (!keystorePropertiesFile.exists()) {
                    null
                } else {
                    keystorePropertiesFile.readLines()
                        .map { it.split("=", limit = 2) }
                        .filter { it.size == 2 }
                        .associate { it[0].trim() to it[1].trim() }
                }
            }

            if (props != null) {
                keyAlias = props["keyAlias"]
                keyPassword = props["keyPassword"]
                storeFile = file(props["storeFile"]!!)
                storePassword = props["storePassword"]
            }
        }
    }

    buildTypes {
        release {
            // Sign release builds via injected secrets (env vars) or the
            // untracked local key.properties fallback.
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
