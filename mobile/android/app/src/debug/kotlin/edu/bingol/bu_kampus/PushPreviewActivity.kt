package edu.bingol.bu_kampus

import android.app.Activity
import android.os.Bundle

/** Debug-only native preview. Never included in a release or Play build. */
class PushPreviewActivity : Activity() {
    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        val style = intent.getStringExtra("style") ?: "CHAT_DIRECT"
        val copy = when (style) {
            "CHAT_GROUP" -> "Bilgisayar Kulübü" to "Mehmet Demir · Toplantı saat 15:00'e alındı. Giriş kat seminer salonundayız."
            "CHAT_MEDIA" -> "Elif Kaya" to "Fotoğraf"
            "EVENT_REMINDER" -> "Etkinlik yarın başlıyor" to "Yapay Zekâ Atölyesi · Yarın 14:00 · Konferans Salonu"
            "EXAM" -> "Sınav hatırlatması" to "Veri Yapıları vizesi yarın 10:00 · Derslik B-204 · Yanınızda öğrenci kimliği bulundurunuz."
            "POLL" -> "Yeni anket" to "Yemekhane menüsünden memnun musunuz?"
            "FOLLOW_REQUEST" -> "Can Öztürk" to "Sana takip isteği gönderdi. Endüstri Mühendisliği · 12 ortak arkadaş"
            "SUPPORT" -> "Destek talebinize yanıt verildi" to "Öğrenci kartı vizeleme sorununuz için destek ekibi yanıt yazdı."
            "SECURITY" -> "Yeni cihazdan giriş" to "Samsung Galaxy S24 · Bingöl · Yeni cihazdan oturum açıldı."
            else -> "Ayşe Yılmaz" to "Yarınki derse geliyor musun? Kütüphanede çalışacağız."
        }
        val data = mapOf("preview" to "1", "style" to style, "title" to copy.first, "body" to copy.second,
            "type" to if (style.startsWith("CHAT")) "MESSAGE" else "SYSTEM", "conversationId" to "4",
            "messageId" to System.currentTimeMillis().toString(), "tag" to "preview-" + style,
            "count" to (intent.getStringExtra("count") ?: "1"), "locale" to "tr",
            "channelId" to if (style.startsWith("CHAT")) "chat" else "announcement")
        Thread {
            try { RichPushNotifications.show(applicationContext, data) }
            finally { runOnUiThread { finish() } }
        }.start()
    }
}
