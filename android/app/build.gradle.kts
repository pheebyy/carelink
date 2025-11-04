plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.carelink"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    //  Enable desugaring + set Java compatibility
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.carelink"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    //  Required for desugaring (fixes flutter_local_notifications issue)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Optional Kotlin standard library (helps with Java 11 compatibility)
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8")
    implementation("androidx.appcompat:appcompat:1.4.0")
}

