package edu.bingol.bu_kampus.widgets

/**
 * Hizli Erisim widget'i icin widget-ornegi (appWidgetId) basina kisayol secimi. Saf Kotlin: birim testlenebilir.
 *
 * Karar: secim CIHAZA ve widget ornegine ozeldir (launcher'daki bir widget'a aittir), kisisel veri icermez
 * (yalniz 8 sabit kisayol kimligi). Hesap baglami: secim, yazildigi andaki hesapla (`meta.ownerUserId`) etiketlenir.
 *  - cikis (meta.signedIn=false) -> tum secimler silinir;
 *  - baska hesap oturum acarsa -> eski hesabin secimi yok sayilir ve silinir;
 *  - oturumsuzken yapilan secim (sahip ""), ilk oturumlu cizimde o hesaba baglanir.
 */
object QuickSelection {
    const val PREFIX = "bu_widget_qa_sel_"

    /** Dart `kQuickAccessCatalog` ile ayni kimlikler ve sira (test denetler). */
    val ALL_IDS = listOf("menu", "timetable", "events", "clubs", "chat", "qr", "news", "search")

    fun key(appWidgetId: Int) = PREFIX + appWidgetId

    class Sel(val owner: String, val ids: List<String>)

    /** Bilinmeyen/yinelenen kimlikleri atar, sirayi korur. */
    fun sanitize(ids: List<String>): List<String> = ids.filter { it in ALL_IDS }.distinct()

    fun encode(owner: String, ids: List<String>): String = owner + "|" + sanitize(ids).joinToString(",")

    fun decode(raw: String?): Sel? {
        if (raw.isNullOrEmpty()) return null
        val i = raw.indexOf('|')
        if (i < 0) return null
        val ids = sanitize(raw.substring(i + 1).split(',').filter { it.isNotEmpty() })
        if (ids.isEmpty()) return null
        return Sel(raw.substring(0, i), ids)
    }

    /** meta.ownerUserId (sayi ya da metin) -> metin; yoksa "". */
    fun ownerOf(metaRaw: String?): String {
        val meta = parseObject(metaRaw) ?: return ""
        if (!meta.bool("signedIn", true)) return ""
        return meta.str("ownerUserId") ?: ""
    }

    /** Meta ACIKCA `signedIn=false` mi (bozuk/eksik meta cikis sayilmaz: secimler yanlislikla silinmesin). */
    fun explicitlySignedOut(metaRaw: String?): Boolean {
        val meta = parseObject(metaRaw) ?: return false
        return meta.has("signedIn") && !meta.bool("signedIn", true)
    }

    enum class Action { USE, DROP, BIND, NONE }

    class Resolution(val action: Action, val ids: List<String>?)

    /** [currentOwner]: oturumlu hesap ("" = bilinmiyor). Secim yoksa NONE. */
    fun resolve(raw: String?, currentOwner: String): Resolution {
        val sel = decode(raw) ?: return Resolution(Action.NONE, null)
        return when {
            currentOwner.isEmpty() -> Resolution(Action.USE, sel.ids) // sahip bilinmiyor: dokunma
            sel.owner.isEmpty() -> Resolution(Action.BIND, sel.ids)
            sel.owner == currentOwner -> Resolution(Action.USE, sel.ids)
            else -> Resolution(Action.DROP, null)
        }
    }

    /** Secimi modele uygular: yalniz secilen (ve snapshot'ta bulunan) kisayollar, secim sirasiyla; small ilk 4. */
    fun apply(m: QuickModel, ids: List<String>): QuickModel {
        val picked = ids.mapNotNull { id -> m.items.firstOrNull { it.id == id } }
        if (picked.isEmpty()) return m
        return QuickModel(picked, picked.take(WidgetTokens.QUICK_SMALL_TILES), m.st, m.deepLink)
    }
}
