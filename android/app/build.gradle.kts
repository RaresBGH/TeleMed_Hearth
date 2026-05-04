// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors — Native Android Build Configuration

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.telemed_k"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        // Required by Android FHIR SDK transitive dependencies (java.time desugaring)
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.telemed_k"
        // FHIR SDK requires API 28+; aligns with our rural elderly device floor (Android 9 Pie).
        minSdk = 28
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    packaging {
        resources {
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/INDEX.LIST",
                "META-INF/*.SF",
                "META-INF/*.DSA",
                "META-INF/*.RSA",
		"META-INF/ASL-2.0.txt",
		"META-INF/LGPL-3.0.txt",
            )
        }
	jniLibs {
      	  pickFirsts.add("lib/arm64-v8a/libsqlcipher.so")
        	pickFirsts.add("lib/armeabi-v7a/libsqlcipher.so")
      	  pickFirsts.add("lib/x86/libsqlcipher.so")
        	pickFirsts.add("lib/x86_64/libsqlcipher.so")
    }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // --- Core Library Desugaring (required by FHIR SDK for java.time on API < 33) ---
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // --- Google Android FHIR SDK ---
    // Local FHIR Engine: encrypted SQLite storage for Observation/Condition/Encounter resources
    implementation("com.google.android.fhir:engine:1.2.0")
    // LiteRT-LM — on-device Gemma 4 E2B inference (Google Maven)
    implementation("com.google.ai.edge.litertlm:litertlm-android:0.10.2")

    // --- SQLCipher: Encryption-at-rest for the FHIR SQLite database ---
    implementation("net.zetetic:sqlcipher-android:4.6.1@aar")
    implementation("androidx.sqlite:sqlite:2.4.0")

    // --- Kotlin Coroutines: Required for suspending native bridge functions ---
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.1")

    // --- AndroidX AppCompat: Required by FlutterFragmentActivity ---
    implementation("androidx.appcompat:appcompat:1.7.0")

    // --- OkHttp: Streaming model download with resume support ---
    implementation("com.squareup.okhttp3:okhttp:4.12.0")

    // --- ML Kit Text Recognition: ID-card OCR for login screen Ajutor flow ---
    implementation("com.google.mlkit:text-recognition:16.0.1")
    implementation("com.google.mlkit:text-recognition-latin:16.0.1")
}
