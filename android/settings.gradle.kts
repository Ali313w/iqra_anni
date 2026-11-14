try {
    val processEnvClass = Class.forName("java.lang.ProcessEnvironment")
    val envField = processEnvClass.getDeclaredField("theEnvironment")
    envField.isAccessible = true
    @Suppress("UNCHECKED_CAST")
    val envMap = envField.get(null) as MutableMap<String, String>
    envMap.remove("ANDROID_PREFS_ROOT")

    val ciEnvField = processEnvClass.getDeclaredField("theCaseInsensitiveEnvironment")
    ciEnvField.isAccessible = true
    @Suppress("UNCHECKED_CAST")
    val ciEnvMap = ciEnvField.get(null) as MutableMap<String, String>
    ciEnvMap.remove("ANDROID_PREFS_ROOT")
} catch (e: Throwable) {
    // Ignore
}

pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.1.0" apply false
}

include(":app")
