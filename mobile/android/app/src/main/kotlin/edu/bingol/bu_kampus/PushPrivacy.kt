package edu.bingol.bu_kampus

/**
 * Kilit ekrani gizliligi kararlari (SAF, android bagimsiz). Sabitler Notification.VISIBILITY_* ile aynidir (testte dogrulanir).
 * Kural: guvenlik/hesap/destek kartlari kilit ekraninda HER ZAMAN genel metin; sohbet yalniz kullanici "mesaj onizlemesini gizle"
 * dediginde (yerel tercih `bu.pref.hide_preview` ya da yukte `hidePreview=1`) gizlenir; varsayilan KAPALI (onizleme gorunur).
 * Birim testi: PushPrivacyTest.
 */
object PushPrivacy {
    const val VISIBILITY_PUBLIC = 1
    const val VISIBILITY_PRIVATE = 0

    /** visibility PRIVATE ise kilit ekraninda [publicText] gosterilir (publicVersion); PUBLIC ise null. */
    data class Lock(val visibility: Int, val publicText: String?)

    private val SENSITIVE = setOf("SECURITY", "MODERATION", "SUPPORT")

    fun truthy(v: String?) = v == "1" || v.equals("true", true)

    fun hideRequested(data: Map<String, String>, stored: Boolean): Boolean = stored || truthy(data["hidePreview"])

    fun isSensitive(style: String) = style in SENSITIVE

    fun lock(style: String, hidePreview: Boolean, lang: String, count: Int = 1): Lock {
        val chat = PushSpec.isChat(style)
        return if (isSensitive(style) || (chat && hidePreview)) Lock(VISIBILITY_PRIVATE, generic(style, lang, count))
        else Lock(VISIBILITY_PUBLIC, null)
    }

    fun generic(style: String, lang: String, count: Int = 1): String = when {
        PushSpec.isChat(style) -> when (lang) {
            "en" -> if (count > 1) "$count new messages" else "New message"
            "ar" -> if (count > 1) "$count رسائل جديدة" else "رسالة جديدة"
            else -> if (count > 1) "$count yeni mesaj" else "Yeni mesaj"
        }
        style == "SECURITY" -> when (lang) { "en" -> "Security notification"; "ar" -> "إشعار أمان"; else -> "Güvenlik bildirimi" }
        style == "SUPPORT" -> when (lang) { "en" -> "Support update"; "ar" -> "تحديث الدعم"; else -> "Destek güncellemesi" }
        style == "MODERATION" -> when (lang) { "en" -> "Account notification"; "ar" -> "إشعار الحساب"; else -> "Hesap bildirimi" }
        else -> when (lang) { "en" -> "New notification"; "ar" -> "إشعار جديد"; else -> "Yeni bildirim" }
    }
}
