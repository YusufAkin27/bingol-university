import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// FCM: google-services.json yoksa (git'te degildir) eklenti uygulanmaz, derleme bozulmaz; push calismaz.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.warn("UYARI: android/app/google-services.json yok; Firebase/push bu derlemede devre disi.")
}

// Imza: android/key.properties (git'te degil; sablon key.properties.example). Bkz. docs/ANDROID_RELEASE.md
val keyProps = Properties()
val keyPropsFile = rootProject.file("key.properties")
val hasReleaseKey = keyPropsFile.exists()
if (hasReleaseKey) {
    // UTF-8 oku (Properties.load varsayilani ISO-8859-1: "Cevik" gibi Turkce karakterli yollari bozar)
    keyPropsFile.reader(Charsets.UTF_8).use { keyProps.load(it) }
    // key.properties var ama alanlar eksik ya da keystore dosyasi yoksa sessizce debug'a dusmeyelim: acik hata.
    val missing = listOf("storeFile", "storePassword", "keyAlias", "keyPassword").filter { keyProps.getProperty(it).isNullOrBlank() }
    if (missing.isNotEmpty()) throw GradleException("key.properties eksik alan: $missing")
    if (!rootProject.file(keyProps.getProperty("storeFile")).exists()) {
        throw GradleException("key.properties storeFile bulunamadi: ${keyProps.getProperty("storeFile")}")
    }
}

// `flutter build ... --dart-define=ALLOW_INSECURE_API=true` (ya da -Pbu.cleartext=true) ise duz http'ye izin verilir.
val dartDefines: List<String> =
    ((project.findProperty("dart-defines") as String?) ?: "")
        .split(",")
        .filter { it.isNotBlank() }
        .mapNotNull { runCatching { String(Base64.getDecoder().decode(it), Charsets.UTF_8) }.getOrNull() }
val allowCleartext = dartDefines.contains("ALLOW_INSECURE_API=true") || project.findProperty("bu.cleartext") == "true"

android {
    namespace = "edu.bingol.bu_kampus"
    // permission_handler_android 13 compileSdk 37 ister; AGP 9.1 en fazla 36 onerir (uyari bastirilir)
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Dis kimlik (Play/Firebase). namespace (kaynak paketi) bilincli olarak ayri kalir: kaynak tasimaya gerek yok.
        applicationId = "tr.com.bukampus.app"
        // 24: video_player, camera, mobile_scanner (ML Kit) gereksinimlerini karsilar
        minSdk = flutter.minSdkVersion
        targetSdk = 36 // Google Play hedef API (Android 16); Flutter varsayilani da 36
        // pubspec.yaml `version: 1.0.0+N` -> versionName=1.0.0, versionCode=N (her magaza yuklemesinde N artar)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["usesCleartext"] = allowCleartext.toString()
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = rootProject.file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            // Yerel gelistirme sunucusu (http) yalniz debug'da; ayrica src/debug networkSecurityConfig.
            manifestPlaceholders["usesCleartext"] = "true"
        }
        release {
            if (hasReleaseKey) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // Karar: key.properties yoksa derleme DURMAZ (gelistirici/elden test), debug anahtariyla imzalanir
                // ve net uyari basilir. Bu cikti Google Play'e YUKLENEMEZ.
                logger.warn("UYARI: android/key.properties yok; release DEBUG anahtariyla imzalaniyor. Play'e yuklenemez. docs/ANDROID_RELEASE.md")
                signingConfig = signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            isDebuggable = false
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
