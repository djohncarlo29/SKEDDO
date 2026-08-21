import java.io.FileInputStream
import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.smartscheduler.smart_scheduler"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.smartscheduler.smart_scheduler"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (!hasReleaseKeystore) {
                throw GradleException(
                    "Release signing is not configured. Run ./build-apk.sh from the project root."
                )
            }
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }

    // Prevents AGP's JetifyTransform from being invoked on Flutter's libs.jar
    // before the Flutter Gradle plugin has generated it, which causes:
    // "Transform's input file does not exist: .../flutter/release/libs.jar"
    // See: https://github.com/flutter/flutter/issues/58247
    lint {
        checkReleaseBuilds = false
    }

}

dependencies {
    implementation("com.google.mlkit:text-recognition:16.0.1")
}

flutter {
    source = "../.."
}

// ── Patch GeneratedPluginRegistrant ──────────────────────────────────────────
// Flutter's generated registrant wraps each plugin in catch (Exception e).
// java.lang.UnsatisfiedLinkError (thrown when a native .so fails to load) is a
// java.lang.Error — not an Exception — so it escapes the catch block and kills
// the process before Dart starts.  Replacing Exception with Throwable means a
// failing plugin is logged and skipped rather than fatal.
// The patch runs AFTER Flutter's plugin-loader generates the file (config phase)
// but BEFORE javac compiles it (execution phase).
tasks.register("patchGeneratedPluginRegistrant") {
    doLast {
        val f = file("src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java")
        if (f.exists()) {
            val original = f.readText()
            val patched = original.replace("} catch (Exception e) {", "} catch (Throwable e) {")
            if (patched != original) {
                f.writeText(patched)
                println("patchGeneratedPluginRegistrant: patched ${f.name}")
            }
        }
    }
}

afterEvaluate {
    tasks.matching {
        it.name.startsWith("compile") && it.name.contains("JavaWithJavac")
    }.configureEach {
        dependsOn("patchGeneratedPluginRegistrant")
    }
}

// Android uses only the TFLite model. Keep the shared asset declaration intact
// for iOS/macOS, but remove the ONNX model from Flutter's Android asset bundle
// after Flutter assembles it and before AGP packages the release APK.
val stripAndroidOnnxAsset = tasks.register("stripAndroidOnnxAsset") {
    doLast {
        val assetRoots = listOf(
            file("${project.layout.buildDirectory.get().asFile}/intermediates/flutter/release/flutter_assets"),
            file("${project.layout.buildDirectory.get().asFile}/intermediates/assets/release/mergeReleaseAssets/flutter_assets"),
            file("${project.layout.buildDirectory.get().asFile}/intermediates/compressed_assets/release/compressReleaseAssets/out/assets/flutter_assets")
        )
        var removed = false
        for (assetRoot in assetRoots) {
            val onnxAsset = file("${assetRoot.path}/assets/models/all-MiniLM-L6-v2.onnx")
            if (onnxAsset.exists()) {
                onnxAsset.delete()
                println("stripAndroidOnnxAsset: removed ${onnxAsset.path}")
                removed = true
            }
        }
        if (!removed) {
            println("stripAndroidOnnxAsset: ONNX asset was not present in Android asset inputs")
        }
    }
}

afterEvaluate {
    tasks.matching {
        it.name == "copyFlutterAssetsRelease" ||
            it.name == "mergeReleaseAssets" ||
            it.name == "compressReleaseAssets"
    }.configureEach {
        // These tasks can copy Flutter assets after an ordinary dependency-based
        // strip task. Run the same removal as the final action of each task.
        doLast {
            val onnxPaths = listOf(
                "${project.layout.buildDirectory.get().asFile}/intermediates/flutter/release/flutter_assets/assets/models/all-MiniLM-L6-v2.onnx",
                "${project.layout.buildDirectory.get().asFile}/intermediates/assets/release/mergeReleaseAssets/flutter_assets/assets/models/all-MiniLM-L6-v2.onnx",
                "${project.layout.buildDirectory.get().asFile}/intermediates/compressed_assets/release/compressReleaseAssets/out/assets/flutter_assets/assets/models/all-MiniLM-L6-v2.onnx"
            )
            onnxPaths.map(::file).filter { it.exists() }.forEach {
                it.delete()
                println("${name}: removed ${it.path}")
            }
        }
    }
    tasks.matching { it.name == "stripAndroidOnnxAsset" }.configureEach {
        dependsOn("compileFlutterBuildRelease")
        dependsOn("copyFlutterAssetsRelease")
        dependsOn("mergeReleaseAssets")
        dependsOn("compressReleaseAssets")
    }
    tasks.matching {
        it.name == "packageRelease" || it.name == "packageReleaseBundle"
    }.configureEach {
        dependsOn(stripAndroidOnnxAsset)
    }
}
