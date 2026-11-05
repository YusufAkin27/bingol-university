package edu.bingol.bu_kampus

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Saf model katmani testleri: android/Flutter gerektirmez (FCM servisi ayni plani cizer). */
class PushRenderPlanTest {
    // 2026-11-05 12:00 UTC = 15:00 Istanbul
    private val now = PushTime.parse("2026-11-05T12:00:00Z")!!

    private fun plan(vararg kv: Pair<String, String>, count: Int = 1) =
        PushRenderPlan.of(mapOf(*kv), count, now, "fallback")

    @Test fun parsesIsoUtcAndFormatsInIstanbul() {
        val t = PushTime.parse("2026-11-06T11:00:00Z")!!
        assertEquals("14:00", PushTime.hhmm(t))
        assertEquals("Yarın", PushTime.dayLabel(t, now, "tr").first)
        assertEquals("Tomorrow", PushTime.dayLabel(t, now, "en").first)
        assertNull(PushTime.parse("bozuk"))
        assertEquals("14:00", PushTime.hhmm(PushTime.parse("2026-11-06T14:00:00+03:00")!!))
    }

    @Test fun styleComesFromServerAndOldPayloadsAreDerived() {
        assertEquals("CHAT_GROUP", PushSpec.style(mapOf("style" to "CHAT_GROUP")))
        assertEquals("SECURITY", PushSpec.style(mapOf("type" to "SYSTEM", "securityKind" to "NEW_DEVICE")))
        assertEquals("SYSTEM", PushSpec.style(mapOf("type" to "SYSTEM")))
        assertEquals("LIKE", PushSpec.style(mapOf("type" to "POST_LIKE")))
        assertEquals("CHAT_MEDIA", PushSpec.style(mapOf("type" to "MESSAGE", "imageUrl" to "https://x")))
    }

    @Test fun moderationIsNotSecurity() {
        val p = plan("style" to "MODERATION", "title" to "t", "body" to "b")
        assertEquals("MODERATION", p.style)
        assertEquals(listOf("open"), p.actions.map { it.id })
        assertFalse(p.critical)
    }

    @Test fun chatUsesSystemActionsWithRealReply() {
        val p = plan("style" to "CHAT_DIRECT", "conversationId" to "4", "messageId" to "9", "channelId" to "chat")
        assertTrue(p.systemActions)
        assertEquals(listOf("reply", "mark_read"), p.actions.map { it.id })
        val many = plan("style" to "CHAT_DIRECT", "conversationId" to "4", "messageId" to "9", count = 3)
        assertEquals(listOf("reply", "open"), many.actions.map { it.id })
        assertEquals("Hızlı Yanıtla", many.actions.first().label)
        assertNull(many.cornerBadge) // sayac rozeti ayri cizilir
        assertEquals(Glyph.GROUP, plan("style" to "CHAT_GROUP", "conversationId" to "4").cornerBadge)
    }

    @Test fun eventUpdateShowsOldAndNewTimeOnlyWhenBothPresent() {
        val p = plan("style" to "EVENT_UPDATE", "oldStartsAt" to "2026-11-06T10:00:00Z", "newStartsAt" to "2026-11-06T11:30:00Z", "badgeText" to "Saat Revizesi")
        val note = p.note
        assertNotNull(note)
        assertEquals("14:30", note!!.newTime)
        assertEquals("13:00", note.oldTime)
        assertEquals("Saat Revizesi", p.pill)
        assertEquals(listOf("ack", "open"), p.actions.map { it.id })
        assertNull(plan("style" to "EVENT_UPDATE", "eventStartsAt" to "2026-11-06T11:30:00Z").note)
    }

    @Test fun eventReminderChipsAndActionsFollowData() {
        val day = plan("style" to "EVENT_REMINDER", "eventStartsAt" to "2026-11-06T11:00:00Z", "location" to "Amfi")
        assertEquals("Yarın", day.headerChip)
        assertNull(day.pill) // zaman cipi sag ustte, baslikta tekrarlanmaz
        assertEquals(listOf("calendar", "map"), day.actions.map { it.id })
        assertEquals(listOf("calendar"), plan("style" to "EVENT_REMINDER", "eventStartsAt" to "2026-11-06T11:00:00Z").actions.map { it.id })
        val soon = plan("style" to "EVENT_REMINDER", "eventStartsAt" to "2026-11-05T13:00:00Z")
        assertEquals(listOf("checkin"), soon.actions.map { it.id })
    }

    @Test fun examChipNeedsData() {
        val p = plan("style" to "EXAM", "eventStartsAt" to "2026-11-06T07:00:00Z", "location" to "B-204")
        assertEquals("Yarın 10:00 · B-204", p.chips.single().text)
        assertTrue(plan("style" to "EXAM").chips.isEmpty())
    }

    @Test fun mealKcalOnlyWhenProvided() {
        assertEquals("Toplam 820 kcal", plan("style" to "MEAL", "totalKcal" to "820").chips.single().text)
        assertTrue(plan("style" to "MEAL").chips.isEmpty())
        assertTrue(plan("style" to "MEAL", "totalKcal" to "0").chips.isEmpty())
    }

    @Test fun securityActionsFollowKindAndCriticalStrip() {
        val d = plan("style" to "SECURITY", "securityKind" to "NEW_DEVICE", "severity" to "critical")
        assertTrue(d.critical)
        assertEquals("Bu ben değilim", d.actions.single().label)
        assertEquals("Hemen Sıfırla", plan("style" to "SECURITY", "securityKind" to "PASSWORD_CHANGED").actions.single().label)
        assertFalse(plan("style" to "SECURITY", "securityKind" to "TWOFA_ENABLED").critical)
    }

    @Test fun followAndLikeActions() {
        assertEquals(listOf("follow_accept", "follow_decline"), plan("style" to "FOLLOW_REQUEST", "userId" to "8").actions.map { it.id })
        assertTrue(plan("style" to "LIKE").actions.isEmpty())
        assertTrue(plan("style" to "FOLLOW").actions.isEmpty()) // kimlik yok -> islevsiz dugme gosterilmez
        assertEquals(Glyph.HEART, plan("style" to "LIKE").cornerBadge)
    }

    @Test fun importantAndBadgeRules() {
        val p = plan("style" to "ANNOUNCEMENT", "important" to "1")
        assertEquals("ÖNEMLİ", p.headerFlag)
        assertNull(p.pill)
        assertEquals("Son 24 saat", plan("style" to "POLL", "badgeText" to "Son 24 saat").pill)
        assertEquals("Hemen Doldur", plan("style" to "POLL", "badgeText" to "Son 24 saat").actions.single().label)
        assertEquals("Oy ver", plan("style" to "POLL").actions.single().label)
    }

    @Test fun sourceNameOverridesStyleLabel() {
        assertEquals("Yazılım Kulübü", plan("style" to "EVENT_REMINDER", "sourceName" to "Yazılım Kulübü").source)
        assertEquals("Etkinlik", plan("style" to "EVENT_REMINDER").source)
    }

    @Test fun localizedLabels() {
        assertEquals("Reply", plan("style" to "CHAT_GROUP", "conversationId" to "4", "locale" to "en").actions.first().label)
        assertEquals("Today", PushTime.dayLabel(now, now, "en").first)
    }

    @Test fun channelAndGroupAreSafe() {
        assertEquals("announcement", plan("style" to "ANNOUNCEMENT", "channelId" to "evil").channel)
        assertEquals("bu.chat", plan("style" to "CHAT_DIRECT", "channelId" to "chat").group)
        assertEquals("message:5", plan("style" to "CHAT_DIRECT", "messageId" to "5").tag)
    }

    @Test fun richDetectionLeavesSystemNotificationsAlone() {
        assertFalse(PushSpec.isRich(mapOf("style" to "EVENT_REMINDER", "title" to "t"), true))
        assertTrue(PushSpec.isRich(mapOf("style" to "EVENT_REMINDER", "title" to "t"), false))
        assertTrue(PushSpec.isRich(mapOf("richChat" to "1"), false))
        assertFalse(PushSpec.isRich(mapOf("type" to "NEWS"), false))
    }
}
