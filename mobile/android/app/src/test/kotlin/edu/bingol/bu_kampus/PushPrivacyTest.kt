package edu.bingol.bu_kampus

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Kilit ekrani gizliligi + kanal secimi (saf). */
class PushPrivacyTest {
    @Test fun constantsMatchPlatform() {
        // android.app.Notification.VISIBILITY_PUBLIC = 1, VISIBILITY_PRIVATE = 0
        assertEquals(1, PushPrivacy.VISIBILITY_PUBLIC)
        assertEquals(0, PushPrivacy.VISIBILITY_PRIVATE)
    }

    @Test fun chatIsPublicByDefault() {
        val lock = PushPrivacy.lock("CHAT_DIRECT", hidePreview = false, lang = "tr")
        assertEquals(PushPrivacy.VISIBILITY_PUBLIC, lock.visibility)
        assertNull(lock.publicText)
    }

    @Test fun chatHidesWhenUserAsks() {
        val lock = PushPrivacy.lock("CHAT_GROUP", hidePreview = true, lang = "tr")
        assertEquals(PushPrivacy.VISIBILITY_PRIVATE, lock.visibility)
        assertEquals("Yeni mesaj", lock.publicText)
        assertEquals("New message", PushPrivacy.lock("CHAT_DIRECT", true, "en").publicText)
        assertEquals("3 yeni mesaj", PushPrivacy.lock("CHAT_DIRECT", true, "tr", 3).publicText)
    }

    @Test fun securityAndAccountAlwaysPrivate() {
        for (style in listOf("SECURITY", "MODERATION", "SUPPORT")) {
            val lock = PushPrivacy.lock(style, hidePreview = false, lang = "tr")
            assertEquals(style, PushPrivacy.VISIBILITY_PRIVATE, lock.visibility)
            assertTrue(style, !lock.publicText.isNullOrBlank())
        }
        assertEquals("Güvenlik bildirimi", PushPrivacy.generic("SECURITY", "tr"))
    }

    @Test fun otherCardsStayPublicEvenIfHideIsOn() {
        assertEquals(PushPrivacy.VISIBILITY_PUBLIC, PushPrivacy.lock("EVENT_REMINDER", true, "tr").visibility)
        assertEquals(PushPrivacy.VISIBILITY_PUBLIC, PushPrivacy.lock("EXAM", true, "tr").visibility)
    }

    @Test fun serverFlagOrStoredPreferenceRequestsHiding() {
        assertFalse(PushPrivacy.hideRequested(emptyMap(), false))
        assertTrue(PushPrivacy.hideRequested(emptyMap(), true))
        assertTrue(PushPrivacy.hideRequested(mapOf("hidePreview" to "1"), false))
        assertTrue(PushPrivacy.hideRequested(mapOf("hidePreview" to "true"), false))
        assertFalse(PushPrivacy.hideRequested(mapOf("hidePreview" to "0"), false))
    }

    @Test fun securityCardsUseSecurityChannelRegardlessOfServer() {
        val data = mapOf("style" to "SECURITY", "channelId" to "announcement", "title" to "t", "body" to "b")
        assertEquals("security", PushRenderPlan.channelFor(data, "SECURITY"))
        assertEquals("security", PushRenderPlan.of(data, 1, 0L, "x").channel)
        assertEquals("chat", PushRenderPlan.channelFor(mapOf("channelId" to "chat"), "CHAT_DIRECT"))
        assertEquals("announcement", PushRenderPlan.channelFor(mapOf("channelId" to "bilinmeyen"), "SYSTEM"))
        assertTrue("security" in PushRenderPlan.CHANNELS)
    }
}
