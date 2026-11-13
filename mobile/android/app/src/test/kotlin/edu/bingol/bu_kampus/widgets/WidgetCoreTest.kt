package edu.bingol.bu_kampus.widgets

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** Widget cekirdegi: kapi, secim, zaman, bozuk veri. Android bagimsiz (org.json test bagimliligi). */
class WidgetCoreTest {
    // 2026-11-06 10:00 Istanbul
    private val now = WidgetClock.parseIso("2026-11-06T10:00:00+03:00")!!

    private fun fixture(lang: String, name: String): String? {
        var dir: File? = File("").absoluteFile
        while (dir != null) {
            val f = File(dir, "design/widget-previews/examples/$lang/$name.json")
            if (f.exists()) return f.readText(Charsets.UTF_8)
            dir = dir.parentFile
        }
        return null
    }

    private val meta = """{"schema":1,"lang":"tr","rtl":false,"signedIn":true,"strings":{"signedOutTitle":"Giris yap","signedOutSub":"Ac"}}"""

    @Test fun isoParsing() {
        assertEquals("2026-11-06", WidgetClock.dateKey(now))
        assertEquals(600, WidgetClock.minuteOfDay(now))
        assertEquals(now, WidgetClock.parseIso("2026-11-06T07:00:00Z"))
        assertNull(WidgetClock.parseIso("bozuk"))
        assertNull(WidgetClock.parseIso(null))
    }

    @Test fun gateSignedOutVariants() {
        assertTrue(WidgetGate.resolve(null, null, now) is Gate.SignedOut)
        assertTrue(WidgetGate.resolve("{bozuk", "{}", now) is Gate.SignedOut)
        assertTrue(WidgetGate.resolve("""{"schema":1,"signedIn":false}""", """{"schema":1,"state":"ok"}""", now) is Gate.SignedOut)
        assertTrue(WidgetGate.resolve(meta, null, now) is Gate.SignedOut)
        assertTrue(WidgetGate.resolve(meta, "", now) is Gate.SignedOut)
        assertTrue(WidgetGate.resolve(meta, "[1,2]", now) is Gate.SignedOut)
        // schema > 1: guvenli geri dusus
        assertTrue(WidgetGate.resolve(meta, """{"schema":2,"state":"ok"}""", now) is Gate.SignedOut)
        assertTrue(WidgetGate.resolve("""{"schema":2,"signedIn":true}""", """{"schema":1}""", now) is Gate.SignedOut)
        val so = WidgetGate.resolve(meta, null, now) as Gate.SignedOut
        assertEquals("Giris yap", so.title)
    }

    @Test fun gateEmptyAndExpiry() {
        assertTrue(WidgetGate.resolve(meta, """{"schema":1,"state":"empty"}""", now) is Gate.Empty)
        val expired = """{"schema":1,"state":"ok","expiresAt":"2026-11-06T09:00:00+03:00"}"""
        assertTrue(WidgetGate.resolve(meta, expired, now) is Gate.Empty)
        val live = """{"schema":1,"state":"ok","expiresAt":"2026-11-06T11:00:00+03:00"}"""
        assertTrue(WidgetGate.resolve(meta, live, now) is Gate.Ok)
        assertTrue(WidgetGate.resolve(meta, """{"schema":1,"state":"ok","expiresAt":null}""", now) is Gate.Ok)
    }

    @Test fun menuSelectionByDate() {
        val snap = JSONObject(fixture("tr", "menu") ?: return)
        val m = MenuModels.build(snap, now)
        assertNotNull(m)
        assertEquals("Mercimek Çorbası", m!!.smallMeal(600).items.first().name)
        assertEquals("Tavuk Sote · Pilav · Salata", MenuModels.subLine(m.smallMeal(600)))
        // ertesi gun: upcoming[0]
        val next = WidgetClock.parseIso("2026-11-07T10:00:00+03:00")!!
        val m2 = MenuModels.build(snap, next)
        assertEquals("Cumartesi, 7 Kasım", m2!!.dateLabel)
        // eslesme yok -> bos durum
        assertNull(MenuModels.build(snap, WidgetClock.parseIso("2026-12-25T10:00:00+03:00")!!))
    }

    @Test fun menuEmptyFixture() {
        val snap = JSONObject(fixture("tr", "empty/menu") ?: return)
        assertNull(MenuModels.build(snap, now))
    }

    @Test fun timetableStates() {
        val snap = JSONObject(fixture("tr", "timetable") ?: return)
        val m = TimetableModels.build(snap, now)!!
        val st = TimetableModels.states(m.lessons, 600) // 10:00
        assertEquals(LessonState.NEXT, st[0])
        assertEquals(LessonState.LATER, st[1])
        val st2 = TimetableModels.states(m.lessons, 640) // 10:40: ilk ders suruyor
        assertEquals(LessonState.NOW, st2[0])
        assertEquals(LessonState.NEXT, st2[1])
        val st3 = TimetableModels.states(m.lessons, 930)
        assertTrue(st3.all { it == LessonState.PAST })
        assertEquals("18 dk sonra", TimetableModels.inText(m.st, 18))
        assertEquals("2 sa sonra", TimetableModels.inText(m.st, 130))
        assertEquals("1 sa sonra", TimetableModels.inText(m.st, 60))
    }

    @Test fun eventsDropsStaleRows() {
        val snap = JSONObject(fixture("tr", "events") ?: return)
        val ev = EventsModels.build(snap, now)!!
        assertEquals(2, ev.events.size)
        // 12 Kas 14:00'in 2 saat sonrasi: ilk etkinlik elenir (startsAt < simdi - 1 saat)
        val later = WidgetClock.parseIso("2026-11-12T16:00:00+03:00")!!
        assertEquals(1, EventsModels.build(snap, later)!!.events.size)
        assertNull(EventsModels.build(snap, WidgetClock.parseIso("2026-12-01T10:00:00+03:00")!!))
    }

    @Test fun pollResultsOnlyWhenVoted() {
        val snap = JSONObject(fixture("tr", "poll") ?: return)
        val p = PollModels.build(snap)!!
        assertTrue(p.showResults)
        snap.put("userVoted", false)
        assertTrue(!PollModels.build(snap)!!.showResults)
        assertNull(PollModels.build(JSONObject(fixture("tr", "empty/poll") ?: return)))
    }

    @Test fun socialAllZeroIsEmptyAndCaps() {
        assertNull(SocialModels.build(JSONObject(fixture("tr", "empty/social") ?: return)))
        assertEquals("99+", SocialModels.cap99(120))
        assertEquals("7", SocialModels.cap99(7))
    }

    @Test fun annUrgentSplit() {
        val j = JSONObject(
            """{"items":[{"title":"X","urgent":true,"urgentLabel":"Acil","metaText":"Acil · Kütüphane · 02 Kas","deepLink":"bukampus://news/1"}]}""",
        )
        val a = AnnModels.build(j)!!.items.first()
        assertTrue(a.urgent)
        assertEquals("Kütüphane · 02 Kas", a.meta)
    }

    @Test fun quickSmallIds() {
        val q = QuickModels.build(JSONObject(fixture("tr", "quickaccess") ?: return))!!
        assertEquals(listOf("menu", "events", "chat", "qr"), q.small.map { it.id })
        assertEquals(8, q.items.size)
    }

    @Test fun badJsonNeverThrows() {
        val junk = JSONObject("""{"schema":1,"items":"x","events":[1,null,{"title":5}],"options":[{}],"meals":{"a":1}}""")
        assertNull(AnnModels.build(junk))
        assertNull(EventsModels.build(junk, now))
        assertNull(PollModels.build(junk))
        assertNull(QuickModels.build(junk))
        assertNull(MenuModels.build(junk, now))
    }

    @Test fun fitRowsRule() {
        assertEquals(2, WidgetSizing.fit(90, 36, 4, 2))
        assertEquals(1, WidgetSizing.fit(10, 36, 4, 2))
        assertEquals(1, WidgetSizing.fit(0, 36, 4, 2))
        assertEquals(4, WidgetSizing.fit(400, 40, 6, 4))
        assertEquals(SizeClass.LARGE, WidgetSizing.classify(350, 350, SizeClass.SMALL))
        assertEquals(SizeClass.MEDIUM, WidgetSizing.classify(350, 170, SizeClass.SMALL))
        assertEquals(SizeClass.SMALL, WidgetSizing.classify(170, 350, SizeClass.MEDIUM))
        assertEquals(SizeClass.MEDIUM, WidgetSizing.classify(0, 0, SizeClass.MEDIUM))
    }

    @Test fun staleAfter24Hours() {
        val fresh = JSONObject("""{"generatedAt":"2026-11-06T09:00:00+03:00"}""")
        val old = JSONObject("""{"generatedAt":"2026-11-05T09:59:00+03:00"}""")
        val future = JSONObject("""{"generatedAt":"2026-11-07T09:00:00+03:00"}""")
        assertTrue(!WidgetGate.isStale(fresh, now))
        assertTrue(WidgetGate.isStale(old, now))
        assertTrue(!WidgetGate.isStale(future, now)) // gelecek zaman eski degildir
        assertTrue(!WidgetGate.isStale(JSONObject("{}"), now)) // alan yok: sahte uyari yok
        assertTrue(!WidgetGate.isStale(JSONObject("""{"generatedAt":"bozuk"}"""), now))
    }
}