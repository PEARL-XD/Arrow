import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val uploadProperties = Properties()
val uploadFile = rootProject.file("key.properties")
if (uploadFile.exists()) {
    FileInputStream(uploadFile).use { uploadProperties.load(it) }
}

android {
    namespace = "com.example.path_out"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.path_out"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (uploadFile.exists()) {
            create("upload") {
                keyAlias = uploadProperties.getProperty("keyAlias")
                keyPassword = uploadProperties.getProperty("keyPassword")
                storeFile = file(uploadProperties.getProperty("storeFile"))
                storePassword = uploadProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Never silently sign a store release with the development key.
            if (uploadFile.exists()) signingConfig = signingConfigs.getByName("upload")
        }
    }
}

gradle.taskGraph.whenReady {
    if (allTasks.any { it.project == project && it.name.contains("Release", ignoreCase = true) }) {
        check(uploadFile.exists()) { "Release signing is not configured. See docs/RELEASE.md." }
        check(android.defaultConfig.applicationId != "com.example.path_out") {
            "Choose your permanent application ID before a store release. See docs/RELEASE.md."
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
