package edu.bingol.bu_kampus

import java.util.Calendar
import java.util.TimeZone

/**
 * Bildirim kartinin SAF (android bagimsiz) belirtimi: yuk -> stil, kaynak etiketi, rozet, cip, aksiyon, ikon karosu.
 * Birim testi: android/app/src/test/.../PushSpecTest.kt. Sunucu sozlesmesi: docs/changes/push.md
 * "Bildirim tasarimi yuk sozlesmesi". Kural: veri yoksa oge uretilmez (uydurma yok); aksiyonun gercek islevi olmali.
 */
enum class Tone { RED, BLUE, PURPLE, ORANGE, GREEN, GRAY }
enum class Glyph { CHAT, GROUP, EVENT, SCHOOL, MEGAPHONE, POLL, MEAL, HEART, PERSON_ADD, LOCK, CHECK, SHIELD, SUPPORT, INFO, CLOCK, PHOTO }

data class IconSpec(val glyph: Glyph, val tone: Tone)
data class ChipSpec(val text: String, val tone: Tone)

/** badge: baslik yanindaki hap (Saat Revizesi, Iptal, Son 24 saat); flag: baslik satirindaki kirmizi etiket (ONEMLI). */
data class BadgeSpec(val pill: String?, val pillTone: Tone, val flag: String?)
data class NoteSpec(val newTime: String, val oldLabel: String, val oldTime: String)

/**
 * id: Dart `PushActions` eylem adi (reply, mark_read, mute_hour, follow_accept, follow_decline, follow, calendar, map,
 * security, checkin, open) ya da yalniz native "ack" (bildirimi kaldir). system: Notification.Action (sohbet) olarak cizilir.
 */
data class ActionSpec(val id: String, val label: String)

object PushSpec {
    val TIME_ZONE: TimeZone = TimeZone.getTimeZone("Europe/Istanbul")

    fun lang(data: Map<String, String>): String = when {
        data["locale"]?.startsWith("en") == true -> "en"
        data["locale"]?.startsWith("ar") == true -> "ar"
        else -> "tr"
    }

    private fun l(data: Map<String, String>, tr: String, en: String, ar: String): String = when (lang(data)) {
        "en" -> en
        "ar" -> ar
        else -> tr
    }

    private fun truthy(v: String?) = v == "1" || v.equals("true", true)

    /**
     * Sunucu veri-only yuku zengin kart mi? Rich isaretleri (richNotification/richChat) ya da yeni sozlesme:
     * notification blogu yok + style + baslik. hasNotificationBlock true ise sistem zaten cizer (dokunma).
     */
    fun isRich(data: Map<String, String>, hasNotificationBlock: Boolean): Boolean {
        if (hasNotificationBlock) return false
        if (data["richNotification"] == "1" || data["richChat"] == "1") return true
        return !data["style"].isNullOrBlank() && !data["title"].isNullOrBlank()
    }

    // ---- stil ----

    /** Sunucu her yukte `style` yazar (ince taneli). Eski sunucu/yerel hatirlatma icin tur/hedeften turetilir. */
    fun style(data: Map<String, String>): String {
        val explicit = data["style"]?.trim()?.uppercase().orEmpty()
        val type = data["type"]?.trim()?.uppercase().orEmpty()
        val subtype = data["subtype"]?.trim()?.uppercase().orEmpty()
        val target = (data["targetType"] ?: data["target"]).orEmpty().trim().uppercase()
        if (explicit.isNotEmpty()) return when (explicit) {
            "CHAT", "MESSAGE" -> chat(data)
            "EVENT" -> event(data, subtype)
            "NEWS" -> "ANNOUNCEMENT"
            else -> explicit
        }
        return when {
            type == "MESSAGE" || data["conversationId"] != null -> chat(data)
            type == "FOLLOW_REQUEST" -> "FOLLOW_REQUEST"
            type == "FOLLOW_ACCEPTED" -> "FOLLOW_ACCEPTED"
            type == "USER_FOLLOW" -> "FOLLOW"
            type == "POST_LIKE" -> "LIKE"
            type.startsWith("POST_") || type == "COMMENT_REPLY" -> "SOCIAL"
            data["pollId"] != null || subtype == "POLL" -> "POLL"
            data["examId"] != null || subtype == "EXAM_REMINDER" -> "EXAM"
            data["ticketId"] != null || data["feedbackId"] != null || target == "TICKET" || target == "FEEDBACK" -> "SUPPORT"
            target == "MEAL" || target == "MENU" -> "MEAL"
            type == "SYSTEM" -> if (data["securityKind"] != null || target == "ACCOUNT_SECURITY" || target == "SECURITY") "SECURITY" else "SYSTEM"
            type == "EVENT" || data["eventId"] != null -> event(data, subtype)
            else -> "ANNOUNCEMENT"
        }
    }

    private fun chat(data: Map<String, String>) = when {
        !data["imageUrl"].isNullOrBlank() -> "CHAT_MEDIA"
        data["conversationType"] == "GROUP" -> "CHAT_GROUP"
        else -> "CHAT_DIRECT"
    }

    private fun event(data: Map<String, String>, subtype: String) = when {
        subtype == "EVENT_REMINDER" -> "EVENT_REMINDER"
        subtype == "EVENT_ADMISSION" -> "EVENT_ADMISSION"
        subtype.contains("CANCEL") -> "EVENT_CANCELLED"
        else -> "EVENT_UPDATE"
    }

    fun isChat(style: String) = style.startsWith("CHAT")

    /** Etkinlik saatine <= 2 sa kala (hatirlatma "1 saat kala" kipi). */
    fun startsSoon(data: Map<String, String>, nowMs: Long): Boolean {
        val at = PushTime.parse(data["eventStartsAt"]) ?: return false
        return at - nowMs in -3_600_000L..7_200_000L
    }

    // ---- kaynak / rozet / cip ----

    fun section(data: Map<String, String>, style: String = style(data)): String = when (style) {
        "CHAT_DIRECT" -> l(data, "Sohbet", "Chat", "محادثة")
        "CHAT_GROUP" -> l(data, "Kulüp Odası", "Group chat", "محادثة جماعية")
        "CHAT_MEDIA" -> l(data, "Medya", "Media", "وسائط")
        "EVENT_REMINDER", "EVENT_UPDATE", "EVENT_ADMISSION", "EVENT_CANCELLED" -> l(data, "Etkinlik", "Event", "فعالية")
        "EXAM", "ACADEMIC" -> l(data, "Akademik", "Academic", "أكاديمي")
        "CLASS" -> l(data, "Ders Programı", "Timetable", "جدول الدروس")
        "POLL" -> l(data, "Anket", "Poll", "استطلاع")
        "MEAL" -> l(data, "Bugünün Menüsü", "Today's menu", "قائمة اليوم")
        "SECURITY" -> l(data, "Güvenlik", "Security", "الأمان")
        "SUPPORT" -> l(data, "Destek Masası", "Support", "الدعم")
        "MODERATION" -> l(data, "Topluluk Kuralları", "Community rules", "قواعد المجتمع")
        "LIKE", "SOCIAL", "FOLLOW", "FOLLOW_REQUEST", "FOLLOW_ACCEPTED" -> l(data, "Sosyal", "Social", "اجتماعي")
        "SYSTEM" -> l(data, "Sistem", "System", "النظام")
        else -> l(data, "Bildirim", "Notification", "إشعار")
    }

    /** Kaynak etiketi: sunucunun kaynak adi (kulup/birim) varsa o; yoksa stilden. */
    fun source(data: Map<String, String>, style: String = style(data)): String {
        val named = data["sourceName"]?.trim().orEmpty()
        return if (named.isNotEmpty()) named.take(60) else section(data, style)
    }

    fun isCritical(data: Map<String, String>) = data["severity"].equals("critical", true)

    fun badge(data: Map<String, String>, style: String = style(data)): BadgeSpec {
        val text = data["badgeText"]?.trim().orEmpty().take(24)
        val important = truthy(data["important"])
        if (important) {
            val flag = text.ifEmpty { l(data, "ÖNEMLİ", "IMPORTANT", "مهم") }
            return BadgeSpec(null, Tone.RED, flag)
        }
        if (text.isNotEmpty()) {
            // "Yarin" gibi zaman etiketi baslik yaninda degil sag ustte cizilir ([headerChip]).
            return BadgeSpec(text, Tone.RED, null)
        }
        return BadgeSpec(null, Tone.RED, null)
    }

    /** Etkinlik hatirlatmasinda "Yarin"/"Bugun" cipi sag ust: `badgeText` bu ise baslik hapinda tekrarlanmaz. */
    fun headerChip(data: Map<String, String>, style: String, nowMs: Long): String? {
        if (style != "EVENT_REMINDER") return null
        val at = PushTime.parse(data["eventStartsAt"]) ?: return data["badgeText"]?.trim()?.take(16)?.ifEmpty { null }
        val day = PushTime.dayLabel(at, nowMs, lang(data))
        return if (day.second) day.first else null
    }

    /** Baslik yanindaki hap: `badgeText` (Saat Revizesi, Iptal, Son 24 saat); EVENT_REMINDER'da sag ust cipe tasinir. */
    fun titlePill(data: Map<String, String>, style: String, nowMs: Long): BadgeSpec {
        val b = badge(data, style)
        if (style == "EVENT_REMINDER") return b.copy(pill = null)
        return b
    }

    fun note(data: Map<String, String>, style: String): NoteSpec? {
        if (style != "EVENT_UPDATE") return null
        val old = PushTime.parse(data["oldStartsAt"]) ?: return null
        val new = PushTime.parse(data["newStartsAt"] ?: data["eventStartsAt"]) ?: return null
        if (old == new) return null
        val sameDay = PushTime.sameDay(old, new)
        val lang = lang(data)
        return NoteSpec(
            if (sameDay) PushTime.hhmm(new) else PushTime.dayTime(new, lang),
            l(data, "Eski saat", "Previous time", "الوقت السابق"),
            if (sameDay) PushTime.hhmm(old) else PushTime.dayTime(old, lang)
        )
    }

    fun chips(data: Map<String, String>, style: String, nowMs: Long): List<ChipSpec> {
        val out = mutableListOf<ChipSpec>()
        when (style) {
            "EXAM" -> {
                val at = PushTime.parse(data["eventStartsAt"])
                val place = data["location"]?.trim().orEmpty().take(40)
                if (at != null) {
                    val day = PushTime.dayLabel(at, nowMs, lang(data)).first
                    out.add(ChipSpec(listOf("$day ${PushTime.hhmm(at)}", place).filter { it.isNotEmpty() }.joinToString(" · "), Tone.RED))
                } else if (place.isNotEmpty()) out.add(ChipSpec(place, Tone.RED))
            }
            "MEAL" -> {
                val kcal = data["totalKcal"]?.trim()?.toIntOrNull()
                if (kcal != null && kcal > 0) out.add(ChipSpec(l(data, "Toplam $kcal kcal", "Total $kcal kcal", "المجموع $kcal سعرة"), Tone.GREEN))
            }
            "EVENT_REMINDER", "EVENT_ADMISSION" -> {
                val at = PushTime.parse(data["eventStartsAt"])
                val place = data["location"]?.trim().orEmpty().take(40)
                if (style == "EVENT_ADMISSION" && at != null) {
                    out.add(ChipSpec(listOf(PushTime.dayLabel(at, nowMs, lang(data)).first + " " + PushTime.hhmm(at), place).filter { it.isNotEmpty() }.joinToString(" · "), Tone.BLUE))
                }
            }
        }
        return out.take(2)
    }

    // ---- ikon karosu / rozet ----

    /** Avatar yokken (ya da kisi olmayan turlerde) kategori ikon karosu. Sohbet: null (BU markasi). */
    fun tile(style: String): IconSpec? = when (style) {
        "CHAT_DIRECT", "CHAT_GROUP", "CHAT_MEDIA" -> null
        "EVENT_REMINDER", "EVENT_ADMISSION" -> IconSpec(Glyph.EVENT, Tone.BLUE)
        "EVENT_UPDATE" -> IconSpec(Glyph.EVENT, Tone.ORANGE)
        "EVENT_CANCELLED" -> IconSpec(Glyph.EVENT, Tone.RED)
        "EXAM" -> IconSpec(Glyph.EVENT, Tone.RED)
        "ACADEMIC" -> IconSpec(Glyph.SCHOOL, Tone.PURPLE)
        "CLASS" -> IconSpec(Glyph.CLOCK, Tone.BLUE)
        "POLL" -> IconSpec(Glyph.POLL, Tone.BLUE)
        "MEAL" -> IconSpec(Glyph.MEAL, Tone.ORANGE)
        "LIKE", "SOCIAL" -> IconSpec(Glyph.HEART, Tone.RED)
        "FOLLOW", "FOLLOW_REQUEST", "FOLLOW_ACCEPTED" -> IconSpec(Glyph.PERSON_ADD, Tone.BLUE)
        "SECURITY" -> IconSpec(Glyph.SHIELD, Tone.RED)
        "SUPPORT" -> IconSpec(Glyph.SUPPORT, Tone.GRAY)
        "MODERATION" -> IconSpec(Glyph.INFO, Tone.ORANGE)
        "SYSTEM" -> IconSpec(Glyph.INFO, Tone.GRAY)
        else -> IconSpec(Glyph.MEGAPHONE, Tone.RED)
    }

    /** Avatarin kose rozeti (yalniz avatar gercekten varsa cizilir). Sohbette okunmamis sayisi ayrica cizilir. */
    fun cornerBadge(style: String, count: Int): Glyph? = when {
        isChat(style) && count > 1 -> null
        style == "CHAT_GROUP" -> Glyph.GROUP
        style == "LIKE" -> Glyph.HEART
        style == "FOLLOW" -> Glyph.PERSON_ADD
        style == "FOLLOW_REQUEST" -> Glyph.LOCK
        style == "FOLLOW_ACCEPTED" -> Glyph.CHECK
        else -> null
    }

    /** Kucuk resmin SAGDA durdugu stiller; sohbet fotografi genis onizleme. */
    fun wideImage(style: String) = style == "CHAT_MEDIA"

    // ---- aksiyonlar (yalniz gercek islevi olanlar) ----

    fun actions(data: Map<String, String>, style: String, count: Int, nowMs: Long): List<ActionSpec> {
        fun a(id: String, tr: String, en: String, ar: String) = ActionSpec(id, l(data, tr, en, ar))
        val hasMessage = data["messageId"] != null
        val hasConversation = data["conversationId"] != null
        return when (style) {
            "CHAT_DIRECT" -> buildList {
                if (hasConversation) add(if (count > 1) a("reply", "Hızlı Yanıtla", "Quick reply", "رد سريع") else a("reply", "Yanıtla", "Reply", "رد"))
                if (count > 1) add(a("open", "Tümünü Aç", "Open all", "فتح الكل"))
                else if (hasMessage && hasConversation) add(a("mark_read", "Okundu İşaretle", "Mark as read", "تحديد كمقروء"))
            }
            "CHAT_GROUP" -> buildList {
                if (hasConversation) add(if (count > 1) a("reply", "Hızlı Yanıtla", "Quick reply", "رد سريع") else a("reply", "Yanıtla", "Reply", "رد"))
                if (count > 1) add(a("open", "Tümünü Aç", "Open all", "فتح الكل"))
                else if (hasConversation) add(a("mute_hour", "1 Saat Sessize Al", "Mute for 1 hour", "كتم لساعة"))
            }
            "CHAT_MEDIA" -> buildList {
                add(a("open", "Görüntüle", "View", "عرض"))
                if (hasConversation) add(a("reply", "Yanıtla", "Reply", "رد"))
            }
            "FOLLOW_REQUEST" -> if (data["userId"] != null || data["targetId"] != null || data["value"] != null)
                listOf(a("follow_accept", "Onayla", "Accept", "قبول"), a("follow_decline", "Reddet", "Decline", "رفض"))
            else listOf(a("open", "Detay", "Details", "التفاصيل"))
            "FOLLOW" -> if (data["userId"] != null || data["targetId"] != null || data["value"] != null)
                listOf(a("follow", "Takip et", "Follow", "متابعة"))
            else emptyList()
            "FOLLOW_ACCEPTED" -> listOf(a("open", "Profili Gör", "View profile", "عرض الملف"))
            "LIKE" -> emptyList() // tasarim: beğeni kartinda aksiyon yok (dokununca gonderi acilir)
            "EVENT_REMINDER" -> buildList {
                if (startsSoon(data, nowMs)) add(a("checkin", "QR ile Giriş", "Check in with QR", "تسجيل الدخول بـ QR"))
                else {
                    add(a("calendar", "Takvime Ekle", "Add to calendar", "إضافة للتقويم"))
                    if (!data["location"].isNullOrBlank()) add(a("map", "Haritada Gör", "Show on map", "عرض الخريطة"))
                }
            }
            "EVENT_ADMISSION" -> listOf(a("open", "Giriş Kartı", "Entry card", "بطاقة الدخول"))
            "EVENT_UPDATE" -> listOf(a("ack", "Anladım", "Got it", "فهمت"), a("open", "Program Detayı", "Event details", "تفاصيل الفعالية"))
            "EVENT_CANCELLED" -> listOf(a("ack", "Anladım", "Got it", "فهمت"), a("open", "Etkinliği Gör", "View event", "عرض الفعالية"))
            "EXAM" -> listOf(a("open", "Sınav Detayı", "Exam details", "تفاصيل الامتحان"))
            "CLASS" -> listOf(a("open", "Ders Programı", "Timetable", "جدول الدروس"))
            "POLL" -> listOf(
                if (!data["badgeText"].isNullOrBlank()) a("open", "Hemen Doldur", "Fill in now", "املأ الآن")
                else a("open", "Oy ver", "Vote", "تصويت")
            )
            "MEAL" -> listOf(a("open", "Menüyü Gör", "View menu", "عرض القائمة"))
            "SUPPORT" -> listOf(a("open", "Talebi Görüntüle →", "View ticket →", "عرض الطلب"))
            "SECURITY" -> when (data["securityKind"]?.uppercase()) {
                "NEW_DEVICE" -> listOf(a("security", "Bu ben değilim", "This wasn't me", "لم أكن أنا"))
                "PASSWORD_CHANGED" -> listOf(a("security", "Hemen Sıfırla", "Reset now", "إعادة التعيين الآن"))
                "TWOFA_DISABLED" -> listOf(a("security", "2FA Aç", "Turn on 2FA", "تفعيل 2FA"))
                else -> listOf(a("security", "Hesap Güvenliği", "Account security", "أمان الحساب"))
            }
            "MODERATION", "SYSTEM" -> listOf(a("open", "Detay", "Details", "التفاصيل"))
            "SOCIAL" -> listOf(a("open", "Detay", "Details", "التفاصيل"))
            else -> listOf(a("open", "Detay", "Details", "التفاصيل"))
        }
    }
}

/** Saat/gun bicimleme: JVM + Android'de ayni (java.time yok; minSdk 24). Gosterim saat dilimi Europe/Istanbul. */
object PushTime {
    private val ISO = Regex("^(\\d{4})-(\\d{2})-(\\d{2})[T ](\\d{2}):(\\d{2})(?::(\\d{2}))?(?:\\.\\d+)?\\s*(Z|[+-]\\d{2}:?\\d{2})?$")
    private val MONTHS_TR = arrayOf("Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara")
    private val MONTHS_EN = arrayOf("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
    private val MONTHS_AR = arrayOf("يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو", "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر")

    /** ISO-8601 (Z/ofset; ofsetsiz = Istanbul) ya da epoch ms/sn -> epoch ms; bozuksa null. */
    fun parse(raw: String?): Long? {
        val s = raw?.trim().orEmpty()
        if (s.isEmpty()) return null
        if (s.all { it.isDigit() }) {
            val n = s.toLongOrNull() ?: return null
            return if (s.length >= 12) n else n * 1000
        }
        val m = ISO.matchEntire(s) ?: return null
        val g = m.groupValues
        val zone = when (val z = g[7]) {
            "" -> TIME_ZONE_ISTANBUL
            "Z" -> TimeZone.getTimeZone("GMT")
            else -> TimeZone.getTimeZone("GMT" + z.substring(0, 3) + ":" + z.takeLast(2))
        }
        val c = Calendar.getInstance(zone)
        c.clear()
        c.set(g[1].toInt(), g[2].toInt() - 1, g[3].toInt(), g[4].toInt(), g[5].toInt(), g[6].ifEmpty { "0" }.toInt())
        return c.timeInMillis
    }

    private val TIME_ZONE_ISTANBUL: TimeZone get() = PushSpec.TIME_ZONE

    private fun wall(ms: Long): Calendar = Calendar.getInstance(PushSpec.TIME_ZONE).apply { timeInMillis = ms }

    private fun two(n: Int) = if (n < 10) "0$n" else "$n"

    fun hhmm(ms: Long): String { val c = wall(ms); return two(c.get(Calendar.HOUR_OF_DAY)) + ":" + two(c.get(Calendar.MINUTE)) }

    private fun dayKey(c: Calendar) = c.get(Calendar.YEAR) * 1000 + c.get(Calendar.DAY_OF_YEAR)

    fun sameDay(a: Long, b: Long) = dayKey(wall(a)) == dayKey(wall(b))

    private fun months(lang: String) = when (lang) { "en" -> MONTHS_EN; "ar" -> MONTHS_AR; else -> MONTHS_TR }

    /** "2 Kas 14:00" */
    fun dayTime(ms: Long, lang: String): String {
        val c = wall(ms)
        return "${c.get(Calendar.DAY_OF_MONTH)} ${months(lang)[c.get(Calendar.MONTH)]} ${hhmm(ms)}"
    }

    /** (etiket, yakin mi): Bugun/Yarin ya da "2 Kas"; ikinci deger Bugun/Yarin ise true. */
    fun dayLabel(ms: Long, nowMs: Long, lang: String): Pair<String, Boolean> {
        val c = wall(ms)
        val today = wall(nowMs)
        val tomorrow = wall(nowMs + 86_400_000L)
        return when (dayKey(c)) {
            dayKey(today) -> Pair(when (lang) { "en" -> "Today"; "ar" -> "اليوم"; else -> "Bugün" }, true)
            dayKey(tomorrow) -> Pair(when (lang) { "en" -> "Tomorrow"; "ar" -> "غدًا"; else -> "Yarın" }, true)
            else -> Pair("${c.get(Calendar.DAY_OF_MONTH)} ${months(lang)[c.get(Calendar.MONTH)]}", false)
        }
    }
}
