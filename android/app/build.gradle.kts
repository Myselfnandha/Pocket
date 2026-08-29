import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.pocket.pocket"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.pocket.pocket"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties.getProperty("keyAlias") ?: "pocket_key"
                keyPassword = keystoreProperties.getProperty("keyPassword") ?: "pocketrelease2026"
                val storePath = keystoreProperties.getProperty("storeFile") ?: "pocket-release-key.jks"
                val targetFile = rootProject.file(storePath).takeIf { it.exists() }
                    ?: file(storePath).takeIf { it.exists() }
                    ?: file("pocket-release-key.jks")
                storeFile = targetFile
                storePassword = keystoreProperties.getProperty("storePassword") ?: "pocketrelease2026"
            } else if (file("pocket-release-key.jks").exists()) {
                keyAlias = "pocket_key"
                keyPassword = "pocketrelease2026"
                storeFile = file("pocket-release-key.jks")
                storePassword = "pocketrelease2026"
            } else {
                initWith(getByName("debug"))
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.google.android.gms:play-services-mlkit-text-recognition:19.0.0")
    implementation("androidx.core:core-ktx:1.13.1")
}
