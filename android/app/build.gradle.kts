import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing key: kept outside the repository, in ~/.capira/key.properties
// (or the file named by CAPIRA_KEY_PROPERTIES). Without it, release builds are
// signed with the debug key so anyone can build from source.
val keyPropertiesFile =
    System.getenv("CAPIRA_KEY_PROPERTIES")?.let(::File)
        ?: File(System.getProperty("user.home"), ".capira/key.properties")
val keyProperties =
    Properties().apply {
        if (keyPropertiesFile.exists()) keyPropertiesFile.inputStream().use(::load)
    }
val hasReleaseKey = keyProperties.getProperty("storeFile") != null

android {
    namespace = "io.github.oomerkaya.capira"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.github.oomerkaya.capira"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                signingConfigs.getByName(if (hasReleaseKey) "release" else "debug")
            isMinifyEnabled = true
            isShrinkResources = true
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
