plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "in.devh.GAYAB"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "29.0.13846066"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "in.devh.GAYAB"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = "satyendra"
            keyPassword = "satyendra"
            storeFile = file("/home/satya/JKSKEYS/urlcheck.jks")
            storePassword = "satyendra"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            
            // 1. Enable Code Shrinking (R8)
            // Removes unused code and obfuscates the APK
            isMinifyEnabled = true

            // 2. Enable Resource Shrinking
            // Removes unused resources (must be used with isMinifyEnabled)
            isShrinkResources = true

            // 3. Add ProGuard Rules
            // "proguard-android-optimize.txt" performs more aggressive optimizations than the standard file
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
