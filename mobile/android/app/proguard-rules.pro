# Flutter motoru ve eklentiler kendi tuketici kurallarini getirir; asagidakiler ek guvencedir.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**
# Play Core (deferred components) kullanilmiyor; R8 eksik sinif uyarisi vermesin.
-dontwarn com.google.android.play.core.**

# Firebase / FCM
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# mobile_scanner (ML Kit barkod)
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# camera / video_player (ExoPlayer-Media3)
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**

# video_compress (yerel paket: Transcoder)
-keep class com.example.video_compress.** { *; }
-keep class com.otaliastudios.transcoder.** { *; }
-dontwarn com.otaliastudios.transcoder.**

# flutter_secure_storage (Tink / EncryptedSharedPreferences)
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**
-dontwarn javax.annotation.**
-dontwarn com.google.errorprone.annotations.**

# permission_handler, gal, photo_manager, flutter_contacts, image_picker, url_launcher
-keep class com.baseflow.permissionhandler.** { *; }
-keep class studio.midoridesign.gal.** { *; }
-keep class com.fluttercandies.photo_manager.** { *; }
-keep class co.quis.flutter_contacts.** { *; }
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class io.flutter.plugins.urllauncher.** { *; }

# Cokme raporu icin satir numaralari ve yansima/serilestirme icin ozellikler
-keepattributes SourceFile,LineNumberTable,*Annotation*,Signature,InnerClasses,EnclosingMethod
