package edu.bingol.bu_kampus

import android.content.Context
import android.content.Intent
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingReceiver
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

/**
 * FCM veri-only zengin bildirimi uygulama KAPALIYKEN de (surec FCM ile dogar) tamamen NATIVE cizer: Flutter motoru / Dart
 * arka plan isolate'i / eklenti cagrisi YOK. Kanallar BuApplication.onCreate'te (Dart'tan once) kurulur.
 *
 * Akis: GMS -> (1) bu servis onMessageReceived: rich + uygulama on planda DEGIL -> RichPushNotifications.show (hata olursa
 * showPlain yedek karti); on plandaysa dokunmaz (Dart on plan seridi cizer); rich olmayan her sey eklentinin
 * varsayilan davranisina gider. (2) BuFcmReceiver: rich mesajlarda eklentinin arka plan Dart motorunu BASLATMAZ.
 *
 * Dürüst sinirlar: kullanici uygulamayi "Zorla durdur" yaptiysa Android FCM yayinini uygulama yeniden acilana dek
 * iletmez; bazi ureticilerde (Xiaomi, Huawei, Oppo, Vivo, Samsung "uyuyan uygulamalar") agresif pil kisitlari sureci
 * kisitlayip gecikmeye / kayba neden olabilir; bildirim izni ya da kanal kapaliysa hicbir sey gosterilemez.
 */
class BuMessagingService : FlutterFirebaseMessagingService() {
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        var data: Map<String, String> = emptyMap()
        try {
            data = remoteMessage.data
            if (!PushSpec.isRich(data, remoteMessage.notification != null)) {
                super.onMessageReceived(remoteMessage)
                return
            }
            if (BuApplication.foreground) return
            BuRichRender.render(applicationContext, data)
        } catch (error: Throwable) {
            // Hicbir hata FCM isleyici surecini dusurmesin; bildirim kaybolmasin: duz yedek kart.
            android.util.Log.w("RichPush", "onMessageReceived failed: " + error.javaClass.simpleName)
            try { RichPushNotifications.showPlain(applicationContext, data) } catch (_: Throwable) { }
        }
    }
}

/** Eklentinin alicisi: rich + arka plan mesajda Dart motoru acilmaz (servis cizer); digerleri eklentiye gider. */
class BuFcmReceiver : FlutterFirebaseMessagingReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Tum govde korunur: eklentinin alicisi goAsync() acar ve finish()'i kendisi cagirir; burada hicbir istisna sizmamali.
        try {
            val extras = intent.extras
            if (extras != null && !BuApplication.foreground) {
                val rich = try {
                    val m = RemoteMessage(extras)
                    PushSpec.isRich(m.data, m.notification != null)
                } catch (_: Throwable) { false }
                if (rich) return
            }
            super.onReceive(context, intent)
        } catch (error: Throwable) {
            android.util.Log.w("RichPush", "FCM receiver failed: " + error.javaClass.simpleName)
        }
    }
}

object BuRichRender {
    /** Hesap eslesmesi + cizim; cizim hata verirse duz yedek kart (bildirim kaybolmasin). */
    fun render(context: Context, data: Map<String, String>) {
        if (!RichPushNotifications.canDisplay(context, data)) return
        try {
            RichPushNotifications.show(context, data, awaitMedia = true)
        } catch (error: Throwable) {
            android.util.Log.w("RichPush", "Rich render failed, plain fallback: " + error.javaClass.simpleName)
            try { RichPushNotifications.showPlain(context, data) } catch (_: Throwable) { }
        }
    }
}
