package edu.bingol.bu_kampus.widgets

import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.TimeZone

/**
 * Widget cekirdegi: saf Kotlin (Android bagimliligi yok, org.json disinda) -> birim testlenebilir.
 * Sozlesme: design/widget-previews/DATA_CONTRACT.md. Bozuk/eksik/surum uyusmayan veri hicbir zaman exception atmaz.
 */

/** Widget slug'lari. [key] SharedPreferences anahtari, DATA_CONTRACT bolum 2. */
enum class WidgetSlug(val slug: String, val key: String) {
    MENU("menu", WidgetTokens.KEY_MENU),
    TIMETABLE("timetable", WidgetTokens.KEY_TIMETABLE),
    EVENTS("events", WidgetTokens.KEY_EVENTS),
    ANNOUNCEMENTS("announcements", WidgetTokens.KEY_ANNOUNCEMENTS),
    POLL("poll", WidgetTokens.KEY_POLL),
    QUICKACCESS("quickaccess", WidgetTokens.KEY_QUICK_ACCESS),
    SOCIAL("social", WidgetTokens.KEY_SOCIAL),
}

enum class SizeClass { SMALL, MEDIUM, LARGE }

/** Launcher'in bildirdigi dp olculerinden yerlesim sinifi: <250 genislik = 2x2, yukseklik <250 = 4x2, digeri 4x4. */
object WidgetSizing {
    fun classify(wDp: Int, hDp: Int, fallback: SizeClass): SizeClass {
        if (wDp <= 0 || hDp <= 0) return fallback
        return if (wDp < 250) SizeClass.SMALL else if (hDp < 250) SizeClass.MEDIUM else SizeClass.LARGE
    }

    /** DESIGN_SYSTEM bolum 7: n = min(tavan, floor((H + aralik) / (satir + aralik))), en az 1. */
    fun fit(availDp: Int, rowDp: Int, gapDp: Int, max: Int): Int {
        if (availDp <= 0) return 1
        val n = (availDp + gapDp) / (rowDp + gapDp)
        return n.coerceIn(1, max)
    }
}

// ------------------------------------------------------------------ JSON yardimcilari
internal fun JSONObject?.str(k: String): String? {
    if (this == null || !has(k) || isNull(k)) return null
    val v = opt(k)
    return if (v is String) v.ifEmpty { null } else if (v is Number || v is Boolean) v.toString() else null
}

internal fun JSONObject?.int(k: String): Int? {
    if (this == null || !has(k) || isNull(k)) return null
    return when (val v = opt(k)) {
        is Number -> v.toInt()
        is String -> v.toIntOrNull()
        else -> null
    }
}

internal fun JSONObject?.bool(k: String, def: Boolean = false): Boolean {
    if (this == null || !has(k) || isNull(k)) return def
    return when (val v = opt(k)) {
        is Boolean -> v
        else -> def
    }
}

internal fun JSONObject?.obj(k: String): JSONObject? = if (this == null || isNull(k)) null else optJSONObject(k)
internal fun JSONObject?.arr(k: String): JSONArray? = if (this == null || isNull(k)) null else optJSONArray(k)

internal fun JSONArray?.objs(): List<JSONObject> {
    if (this == null) return emptyList()
    val out = ArrayList<JSONObject>(length())
    for (i in 0 until length()) optJSONObject(i)?.let { out.add(it) }
    return out
}

internal fun JSONArray?.strs(): List<String> {
    if (this == null) return emptyList()
    val out = ArrayList<String>(length())
    for (i in 0 until length()) {
        if (!isNull(i)) (opt(i) as? String)?.let { out.add(it) }
    }
    return out
}

internal fun parseObject(raw: String?): JSONObject? {
    if (raw.isNullOrBlank()) return null
    return try {
        JSONObject(raw)
    } catch (_: Throwable) {
        null
    }
}

/** Sabit metin sozlugu (snapshot `strings`); eksik anahtar bos metin. {n} {time} gibi yer tutucular tek yerlestirme. */
class Strs(private val o: JSONObject?) {
    operator fun get(k: String): String = o.str(k) ?: ""
    fun opt(k: String): String? = o.str(k)
    fun fill(k: String, vararg pairs: Pair<String, String>): String {
        var t = get(k)
        for ((name, value) in pairs) t = t.replace("{$name}", value)
        return t
    }
}

// ------------------------------------------------------------------ Saat (Europe/Istanbul)
object WidgetClock {
    private val TZ: TimeZone = TimeZone.getTimeZone("Europe/Istanbul")
    private val ISO = Regex("""^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2}))?(?:\.\d+)?(Z|[+-]\d{2}:?\d{2})?$""")

    private fun cal(ms: Long): Calendar = Calendar.getInstance(TZ).also { it.timeInMillis = ms }

    /** `YYYY-MM-DD` (Istanbul yerel gunu). */
    fun dateKey(ms: Long): String {
        val c = cal(ms)
        return "%04d-%02d-%02d".format(c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH))
    }

    /** Gece yarisindan dakika. */
    fun minuteOfDay(ms: Long): Int {
        val c = cal(ms)
        return c.get(Calendar.HOUR_OF_DAY) * 60 + c.get(Calendar.MINUTE)
    }

    /** ISO-8601 (ofsetli) -> epoch ms; ofset yoksa Istanbul. Gecersizse null. */
    fun parseIso(s: String?): Long? {
        if (s.isNullOrBlank()) return null
        val m = ISO.matchEntire(s.trim()) ?: return null
        return try {
            val g = m.groupValues
            val utc = Calendar.getInstance(TimeZone.getTimeZone("UTC"))
            utc.clear()
            utc.set(g[1].toInt(), g[2].toInt() - 1, g[3].toInt(), g[4].toInt(), g[5].toInt(), if (g[6].isEmpty()) 0 else g[6].toInt())
            val localAsUtc = utc.timeInMillis
            val off = g[7]
            val offMs = when {
                off.isEmpty() -> TZ.getOffset(localAsUtc).toLong()
                off == "Z" -> 0L
                else -> {
                    val sign = if (off[0] == '-') -1 else 1
                    val digits = off.substring(1).replace(":", "")
                    sign * (digits.substring(0, 2).toInt() * 60L + digits.substring(2, 4).toInt()) * 60_000L
                }
            }
            localAsUtc - offMs
        } catch (_: Throwable) {
            null
        }
    }
}

// ------------------------------------------------------------------ Kapi: oturumsuz / bos / tamam
sealed class Gate {
    /** Oturumsuz ya da veri yok/bozuk: "Giris yap". [title]/[sub] null ise yerel (strings.xml) metin kullanilir. */
    class SignedOut(val title: String?, val sub: String?, val rtl: Boolean) : Gate()

    class Empty(val snap: JSONObject, val rtl: Boolean) : Gate()
    class Ok(val snap: JSONObject, val rtl: Boolean) : Gate()
}

object WidgetGate {
    const val SCHEMA = 1

    fun resolve(metaRaw: String?, snapRaw: String?, nowMs: Long): Gate {
        val meta = parseObject(metaRaw)
        val ms = Strs(meta.obj("strings"))
        val metaOk = meta != null && (meta.int("schema") ?: 1) <= SCHEMA
        val rtl = if (metaOk) meta.bool("rtl") else false
        val so = Gate.SignedOut(ms.opt("signedOutTitle"), ms.opt("signedOutSub"), rtl)
        if (!metaOk) return Gate.SignedOut(null, null, false)
        if (!meta.bool("signedIn", true)) return so
        val snap = parseObject(snapRaw) ?: return so
        if ((snap.int("schema") ?: 1) > SCHEMA) return so
        val state = snap.str("state") ?: "ok"
        if (state == "signedOut") return so
        val snapRtl = if (snap.has("rtl")) snap.bool("rtl") else rtl
        if (state == "empty") return Gate.Empty(snap, snapRtl)
        val exp = WidgetClock.parseIso(snap.str("expiresAt"))
        if (exp != null && nowMs > exp) return Gate.Empty(snap, snapRtl)
        return Gate.Ok(snap, snapRtl)
    }
}
