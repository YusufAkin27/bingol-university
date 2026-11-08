package edu.bingol.bu_kampus.widgets

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import edu.bingol.bu_kampus.R
import org.json.JSONObject

/**
 * RemoteViews cizimi (Glance degil: bkz. docs/MOBILE_WIDGETS_ANDROID.md karari). Yerlesimler uretilmis
 * `res/layout/bw_*.xml` (mobile/tool/gen_android_widgets_layouts.py); burada yalniz veri baglama, satir sayisi,
 * gorunurluk ve tiklama vardir. Renkler/olculer XML'de (tema degisince launcher yeniden cizer).
 */
internal object WidgetRenderer {
    private const val VISIBLE = View.VISIBLE
    private const val GONE = View.GONE
    private const val HOME = "bukampus://home"

    private class Env(
        val ctx: Context, val sz: SizeClass, val hDp: Int, val nowMs: Long, val rtl: Boolean,
    ) {
        val nowMin = WidgetClock.minuteOfDay(nowMs)

        /** Baslik altindaki kullanilabilir yukseklik: H - 2*16 - (baslik 16 + bosluk 12). */
        val avail: Int get() = hDp - 32 - 28
    }

    // ------------------------------------------------------------------ genel yardimcilar
    private fun rv(c: Env, layout: Int): RemoteViews {
        val r = RemoteViews(c.ctx.packageName, layout)
        r.setInt(R.id.bw_root, "setLayoutDirection", if (c.rtl) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR)
        return r
    }

    private fun RemoteViews.txt(id: Int, s: String?) {
        if (s.isNullOrEmpty()) {
            setViewVisibility(id, GONE)
        } else {
            setTextViewText(id, s)
            setViewVisibility(id, VISIBLE)
        }
    }

    private fun RemoteViews.show(id: Int, on: Boolean) = setViewVisibility(id, if (on) VISIBLE else GONE)

    private fun RemoteViews.icon(id: Int, name: String) = setImageViewResource(id, iconRes(name))

    fun iconRes(name: String): Int = when (name) {
        "vote" -> R.drawable.ic_w_vote
        "utensils" -> R.drawable.ic_w_utensils
        "calendar-clock" -> R.drawable.ic_w_calendar_clock
        "ticket" -> R.drawable.ic_w_ticket
        "users" -> R.drawable.ic_w_users
        "message-circle" -> R.drawable.ic_w_message_circle
        "qr-code" -> R.drawable.ic_w_qr_code
        "newspaper" -> R.drawable.ic_w_newspaper
        "bell" -> R.drawable.ic_w_bell
        "heart" -> R.drawable.ic_w_heart
        "lock" -> R.drawable.ic_w_lock
        "message-square" -> R.drawable.ic_w_message_square
        "circle-check" -> R.drawable.ic_w_circle_check
        "calendar" -> R.drawable.ic_w_calendar
        "clock" -> R.drawable.ic_w_clock
        "map-pin" -> R.drawable.ic_w_map_pin
        "megaphone" -> R.drawable.ic_w_megaphone
        "sun" -> R.drawable.ic_w_sun
        "moon" -> R.drawable.ic_w_moon
        "flame" -> R.drawable.ic_w_flame
        else -> R.drawable.ic_w_search
    }

    /** `bukampus://...` derin baglantisi (soguk + sicak acilis; uygulama app_links ile okur). Yalniz bukampus semasi. */
    private fun RemoteViews.click(c: Env, id: Int, link: String?) {
        val uri = safeLink(link) ?: Uri.parse(HOME)
        val intent = Intent(Intent.ACTION_VIEW, uri).setPackage(c.ctx.packageName)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val pi = PendingIntent.getActivity(c.ctx, 0, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        setOnClickPendingIntent(id, pi)
    }

    fun safeLink(link: String?): Uri? {
        if (link.isNullOrBlank()) return null
        return try {
            val u = Uri.parse(link)
            if (u.scheme == WidgetTokens.URL_SCHEME) u else null
        } catch (_: Throwable) {
            null
        }
    }

    // ------------------------------------------------------------------ giris noktasi
    fun render(ctx: Context, slug: WidgetSlug, sz: SizeClass, hDp: Int): RemoteViews {
        val nowMs = WidgetClock.nowMillis(ctx)
        val prefs = ctx.getSharedPreferences(WidgetTokens.PREFS_NAME, Context.MODE_PRIVATE)
        val gate = try {
            WidgetGate.resolve(prefs.getString(WidgetTokens.KEY_META, null), prefs.getString(slug.key, null), nowMs)
        } catch (_: Throwable) {
            Gate.SignedOut(null, null, false)
        }
        return when (gate) {
            is Gate.SignedOut -> signedOut(Env(ctx, sz, hDp, nowMs, gate.rtl), gate)
            is Gate.Empty -> bind(Env(ctx, sz, hDp, nowMs, gate.rtl), slug, gate.snap, true)
            is Gate.Ok -> bind(Env(ctx, sz, hDp, nowMs, gate.rtl), slug, gate.snap, false)
        }
    }

    private fun bind(c: Env, slug: WidgetSlug, snap: JSONObject, forceEmpty: Boolean): RemoteViews {
        val st = Strs(snap.obj("strings"))
        val link = snap.str("deepLink")
        val out: RemoteViews? = if (forceEmpty) null else try {
            when (slug) {
                WidgetSlug.MENU -> MenuModels.build(snap, c.nowMs)?.let { menu(c, it) }
                WidgetSlug.TIMETABLE -> TimetableModels.build(snap, c.nowMs)?.let { timetable(c, it) }
                WidgetSlug.EVENTS -> EventsModels.build(snap, c.nowMs)?.let { events(c, it) }
                // Sinavlar ve akademik takvim duyuru ile AYNI satir bicimini tasir (items[title, metaText, deepLink]).
                WidgetSlug.ANNOUNCEMENTS, WidgetSlug.EXAMS, WidgetSlug.ACADEMIC -> AnnModels.build(snap)?.let { announcements(c, it) }
                WidgetSlug.POLL -> PollModels.build(snap)?.let { poll(c, it) }
                WidgetSlug.QUICKACCESS -> QuickModels.build(snap)?.let { quick(c, it) }
                WidgetSlug.SOCIAL -> SocialModels.build(snap)?.let { social(c, it) }
            }
        } catch (t: Throwable) {
            android.util.Log.w("BuWidget", "render " + slug.slug, t)
            null
        }
        if (out != null) return out
        return empty(c, slug, snap, st, link)
    }

    private fun signedOut(c: Env, g: Gate.SignedOut): RemoteViews {
        val r = rv(c, R.layout.bw_signedout)
        r.setTextViewText(R.id.so_title, g.title ?: c.ctx.getString(R.string.bw_signed_out_title))
        r.setTextViewText(R.id.so_sub, g.sub ?: c.ctx.getString(R.string.bw_signed_out_sub))
        r.click(c, R.id.bw_root, HOME)
        return r
    }

    /** Debug/son care: hicbir sey cizilemezse bile cokme yok. */
    fun fallback(ctx: Context): RemoteViews {
        val c = Env(ctx, SizeClass.SMALL, 170, System.currentTimeMillis(), false)
        return signedOut(c, Gate.SignedOut(null, null, false))
    }

    // ------------------------------------------------------------------ bos durum
    private fun empty(c: Env, slug: WidgetSlug, snap: JSONObject, st: Strs, link: String?): RemoteViews {
        val small = c.sz == SizeClass.SMALL
        val sizeName = when (c.sz) { SizeClass.SMALL -> "small"; SizeClass.MEDIUM -> "medium"; SizeClass.LARGE -> "large" }
        val isText = slug == WidgetSlug.EVENTS || slug == WidgetSlug.ANNOUNCEMENTS || slug == WidgetSlug.EXAMS || slug == WidgetSlug.ACADEMIC
        val layout = if (isText) when (c.sz) {
            SizeClass.SMALL -> R.layout.bw_empty_text_small
            SizeClass.MEDIUM -> R.layout.bw_empty_text_medium
            SizeClass.LARGE -> R.layout.bw_empty_text_large
        } else when (c.sz) {
            SizeClass.SMALL -> R.layout.bw_empty_display_small
            SizeClass.MEDIUM -> R.layout.bw_empty_display_medium
            SizeClass.LARGE -> R.layout.bw_empty_display_large
        }
        val r = rv(c, layout)
        var title = st["emptyTitle"]
        var sub: String? = if (small) st.opt("emptySmallSub") else st.opt("emptySub")
        when (slug) {
            WidgetSlug.MENU -> {
                r.icon(R.id.e_hicon, "utensils")
                r.txt(R.id.e_hcap, if (small) st["captionAny"] else st["captionFull"])
            }
            WidgetSlug.TIMETABLE -> {
                r.icon(R.id.e_hicon, if (small) "clock" else "calendar")
                r.txt(R.id.e_hcap, if (small) st["captionNone"] else st["captionFull"])
                val next = snap.obj("next")
                sub = if (small) next.str("labelShort")?.let { st.fill("nextSmall", "day" to it) }
                else next.str("labelFull")?.let { st.fill("nextFull", "day" to it) }
            }
            WidgetSlug.POLL -> {
                r.icon(R.id.e_hicon, "vote")
                r.txt(R.id.e_hcap, if (small) st["caption"] else st["captionFull"])
            }
            WidgetSlug.SOCIAL -> {
                r.icon(R.id.e_hicon, "message-square")
                r.txt(R.id.e_hcap, if (small) st["captionEmpty"] else st["captionFull"])
                r.icon(R.id.e_icon, "circle-check")
                r.show(R.id.e_icon, true)
                sub = if (small) null else st.opt("emptySub")
            }
            WidgetSlug.EVENTS, WidgetSlug.ANNOUNCEMENTS, WidgetSlug.EXAMS, WidgetSlug.ACADEMIC -> {
                val ann = slug != WidgetSlug.EVENTS
                r.icon(R.id.e_icon, if (slug == WidgetSlug.ANNOUNCEMENTS) "megaphone" else "calendar")
                if (small) {
                    r.icon(R.id.e_hicon, if (slug == WidgetSlug.ANNOUNCEMENTS) "megaphone" else "calendar")
                    r.show(R.id.e_hicon, true)
                    r.txt(R.id.e_hcap, if (ann) st["titleSmall"] else st["captionEmpty"])
                    r.show(R.id.e_logo, false)
                    sub = null
                } else {
                    r.txt(R.id.e_hcap, if (ann) st["title"] else st["title"])
                    r.show(R.id.e_logo, true)
                    sub = st.opt("emptySub")
                }
            }
            WidgetSlug.QUICKACCESS -> {
                r.icon(R.id.e_hicon, "search")
                r.txt(R.id.e_hcap, st["caption"])
                title = st["heading"]
            }
        }
        if (!isText) {
            // display kind: ust satirda ikon + caption
        }
        r.setTextViewText(R.id.e_title, title)
        r.txt(R.id.e_sub, sub)
        r.click(c, R.id.bw_root, link ?: HOME)
        return r
    }

    // ------------------------------------------------------------------ MENU
    private fun menu(c: Env, m: MenuModel): RemoteViews {
        val st = m.st
        return when (c.sz) {
            SizeClass.SMALL -> {
                val r = rv(c, R.layout.bw_menu_small)
                val meal = m.smallMeal(c.nowMin)
                r.icon(R.id.mn_hicon, if (meal.id == "dinner") "moon" else "sun")
                r.txt(R.id.mn_hcap, meal.label)
                r.setTextViewText(R.id.mn_main, meal.items.first().name)
                r.txt(R.id.mn_sub, MenuModels.subLine(meal))
                r.show(R.id.mn_kcal_row, m.kcalLine != null)
                r.txt(R.id.mn_kcal, m.kcalLine)
                r.click(c, R.id.bw_root, "bukampus://menu")
                r
            }
            SizeClass.MEDIUM -> {
                val r = rv(c, R.layout.bw_menu_medium)
                r.txt(R.id.mn_hcap, m.dateLabel)
                val perCol = WidgetSizing.fit(c.avail - 22 - 20, 20, 0, 3) // alt satir (kcal) + sutun basligi payi
                val two = m.meals.size >= 2
                val col1: List<Dish>
                val col2: List<Dish>
                if (two) {
                    col1 = m.meals[0].items
                    col2 = m.meals[1].items
                    r.icon(R.id.mn_c1icon, if (m.meals[0].id == "dinner") "moon" else "sun")
                    r.txt(R.id.mn_c1cap, m.meals[0].label)
                    r.icon(R.id.mn_c2icon, if (m.meals[1].id == "dinner") "moon" else "sun")
                    r.txt(R.id.mn_c2cap, m.meals[1].label)
                } else {
                    val all = m.meals[0].items
                    col1 = all.take(perCol)
                    col2 = all.drop(perCol).take(perCol)
                    r.icon(R.id.mn_c1icon, if (m.meals[0].id == "dinner") "moon" else "sun")
                    r.txt(R.id.mn_c1cap, m.meals[0].label)
                    r.setViewVisibility(R.id.mn_c2head, View.INVISIBLE) // hizayi korur, ikinci sutunun basligi yok
                }
                val c1 = intArrayOf(R.id.mn_c1d0, R.id.mn_c1d1, R.id.mn_c1d2)
                val c2 = intArrayOf(R.id.mn_c2d0, R.id.mn_c2d1, R.id.mn_c2d2)
                for (i in 0 until 3) {
                    if (i < perCol && i < col1.size) r.txt(c1[i], col1[i].name) else r.show(c1[i], false)
                    if (i < perCol && i < col2.size) r.txt(c2[i], col2[i].name) else r.show(c2[i], false)
                }
                val showC2 = col2.isNotEmpty()
                r.show(R.id.mn_c2, showC2)
                r.show(R.id.mn_cdiv, showC2)
                r.show(R.id.mn_kcal_row, m.totalLine != null)
                r.txt(R.id.mn_total, m.totalLine)
                r.click(c, R.id.bw_root, "bukampus://menu")
                r
            }
            SizeClass.LARGE -> {
                val r = rv(c, R.layout.bw_menu_large)
                r.txt(R.id.mn_hcap, m.dateLabel)
                val unit = st["kcalUnit"]
                val two = m.meals.size >= 2
                // dikey butce: baslik 28 + chip 40 (36 + 4); iki bolumde ayirici 21, bolum basi 22
                val body = c.hDp - 32 - 28 - (if (m.totalText != null) 40 else 0)
                val perSection = if (two) WidgetSizing.fit((body - 21) / 2 - 22, 18, 2, 4) else WidgetSizing.fit(body - 22, 18, 2, 8)
                section(r, c, "a", m.meals[0], perSection, unit, st)
                if (two) {
                    section(r, c, "b", m.meals[1], perSection, unit, st)
                    r.show(R.id.mn_b, true)
                    r.show(R.id.mn_div, true)
                } else {
                    r.show(R.id.mn_b, false)
                    r.show(R.id.mn_div, false)
                }
                r.show(R.id.mn_chip, m.totalText != null)
                r.txt(R.id.mn_chiplbl, st["dailyTotal"])
                r.txt(R.id.mn_chiptot, m.totalText)
                r.click(c, R.id.bw_root, "bukampus://menu")
                r
            }
        }
    }

    private fun section(r: RemoteViews, c: Env, p: String, meal: Meal, cap: Int, unit: String, st: Strs) {
        val rows = if (p == "a") intArrayOf(R.id.mn_a_r0, R.id.mn_a_r1, R.id.mn_a_r2, R.id.mn_a_r3, R.id.mn_a_r4, R.id.mn_a_r5, R.id.mn_a_r6, R.id.mn_a_r7)
        else intArrayOf(R.id.mn_b_r0, R.id.mn_b_r1, R.id.mn_b_r2, R.id.mn_b_r3)
        val names = if (p == "a") intArrayOf(R.id.mn_a_d0, R.id.mn_a_d1, R.id.mn_a_d2, R.id.mn_a_d3, R.id.mn_a_d4, R.id.mn_a_d5, R.id.mn_a_d6, R.id.mn_a_d7)
        else intArrayOf(R.id.mn_b_d0, R.id.mn_b_d1, R.id.mn_b_d2, R.id.mn_b_d3)
        val kc = if (p == "a") intArrayOf(R.id.mn_a_k0, R.id.mn_a_k1, R.id.mn_a_k2, R.id.mn_a_k3, R.id.mn_a_k4, R.id.mn_a_k5, R.id.mn_a_k6, R.id.mn_a_k7)
        else intArrayOf(R.id.mn_b_k0, R.id.mn_b_k1, R.id.mn_b_k2, R.id.mn_b_k3)
        val icon = if (p == "a") R.id.mn_aicon else R.id.mn_bicon
        val capId = if (p == "a") R.id.mn_acap else R.id.mn_bcap
        val tot = if (p == "a") R.id.mn_atot else R.id.mn_btot
        val more = if (p == "a") R.id.mn_amore else R.id.mn_bmore
        r.icon(icon, if (meal.id == "dinner") "moon" else "sun")
        r.txt(capId, meal.label)
        r.txt(tot, meal.totalText)
        // fazla yemek varsa son satir "+N yemek" olur (satir sayisi tavani korunur)
        val overflow = meal.items.size > cap
        val shown = if (overflow) maxOf(1, cap - 1) else cap
        for (i in rows.indices) {
            if (i < shown && i < meal.items.size) {
                r.show(rows[i], true)
                r.setTextViewText(names[i], meal.items[i].name)
                val k = meal.items[i].kcalText?.removeSuffix(" $unit")?.trim()
                r.txt(kc[i], k)
            } else r.show(rows[i], false)
        }
        if (overflow) {
            r.txt(more, st.fill("more", "n" to (meal.items.size - shown).toString()))
        } else r.show(more, false)
    }

    // ------------------------------------------------------------------ TIMETABLE
    private fun timetable(c: Env, m: TimetableModel): RemoteViews? {
        val st = m.st
        val states = TimetableModels.states(m.lessons, c.nowMin)
        val liveIdx = states.indexOfFirst { it == LessonState.NOW || it == LessonState.NEXT }
        if (liveIdx < 0) return null // bugunun dersleri bitti: bos durum (+ sonraki ders)
        return when (c.sz) {
            SizeClass.SMALL -> {
                val r = rv(c, R.layout.bw_timetable_small)
                val l = m.lessons[liveIdx]
                r.icon(R.id.tt_hicon, "clock")
                r.txt(R.id.tt_hcap, st["captionNext"])
                if (states[liveIdx] == LessonState.NOW) {
                    r.setTextViewText(R.id.tt_badge, st["nowBadge"])
                    r.txt(R.id.tt_in, st.fill("endsAt", "time" to l.end))
                } else {
                    r.setTextViewText(R.id.tt_badge, l.start)
                    r.txt(R.id.tt_in, TimetableModels.inText(st, l.startMin - c.nowMin))
                }
                r.setTextViewText(R.id.tt_title, l.title)
                r.show(R.id.tt_room_row, l.room != null)
                r.txt(R.id.tt_room, l.room)
                r.click(c, R.id.bw_root, "bukampus://timetable")
                r
            }
            SizeClass.MEDIUM -> {
                val r = rv(c, R.layout.bw_timetable_medium)
                r.icon(R.id.tt_hicon, "clock")
                r.txt(R.id.tt_hcap, st.fill("headerNext", "date" to m.dateLabel))
                val n = WidgetSizing.fit(c.avail, 36, 4, 2)
                ttRows(r, c, m, states, windowStart(m.lessons.size, liveIdx, n), n, intArrayOf(R.id.tt_r0, R.id.tt_r1), 2)
                r.click(c, R.id.bw_root, "bukampus://timetable")
                r
            }
            SizeClass.LARGE -> {
                val r = rv(c, R.layout.bw_timetable_large)
                r.icon(R.id.tt_hicon, "calendar")
                r.txt(R.id.tt_hcap, m.dateLabel)
                r.txt(R.id.tt_count, st.fill("todayCount", "n" to m.count.toString()))
                val l = m.lessons[liveIdx]
                r.txt(R.id.tt_in, if (states[liveIdx] == LessonState.NOW) st.fill("endsAt", "time" to l.end)
                else TimetableModels.inText(st, l.startMin - c.nowMin))
                // baslik 28 + sayi satiri 34 + alt not 22
                val n = WidgetSizing.fit(c.avail - 34 - 22, 40, 6, 4)
                val start = windowStart(m.lessons.size, liveIdx, n)
                ttRows(r, c, m, states, start, n, intArrayOf(R.id.tt_r0, R.id.tt_r1, R.id.tt_r2, R.id.tt_r3), 4)
                val hidden = m.lessons.size - (start + minOf(n, m.lessons.size - start))
                if (hidden > 0) r.txt(R.id.tt_foot, st.fill("more", "n" to hidden.toString()))
                else r.txt(R.id.tt_foot, st.fill("lastEnds", "time" to (m.lessons.last().end)))
                r.click(c, R.id.bw_root, "bukampus://timetable")
                r
            }
        }
    }

    /** Siradaki dersten baslayan n satirlik pencere; sonda yer kalmazsa geriye kayar (gecmis dersler soluk gorunur). */
    private fun windowStart(size: Int, liveIdx: Int, n: Int): Int = if (size - liveIdx >= n) liveIdx else maxOf(0, size - n)

    private fun ttRows(r: RemoteViews, c: Env, m: TimetableModel, states: List<LessonState>, start: Int, n: Int, rows: IntArray, slots: Int) {
        val badge = intArrayOf(R.id.tt_r0_badge, R.id.tt_r1_badge, R.id.tt_r2_badge, R.id.tt_r3_badge)
        val t1 = intArrayOf(R.id.tt_r0_t1, R.id.tt_r1_t1, R.id.tt_r2_t1, R.id.tt_r3_t1)
        val t2 = intArrayOf(R.id.tt_r0_t2, R.id.tt_r1_t2, R.id.tt_r2_t2, R.id.tt_r3_t2)
        val title = intArrayOf(R.id.tt_r0_title, R.id.tt_r1_title, R.id.tt_r2_title, R.id.tt_r3_title)
        val pin = intArrayOf(R.id.tt_r0_pin, R.id.tt_r1_pin, R.id.tt_r2_pin, R.id.tt_r3_pin)
        val room = intArrayOf(R.id.tt_r0_room, R.id.tt_r1_room, R.id.tt_r2_room, R.id.tt_r3_room)
        for (i in 0 until slots) {
            val idx = start + i
            if (i >= n || idx >= m.lessons.size) {
                r.show(rows[i], false)
                continue
            }
            val l = m.lessons[idx]
            val s = states[idx]
            r.show(rows[i], true)
            val live = s == LessonState.NOW || s == LessonState.NEXT
            if (live && idx == states.indexOfFirst { it == LessonState.NOW || it == LessonState.NEXT }) {
                r.setInt(rows[i], "setBackgroundResource", R.drawable.bw_chip12)
                r.setTextViewText(badge[i], l.start)
                r.show(badge[i], true)
                r.show(t1[i], false)
                r.show(t2[i], false)
            } else if (s == LessonState.PAST) {
                r.setFloat(rows[i], "setAlpha", WidgetTokens.OPACITY_PAST_LESSON)
                r.setTextViewText(t2[i], l.start)
                r.show(t2[i], true)
                r.show(badge[i], false)
                r.show(t1[i], false)
            } else {
                r.setTextViewText(t1[i], l.start)
                r.show(t1[i], true)
                r.show(badge[i], false)
                r.show(t2[i], false)
            }
            r.setTextViewText(title[i], l.title)
            r.show(pin[i], l.room != null)
            r.txt(room[i], l.room)
        }
    }

    // ------------------------------------------------------------------ EVENTS
    private fun events(c: Env, m: EventsModel): RemoteViews {
        val st = m.st
        return when (c.sz) {
            SizeClass.SMALL -> {
                val r = rv(c, R.layout.bw_events_small)
                val e = m.events.first()
                r.txt(R.id.ev_hcap, st["captionSmall"])
                r.setTextViewText(R.id.ev_day, e.day)
                r.setTextViewText(R.id.ev_mon, e.monthCaps)
                r.setTextViewText(R.id.ev_title, e.title)
                r.txt(R.id.ev_time, e.time)
                r.click(c, R.id.bw_root, e.deepLink ?: m.deepLink)
                r
            }
            SizeClass.MEDIUM -> {
                val r = rv(c, R.layout.bw_events_medium)
                r.txt(R.id.ev_hcap, st["title"])
                val n = WidgetSizing.fit(c.avail - 6 /* baslik 14 yerine 16: 2dp pay */, 36, 3, WidgetTokens.EVENTS_MEDIUM)
                val ids = arrayOf(
                    intArrayOf(R.id.ev_r0, R.id.ev_r0_day, R.id.ev_r0_mon, R.id.ev_r0_title, R.id.ev_r0_club, R.id.ev_r0_time),
                    intArrayOf(R.id.ev_r1, R.id.ev_r1_day, R.id.ev_r1_mon, R.id.ev_r1_title, R.id.ev_r1_club, R.id.ev_r1_time),
                    intArrayOf(R.id.ev_r2, R.id.ev_r2_day, R.id.ev_r2_mon, R.id.ev_r2_title, R.id.ev_r2_club, R.id.ev_r2_time),
                )
                for (i in 0 until 3) evRow(r, c, ids[i], m.events.getOrNull(i)?.takeIf { i < n })
                r.click(c, R.id.bw_root, m.deepLink ?: "bukampus://events")
                r
            }
            SizeClass.LARGE -> {
                val r = rv(c, R.layout.bw_events_large)
                r.txt(R.id.ev_hcap, st["title"])
                val shown = minOf(3, m.events.size, WidgetSizing.fit(c.avail - 17, 56, 1, 3))
                r.txt(R.id.ev_count, st.fill("countLabel", "n" to shown.toString()))
                val ids = arrayOf(
                    intArrayOf(R.id.ev_r0, R.id.ev_r0_day, R.id.ev_r0_mon, R.id.ev_r0_title, R.id.ev_r0_club, R.id.ev_r0_time),
                    intArrayOf(R.id.ev_r1, R.id.ev_r1_day, R.id.ev_r1_mon, R.id.ev_r1_title, R.id.ev_r1_club, R.id.ev_r1_time),
                    intArrayOf(R.id.ev_r2, R.id.ev_r2_day, R.id.ev_r2_mon, R.id.ev_r2_title, R.id.ev_r2_club, R.id.ev_r2_time),
                )
                val venueG = intArrayOf(R.id.ev_r0_vg, R.id.ev_r1_vg, R.id.ev_r2_vg)
                val venue = intArrayOf(R.id.ev_r0_venue, R.id.ev_r1_venue, R.id.ev_r2_venue)
                val divs = intArrayOf(0, R.id.ev_div1, R.id.ev_div2)
                for (i in 0 until 3) {
                    val e = m.events.getOrNull(i)?.takeIf { i < shown }
                    evRow(r, c, ids[i], e)
                    if (divs[i] != 0) r.show(divs[i], e != null)
                    r.show(venueG[i], e?.venue != null)
                    r.txt(venue[i], e?.venue)
                }
                r.click(c, R.id.bw_root, m.deepLink ?: "bukampus://events")
                r
            }
        }
    }

    private fun evRow(r: RemoteViews, c: Env, id: IntArray, e: EventItem?) {
        if (e == null) {
            r.show(id[0], false)
            return
        }
        r.show(id[0], true)
        r.setTextViewText(id[1], e.day)
        r.setTextViewText(id[2], e.monthCaps)
        r.setTextViewText(id[3], e.title)
        r.txt(id[4], e.club)
        r.txt(id[5], e.time)
        r.click(c, id[0], e.deepLink)
    }

    // ------------------------------------------------------------------ ANNOUNCEMENTS
    private fun announcements(c: Env, m: AnnModel): RemoteViews {
        val st = m.st
        return when (c.sz) {
            SizeClass.SMALL -> {
                val r = rv(c, R.layout.bw_announcements_small)
                val a = m.items.first()
                r.txt(R.id.an_hcap, st["titleSmall"])
                r.setTextViewText(R.id.an_title, a.title)
                annMeta(r, R.id.an_urg, R.id.an_meta, a)
                r.click(c, R.id.bw_root, a.deepLink ?: m.deepLink)
                r
            }
            SizeClass.MEDIUM -> {
                val r = rv(c, R.layout.bw_announcements_medium)
                r.txt(R.id.an_hcap, st["title"])
                val n = WidgetSizing.fit(c.avail - 6, 36, 3, 3)
                val rows = intArrayOf(R.id.an_r0, R.id.an_r1, R.id.an_r2)
                val dots = intArrayOf(R.id.an_r0_dot, R.id.an_r1_dot, R.id.an_r2_dot)
                val dotd = intArrayOf(R.id.an_r0_dotd, R.id.an_r1_dotd, R.id.an_r2_dotd)
                val titles = intArrayOf(R.id.an_r0_title, R.id.an_r1_title, R.id.an_r2_title)
                val urg = intArrayOf(R.id.an_r0_urg, R.id.an_r1_urg, R.id.an_r2_urg)
                val meta = intArrayOf(R.id.an_r0_meta, R.id.an_r1_meta, R.id.an_r2_meta)
                for (i in 0 until 3) {
                    val a = m.items.getOrNull(i)?.takeIf { i < n }
                    if (a == null) { r.show(rows[i], false); continue }
                    r.show(rows[i], true)
                    r.setTextViewText(titles[i], a.title)
                    r.show(dots[i], !a.urgent)
                    r.show(dotd[i], a.urgent)
                    annMeta(r, urg[i], meta[i], a)
                    r.click(c, rows[i], a.deepLink)
                }
                r.click(c, R.id.bw_root, m.deepLink ?: "bukampus://news")
                r
            }
            SizeClass.LARGE -> {
                val r = rv(c, R.layout.bw_announcements_large)
                r.txt(R.id.an_hcap, st["title"])
                val shown = minOf(4, m.items.size, WidgetSizing.fit(c.avail - 17, 48, 1, 4))
                r.txt(R.id.an_last, if (shown == m.items.size && m.lastLabel != null) m.lastLabel else st.fill("last", "n" to shown.toString()))
                val rows = intArrayOf(R.id.an_r0, R.id.an_r1, R.id.an_r2, R.id.an_r3)
                val divs = intArrayOf(0, R.id.an_div1, R.id.an_div2, R.id.an_div3)
                val titles = intArrayOf(R.id.an_r0_title, R.id.an_r1_title, R.id.an_r2_title, R.id.an_r3_title)
                val urg = intArrayOf(R.id.an_r0_urg, R.id.an_r1_urg, R.id.an_r2_urg, R.id.an_r3_urg)
                val meta = intArrayOf(R.id.an_r0_meta, R.id.an_r1_meta, R.id.an_r2_meta, R.id.an_r3_meta)
                for (i in 0 until 4) {
                    val a = m.items.getOrNull(i)?.takeIf { i < shown }
                    r.show(rows[i], a != null)
                    if (divs[i] != 0) r.show(divs[i], a != null)
                    if (a == null) continue
                    r.setTextViewText(titles[i], a.title)
                    annMeta(r, urg[i], meta[i], a)
                    r.click(c, rows[i], a.deepLink)
                }
                r.click(c, R.id.bw_root, m.deepLink ?: "bukampus://news")
                r
            }
        }
    }

    private fun annMeta(r: RemoteViews, urgId: Int, metaId: Int, a: AnnItem) {
        if (a.urgent) {
            r.txt(urgId, if (a.meta != null) a.urgentPrefix + " · " else a.urgentPrefix)
        } else r.show(urgId, false)
        r.txt(metaId, a.meta)
    }

    // ------------------------------------------------------------------ POLL
    private fun poll(c: Env, m: PollModel): RemoteViews {
        val st = m.st
        val link = m.deepLink ?: "bukampus://poll/${m.pollId}"
        return when (c.sz) {
            SizeClass.SMALL -> {
                val r = rv(c, R.layout.bw_poll_small)
                r.txt(R.id.pl_hcap, st["caption"])
                r.setTextViewText(R.id.pl_q, m.question)
                if (m.userVoted) {
                    r.show(R.id.pl_pill, false)
                    r.txt(R.id.pl_voted, st["voted"])
                } else {
                    r.txt(R.id.pl_pill, st["vote"])
                    r.show(R.id.pl_voted, false)
                }
                r.click(c, R.id.bw_root, link)
                r
            }
            SizeClass.MEDIUM -> {
                val r = rv(c, R.layout.bw_poll_medium)
                r.txt(R.id.pl_hcap, st["captionFull"])
                r.setTextViewText(R.id.pl_q, m.question)
                r.txt(R.id.pl_micro, if (m.showResults) m.microLine else null)
                pollOptions(r, m, 3, intArrayOf(R.id.pl_o0, R.id.pl_o1, R.id.pl_o2, 0), false)
                r.show(R.id.pl_pill, !m.showResults)
                if (!m.showResults) r.txt(R.id.pl_pill, st["vote"])
                r.click(c, R.id.bw_root, link)
                r
            }
            SizeClass.LARGE -> {
                val r = rv(c, R.layout.bw_poll_large)
                r.txt(R.id.pl_hcap, st["captionFull"])
                r.setTextViewText(R.id.pl_q, m.question)
                pollOptions(r, m, 4, intArrayOf(R.id.pl_o0, R.id.pl_o1, R.id.pl_o2, R.id.pl_o3), true)
                r.show(R.id.pl_pill, !m.showResults)
                if (!m.showResults) r.txt(R.id.pl_pill, st["vote"])
                r.show(R.id.pl_bottom, true)
                r.show(R.id.pl_lock, m.secretLine != null)
                r.txt(R.id.pl_secret, m.secretLine)
                r.txt(R.id.pl_detail, st["detail"])
                r.click(c, R.id.bw_root, link)
                r
            }
        }
    }

    private fun pollOptions(r: RemoteViews, m: PollModel, max: Int, blocks: IntArray, large: Boolean) {
        val lbl = intArrayOf(R.id.pl_o0_lbl, R.id.pl_o1_lbl, R.id.pl_o2_lbl, R.id.pl_o3_lbl)
        val p1 = intArrayOf(R.id.pl_o0_pct1, R.id.pl_o1_pct1, R.id.pl_o2_pct1, R.id.pl_o3_pct1)
        val p2 = intArrayOf(R.id.pl_o0_pct2, R.id.pl_o1_pct2, R.id.pl_o2_pct2, R.id.pl_o3_pct2)
        val ba = intArrayOf(R.id.pl_o0_barA, R.id.pl_o1_barA, R.id.pl_o2_barA, R.id.pl_o3_barA)
        val bb = intArrayOf(R.id.pl_o0_barB, R.id.pl_o1_barB, R.id.pl_o2_barB, R.id.pl_o3_barB)
        for (i in 0 until (if (large) 4 else 3)) {
            val o = m.options.getOrNull(i)?.takeIf { i < max }
            if (blocks[i] == 0) continue
            if (o == null) { r.show(blocks[i], false); continue }
            r.show(blocks[i], true)
            r.setTextViewText(lbl[i], o.label)
            if (m.showResults) {
                val leader = if (m.leaderIndex == null) true else m.leaderIndex == i
                r.setTextViewText(p1[i], o.percentText ?: "%${o.percent}")
                r.setTextViewText(p2[i], o.percentText ?: "%${o.percent}")
                r.show(p1[i], leader)
                r.show(p2[i], !leader)
                r.show(ba[i], leader)
                r.show(bb[i], !leader)
                r.setProgressBar(if (leader) ba[i] else bb[i], 100, o.percent ?: 0, false)
            } else {
                r.show(p1[i], false); r.show(p2[i], false); r.show(ba[i], false); r.show(bb[i], false)
            }
        }
    }

    // ------------------------------------------------------------------ QUICK ACCESS
    private fun quick(c: Env, m: QuickModel): RemoteViews {
        val st = m.st
        val tiles = intArrayOf(R.id.qa_t0, R.id.qa_t1, R.id.qa_t2, R.id.qa_t3, R.id.qa_t4, R.id.qa_t5, R.id.qa_t6, R.id.qa_t7)
        val icons = intArrayOf(R.id.qa_i0, R.id.qa_i1, R.id.qa_i2, R.id.qa_i3, R.id.qa_i4, R.id.qa_i5, R.id.qa_i6, R.id.qa_i7)
        val labels = intArrayOf(R.id.qa_l0, R.id.qa_l1, R.id.qa_l2, R.id.qa_l3, R.id.qa_l4, R.id.qa_l5, R.id.qa_l6, R.id.qa_l7)
        val r: RemoteViews
        val list: List<QuickItem>
        when (c.sz) {
            SizeClass.SMALL -> { r = rv(c, R.layout.bw_quickaccess_small); list = m.small }
            SizeClass.MEDIUM -> {
                r = rv(c, R.layout.bw_quickaccess_medium); list = m.items
                r.txt(R.id.qa_hcap, st["caption"])
            }
            SizeClass.LARGE -> {
                r = rv(c, R.layout.bw_quickaccess_large); list = m.items
                r.txt(R.id.qa_hcap, st["caption"])
                r.txt(R.id.qa_heading, st["heading"])
                r.txt(R.id.qa_sub, st["sub"])
            }
        }
        val count = if (c.sz == SizeClass.SMALL) 4 else 8
        for (i in 0 until count) {
            val it = list.getOrNull(i)
            if (it == null) { r.setViewVisibility(tiles[i], View.INVISIBLE); continue }
            r.icon(icons[i], it.icon)
            r.setTextViewText(labels[i], it.label)
            r.setContentDescription(tiles[i], it.a11y ?: it.label)
            r.click(c, tiles[i], it.deepLink)
        }
        r.click(c, R.id.bw_root, m.deepLink ?: HOME)
        return r
    }

    // ------------------------------------------------------------------ SOCIAL
    private fun social(c: Env, m: SocialModel): RemoteViews {
        val st = m.st
        return when (c.sz) {
            SizeClass.SMALL -> {
                val r = rv(c, R.layout.bw_social_small)
                r.txt(R.id.sc_hcap, st["captionSmall"])
                r.setTextViewText(R.id.sc_num, m.messagesText)
                r.txt(R.id.sc_sub, st["unreadSmall"])
                r.setTextViewText(R.id.sc_n2, m.notificationsText)
                r.setTextViewText(R.id.sc_n3, m.likesText)
                r.click(c, R.id.bw_root, m.deepLink)
                r
            }
            SizeClass.MEDIUM -> {
                val r = rv(c, R.layout.bw_social_medium)
                r.txt(R.id.sc_hcap, st["captionFull"])
                val nums = arrayOf(m.messagesText, m.notificationsText, m.likesText)
                val lbls = arrayOf(st["labelMessages"], st["labelNotifications"], st["labelLikes"])
                val links = arrayOf(m.linkMessages, m.linkNotifications, m.linkLikes)
                val cols = intArrayOf(R.id.sc_c0, R.id.sc_c1, R.id.sc_c2)
                val n = intArrayOf(R.id.sc_c0_n, R.id.sc_c1_n, R.id.sc_c2_n)
                val l = intArrayOf(R.id.sc_c0_l, R.id.sc_c1_l, R.id.sc_c2_l)
                for (i in 0 until 3) {
                    r.setTextViewText(n[i], nums[i]); r.setTextViewText(l[i], lbls[i]); r.click(c, cols[i], links[i])
                }
                r.click(c, R.id.bw_root, m.linkHeader)
                r
            }
            SizeClass.LARGE -> {
                val r = rv(c, R.layout.bw_social_large)
                r.txt(R.id.sc_hcap, st["captionFull"])
                r.txt(R.id.sc_heading, st["heading"])
                r.txt(R.id.sc_note, st["privacyNote"])
                val nums = arrayOf(m.messagesText, m.notificationsText, m.likesText)
                val lbls = arrayOf(st["rowMessages"], st["rowNotifications"], st["rowLikes"])
                val subs = arrayOf(st["subMessages"], st["subNotifications"], st["subLikes"])
                val links = arrayOf(m.linkMessages, m.linkNotifications, m.linkLikes)
                val rows = intArrayOf(R.id.sc_r0, R.id.sc_r1, R.id.sc_r2)
                val rn = intArrayOf(R.id.sc_r0_n, R.id.sc_r1_n, R.id.sc_r2_n)
                val rl = intArrayOf(R.id.sc_r0_l, R.id.sc_r1_l, R.id.sc_r2_l)
                val rs = intArrayOf(R.id.sc_r0_s, R.id.sc_r1_s, R.id.sc_r2_s)
                // yukseklik azsa son satirlar dusmez ama kalan alan dar kalirsa not satiri gizlenir
                val showNote = c.hDp >= 330
                r.show(R.id.sc_note, showNote && st.opt("privacyNote") != null)
                for (i in 0 until 3) {
                    r.setTextViewText(rn[i], nums[i]); r.setTextViewText(rl[i], lbls[i]); r.txt(rs[i], subs[i])
                    r.click(c, rows[i], links[i])
                }
                r.click(c, R.id.bw_root, m.linkHeader)
                r
            }
        }
    }

    /** Yalniz debuggable (debug) derlemede saat gecersiz kilinabilir: release'e sizmaz. */
    fun isDebuggable(ctx: Context): Boolean = (ctx.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
}
