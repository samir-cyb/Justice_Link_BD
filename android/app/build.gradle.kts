plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.justice_link_user"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.justice_link_user"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode.toInt()
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Enables code shrinking (R8)
            isMinifyEnabled = true
            isShrinkResources = true

            // This loads the rules to fix the ML Kit errors
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // --- FIX: Force specific versions to prevent build errors ---
    configurations.all {
        resolutionStrategy {
            // 1. Fix "Requires Android Gradle Plugin 8.9.1" errors
            force("androidx.browser:browser:1.8.0")
            force("androidx.activity:activity-ktx:1.9.3")
            force("androidx.activity:activity:1.9.3")
            force("androidx.core:core-ktx:1.15.0")
            force("androidx.core:core:1.15.0")

            // 2. Fix "Incompatible version of Kotlin" error
            // (Forces an older version of maps-utils that doesn't use Kotlin 2.2.0)
            force("com.google.maps.android:android-maps-utils:3.8.0")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.multidex:multidex:2.0.1")

    // --- ML Kit Text Recognition (Base - Required) ---
    implementation("com.google.mlkit:text-recognition:16.0.1")

    // --- Bangla (Bengali) Support ---
    // Bangla uses the Devanagari script model in ML Kit
    implementation("com.google.mlkit:text-recognition-devanagari:16.0.1")

    // --- Other languages (Keep these to prevent build errors) ---
    implementation("com.google.mlkit:text-recognition-chinese:16.0.1")
    implementation("com.google.mlkit:text-recognition-japanese:16.0.1")
    implementation("com.google.mlkit:text-recognition-korean:16.0.1")
}
