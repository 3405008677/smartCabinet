import com.android.build.gradle.internal.api.BaseVariantOutputImpl
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties().apply {
    val localPropertiesFile = rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        localPropertiesFile.inputStream().use(::load)
    }
}

val gstAndroidRoot = localProperties.getProperty("gstAndroidRoot")
    ?: System.getenv("GSTREAMER_ROOT_ANDROID")
    ?: ""

val includeGStreamer = providers.gradleProperty("includeGStreamer")
    .map(String::toBoolean)
    .getOrElse(true)

android {
    namespace = "com.example.smart_cabinet"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.smart_cabinet"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }

    sourceSets {
        getByName("main") {
            java.srcDir("src/main/jni/src")
            if (includeGStreamer) {
                jniLibs.setSrcDirs(listOf("src/main/jniLibs"))
                assets.srcDir("src/main/jni/src/main/assets")
            } else {
                jniLibs.setSrcDirs(emptyList<String>())
            }
        }
    }

    if (includeGStreamer && (gstAndroidRoot.isBlank() || !file(gstAndroidRoot).exists())) {
        throw GradleException(
            "GStreamer Android SDK not found. Set gstAndroidRoot in android/local.properties " +
                "or GSTREAMER_ROOT_ANDROID to the extracted SDK path.",
        )
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    applicationVariants.all {
        if (buildType.name == "release") {
            outputs.all {
                (this as BaseVariantOutputImpl).outputFileName = "管管智能柜.apk"
            }
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

dependencies {
    implementation("com.github.pedroSG94.RootEncoder:library:2.7.5")
}
