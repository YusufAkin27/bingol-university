package edu.bingol.bu_kampus.widgets

import org.json.JSONObject

/**
 * Slug bazli gorunum modelleri ve secim mantigi (saf Kotlin, birim testli).
 * Ceviri/bicimlendirme YOK: metinler snapshot'ta hazir gelir (DATA_CONTRACT bolum 4); burada yalniz secim, filtre,
 * zamana gore durum ve sablon doldurma yapilir.
 */

// ====================================================================== MENU
class Dish(val name: String, val kcalText: String?)

class Meal(val id: String, val label: String, val items: List<Dish>, val totalText: String?)

class MenuModel(
    val dateLabel: String,
    val meals: List<Meal>,
    val totalLine: String?,
    val totalText: String?,
    val kcalLine: String?,
    val st: Strs,
) {
    /** Small/2x2 ogunu: 18:00 sonrasi ve aksam varsa aksam, yoksa ilk ogun. */
    fun smallMeal(nowMin: Int): Meal {
        val dinner = meals.firstOrNull { it.id == "dinner" }
        return if (dinner != null && nowMin >= 18 * 60) dinner else meals.first()
    }
}

object MenuModels {
    /** Bugune esit `date` tasiyan nesne (ust duzey ya da upcoming[i]); yoksa null (bos durum). */
    fun build(snap: JSONObject, nowMs: Long): MenuModel? {
        val today = WidgetClock.dateKey(nowMs)
        val day = if (snap.str("date") == today) snap
        else snap.arr("upcoming").objs().firstOrNull { it.str("date") == today } ?: return null
        if (day.bool("empty")) return null
        val meals = day.arr("meals").objs().mapNotNull { m ->
            val items = m.arr("items").objs().mapNotNull { d ->
                val n = d.str("name") ?: return@mapNotNull null
                Dish(n, d.str("kcalText"))
            }
            if (items.isEmpty()) null else Meal(m.str("id") ?: "lunch", m.str("label") ?: "", items, m.str("totalText"))
        }
        if (meals.isEmpty()) return null
        val small = day.obj("small")
        return MenuModel(
            dateLabel = day.str("dateLabel") ?: "",
            meals = meals,
            totalLine = day.str("totalLine"),
            totalText = day.str("totalText"),
            kcalLine = small.str("kcalLine"),
            st = Strs(snap.obj("strings")),
        )
    }

    /** "Tavuk Sote · Pilav · Salata": ana yemekten sonraki ilk 3 yemek. */
    fun subLine(meal: Meal): String? =
        meal.items.drop(1).take(3).joinToString(" · ") { it.name }.ifEmpty { null }
}

// ====================================================================== TIMETABLE
class Lesson(val start: String, val end: String, val startMin: Int, val endMin: Int, val title: String, val room: String?)

enum class LessonState { PAST, NOW, NEXT, LATER }

class TimetableModel(
    val dateLabel: String,
    val lessons: List<Lesson>,
    val count: Int,
    val nextShort: String?,
    val nextFull: String?,
    val st: Strs,
)

object TimetableModels {
    fun build(snap: JSONObject, nowMs: Long): TimetableModel? {
        val today = WidgetClock.dateKey(nowMs)
        val day = if (snap.str("date") == today) snap
        else snap.arr("upcoming").objs().firstOrNull { it.str("date") == today }
        val lessons = day.arr("lessons").objs().mapNotNull { l ->
            val title = l.str("title") ?: return@mapNotNull null
            val sm = l.int("startMin") ?: return@mapNotNull null
            val em = l.int("endMin") ?: return@mapNotNull null
            Lesson(l.str("start") ?: "", l.str("end") ?: "", sm, em, title, l.str("room"))
        }.sortedBy { it.startMin }
        val next = snap.obj("next")
        return TimetableModel(
            dateLabel = (day ?: snap).str("dateLabel") ?: "",
            lessons = lessons,
            count = day.int("count") ?: lessons.size,
            nextShort = next.str("labelShort"),
            nextFull = next.str("labelFull"),
            st = Strs(snap.obj("strings")),
        )
    }

    /** Kural (DATA_CONTRACT 5.2): endMin <= now gecmis; start <= now < end suren; ilk start > now siradaki. */
    fun states(lessons: List<Lesson>, nowMin: Int): List<LessonState> {
        var nextAssigned = false
        return lessons.map { l ->
            when {
                l.endMin <= nowMin -> LessonState.PAST
                l.startMin <= nowMin -> LessonState.NOW
                !nextAssigned -> { nextAssigned = true; LessonState.NEXT }
                else -> LessonState.LATER
            }
        }
    }

    /** Siradaki/sure kalan: d<60 inMin, aksi inHour (en az 1). */
    fun inText(st: Strs, d: Int): String =
        if (d < 60) st.fill("inMin", "n" to d.toString()) else st.fill("inHour", "n" to maxOf(1, d / 60).toString())
}

// ====================================================================== EVENTS
class EventItem(
    val id: String, val title: String, val club: String?, val startsAtMs: Long,
    val day: String, val monthCaps: String, val time: String, val venue: String?, val deepLink: String?,
)

class EventsModel(val events: List<EventItem>, val st: Strs, val deepLink: String?)

object EventsModels {
    /** Widget, `startsAt < simdi - 1 saat` satiri kendisi eler (liste uygulamada bayat olabilir). */
    fun build(snap: JSONObject, nowMs: Long): EventsModel? {
        val items = snap.arr("events").objs().mapNotNull { e ->
            val title = e.str("title") ?: return@mapNotNull null
            val at = WidgetClock.parseIso(e.str("startsAt")) ?: return@mapNotNull null
            if (at < nowMs - 3_600_000L) return@mapNotNull null
            EventItem(
                e.str("id") ?: "", title, e.str("communityName"), at,
                e.str("day") ?: "", e.str("monthCaps") ?: "", e.str("timeLabel") ?: "",
                e.str("venue"), e.str("deepLink"),
            )
        }.sortedBy { it.startsAtMs }
        if (items.isEmpty()) return null
        return EventsModel(items, Strs(snap.obj("strings")), snap.str("deepLink"))
    }
}

// ====================================================================== ANNOUNCEMENTS
class AnnItem(
    val title: String, val urgent: Boolean, val urgentPrefix: String?, val meta: String?, val deepLink: String?,
)

class AnnModel(val items: List<AnnItem>, val st: Strs, val lastLabel: String?, val deepLink: String?)

object AnnModels {
    fun build(snap: JSONObject): AnnModel? {
        val items = snap.arr("items").objs().mapNotNull { i ->
            val title = i.str("title") ?: return@mapNotNull null
            val urgent = i.bool("urgent")
            val label = i.str("urgentLabel")
            val metaText = i.str("metaText")
            // metaText "Acil · Kutuphane · 02 Kas": Acil danger renginde ayri gosterilir, kalan meta ikincil
            val rest = if (urgent && label != null && metaText != null) {
                metaText.removePrefix(label).trimStart(' ', '·', '-').ifEmpty { null }
            } else metaText
            AnnItem(title, urgent && label != null, if (urgent && label != null) label else null, rest, i.str("deepLink"))
        }
        if (items.isEmpty()) return null
        return AnnModel(items, Strs(snap.obj("strings")), snap.str("lastLabel"), snap.str("deepLink"))
    }
}

// ====================================================================== POLL
class PollOption(val label: String, val percent: Int?, val percentText: String?)

class PollModel(
    val pollId: String, val question: String, val options: List<PollOption>,
    val userVoted: Boolean, val resultsVisible: Boolean,
    val microLine: String?, val secretLine: String?, val leaderIndex: Int?, val deepLink: String?, val st: Strs,
) {
    /** Yuzde/cubuk yalniz oy verilmis + sonuc gorunur + tum secenekte yuzde varsa (DATA_CONTRACT 5.5). */
    val showResults: Boolean get() = userVoted && resultsVisible && options.isNotEmpty() && options.all { it.percent != null }
}

object PollModels {
    fun build(snap: JSONObject): PollModel? {
        val id = snap.str("pollId") ?: return null
        val q = snap.str("question") ?: return null
        val opts = snap.arr("options").objs().mapNotNull { o ->
            val l = o.str("label") ?: return@mapNotNull null
            PollOption(l, o.int("percent")?.coerceIn(0, 100), o.str("percentText"))
        }.take(4)
        if (opts.size < 2) return null
        return PollModel(
            id, q, opts, snap.bool("userVoted"), snap.bool("resultsVisible"),
            snap.str("microLine"), snap.str("secretLine"), snap.int("leaderIndex"),
            snap.str("deepLink"), Strs(snap.obj("strings")),
        )
    }
}

// ====================================================================== QUICK ACCESS
class QuickItem(val id: String, val icon: String, val label: String, val a11y: String?, val deepLink: String)

class QuickModel(val items: List<QuickItem>, val small: List<QuickItem>, val st: Strs, val deepLink: String?)

object QuickModels {
    fun build(snap: JSONObject): QuickModel? {
        val items = snap.arr("items").objs().mapNotNull { i ->
            val id = i.str("id") ?: return@mapNotNull null
            val link = i.str("deepLink") ?: return@mapNotNull null
            QuickItem(id, i.str("icon") ?: "search", i.str("label") ?: "", i.str("a11yLabel"), link)
        }
        if (items.isEmpty()) return null
        val smallIds = snap.arr("smallIds").strs()
        val small = (if (smallIds.isEmpty()) items.take(4) else smallIds.mapNotNull { id -> items.firstOrNull { it.id == id } })
            .let { if (it.size >= 4) it.take(4) else items.take(4) }
        return QuickModel(items.take(8), small, Strs(snap.obj("strings")), snap.str("deepLink"))
    }
}

// ====================================================================== SOCIAL
class SocialModel(
    val messagesText: String, val notificationsText: String, val likesText: String,
    val messages: Int, val notifications: Int, val likes: Int,
    val linkMessages: String, val linkNotifications: String, val linkLikes: String, val linkHeader: String,
    val deepLink: String, val st: Strs,
)

object SocialModels {
    fun build(snap: JSONObject): SocialModel? {
        if (snap.bool("allZero")) return null
        val m = snap.int("unreadMessages") ?: 0
        val n = snap.int("newNotifications") ?: 0
        val l = snap.int("newLikesAndFollowers") ?: 0
        if (m + n + l <= 0) return null
        val links = snap.obj("links")
        val lm = links.str("messages") ?: "bukampus://chat"
        val ln = links.str("notifications") ?: "bukampus://notifications"
        val ll = links.str("likes") ?: "bukampus://discover"
        return SocialModel(
            snap.str("unreadMessagesText") ?: cap99(m), snap.str("newNotificationsText") ?: cap99(n),
            snap.str("newLikesAndFollowersText") ?: cap99(l), m, n, l, lm, ln, ll,
            links.str("header") ?: "bukampus://home",
            snap.str("deepLink") ?: (if (m > 0) lm else if (n > 0) ln else ll), Strs(snap.obj("strings")),
        )
    }

    fun cap99(n: Int): String = if (n > 99) "99+" else n.toString()
}
