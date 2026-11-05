package edu.bingol.backend.notification;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.*;

import edu.bingol.backend.notification.fcm.PushMessage;
import java.time.Instant;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;
import org.junit.jupiter.api.Test;

/** Bildirim tasarimi yuk sozlesmesi (docs/changes/push.md): style, medya kurali, BU_ kategorisi, kapali uygulama teslimi. */
class NotifDesignContractTest {

    private static PushMessage message(NotificationType t, NotificationSubtype s, Map<String, String> in) {
        return PushMessages.of(t, s, "Baslik", "Govde", PushPayload.build(t, s, in, 1), null, 1);
    }

    @Test
    void styleIsPresentOnEveryPushAndCannotBeSpoofed() {
        var payload = PushPayload.build(NotificationType.EVENT, NotificationSubtype.EVENT_REMINDER,
                Map.of("eventId", "4", "style", "SECURITY"), 1);
        assertEquals("EVENT_REMINDER", payload.get("style"));
        assertEquals("ANNOUNCEMENT", PushPayload.build(NotificationType.NEWS, null, Map.of("newsId", "1"), 1).get("style"));
        // kaynak sitenin etkinligi (newsId) etkinlik kaydi sayilmaz
        assertEquals("ANNOUNCEMENT", PushPayload.build(NotificationType.EVENT, null, Map.of("newsId", "1"), 1).get("style"));
    }

    @Test
    void newStylesAreDerivedOnTheServer() {
        assertEquals("EVENT_CANCELLED", RichPushPayload.style(Map.of("type", "EVENT", "subtype", "EVENT_UPDATE", "eventChange", "CANCELLED")));
        assertEquals("EVENT_UPDATE", RichPushPayload.style(Map.of("type", "EVENT", "subtype", "EVENT_UPDATE", "eventChange", "TIME")));
        assertEquals("LIKE", RichPushPayload.style(Map.of("type", "POST_LIKE")));
        assertEquals("SOCIAL", RichPushPayload.style(Map.of("type", "POST_COMMENT")));
        assertEquals("FOLLOW", RichPushPayload.style(Map.of("type", "USER_FOLLOW")));
        assertEquals("MEAL", RichPushPayload.style(Map.of("type", "ANNOUNCEMENT", "subtype", "MEAL_MENU")));
        assertEquals("SECURITY", RichPushPayload.style(Map.of("type", "SYSTEM", "securityKind", "TWOFA_DISABLED")));
        assertEquals("MODERATION", RichPushPayload.style(Map.of("type", "SYSTEM", "moderation", "1")));
        assertEquals("SYSTEM", RichPushPayload.style(Map.of("type", "SYSTEM")));
        assertEquals("SUPPORT", RichPushPayload.style(Map.of("type", "SYSTEM", "ticketId", "3")));
    }

    @Test
    void apnsCategoryIsBuPlusStyleForEveryPlatform() {
        assertEquals("BU_EVENT_REMINDER", message(NotificationType.EVENT, NotificationSubtype.EVENT_REMINDER,
                Map.of("eventId", "4")).category());
        assertEquals("BU_LIKE", message(NotificationType.POST_LIKE, NotificationSubtype.POST_LIKE, Map.of("postId", "1")).category());
        assertEquals("BU_SYSTEM", message(NotificationType.SYSTEM, null, Map.of()).category());
    }

    @Test
    void mediaAcceptsOwnHostAndCampusSubdomainsOnly() {
        String base = "https://bukampus.com.tr";
        assertEquals("https://bukampus.com.tr/files/a.jpg", RichChatPayload.mediaUrl(base, "/files/a.jpg"));
        assertEquals("https://bukampus.com.tr/files/a.jpg", RichChatPayload.mediaUrl(base, "files/a.jpg"));
        assertEquals("https://www.bingol.edu.tr/media/1.jpg", RichChatPayload.mediaUrl(base, "https://www.bingol.edu.tr/media/1.jpg"));
        assertEquals("https://bingol.edu.tr/a.png", RichChatPayload.mediaUrl("", "https://bingol.edu.tr/a.png"));
        assertNull(RichChatPayload.mediaUrl(base, "https://evil.test/a.jpg"));
        assertNull(RichChatPayload.mediaUrl(base, "https://bingol.edu.tr.evil.test/a.jpg"));
        assertNull(RichChatPayload.mediaUrl(base, "http://www.bingol.edu.tr/a.jpg"));
        assertNull(RichChatPayload.mediaUrl(base, "//evil.test/a.jpg"));
        assertNull(RichChatPayload.mediaUrl(base, "https://www.bingol.edu.tr:8443/a.jpg"));
        assertNull(RichChatPayload.mediaUrl(base, "https://u:p@www.bingol.edu.tr/a.jpg"));
    }

    @Test
    void pushOnlyKeysNeverReachTheStoredInboxJson() {
        Map<String, String> data = new LinkedHashMap<>();
        data.put("eventId", "4");
        data.put("sourceName", "Yazilim Kulubu");
        data.put("senderAvatarUrl", "/files/a.jpg");
        data.put("imageUrl", "/files/b.jpg");
        data.put("badgeKey", "tomorrow");
        data.put("eventStartsAt", "2026-11-06T11:00:00Z");
        String json = NotificationService.toJson(data);
        assertThat(json).contains("eventId").contains("eventStartsAt")
                .doesNotContain("sourceName").doesNotContain("senderAvatarUrl").doesNotContain("imageUrl")
                .doesNotContain("badgeKey");
        assertEquals(6, data.size(), "kaynak harita degismez");
    }

    @Test
    void badgeKeyResolvesToLocalizedBadgeText() {
        var i18n = org.mockito.Mockito.mock(edu.bingol.backend.i18n.I18n.class);
        org.mockito.Mockito.when(i18n.msg("notif.badge.tomorrow", edu.bingol.backend.i18n.Lang.EN)).thenReturn("Tomorrow");
        Map<String, String> out = PushDisplay.withBadge(Map.of("eventId", "1", "badgeKey", "tomorrow"), i18n,
                edu.bingol.backend.i18n.Lang.EN);
        assertEquals("Tomorrow", out.get("badgeText"));
        assertFalse(out.containsKey("badgeKey"));
        // cevirisi olmayan anahtar rozet uretmez (anahtar metni sizmaz)
        org.mockito.Mockito.when(i18n.msg("notif.badge.nope", edu.bingol.backend.i18n.Lang.EN)).thenReturn("notif.badge.nope");
        assertFalse(PushDisplay.withBadge(Map.of("badgeKey", "nope"), i18n, edu.bingol.backend.i18n.Lang.EN).containsKey("badgeText"));
        assertEquals("2026-11-06T11:00:00Z", PushDisplay.iso(Instant.parse("2026-11-06T11:00:00.987Z")));
    }

    @Test
    void alertAndDataShareTheApnsBudget() {
        Map<String, String> big = new HashMap<>();
        big.put("eventId", "4");
        big.put("location", "x".repeat(3000));
        big.put("imageUrl", "https://bingol.edu.tr/" + "a".repeat(900));
        PushMessage m = PushMessages.of(NotificationType.EVENT, NotificationSubtype.EVENT_UPDATE, "T".repeat(500),
                "B".repeat(1500), PushPayload.build(NotificationType.EVENT, NotificationSubtype.EVENT_UPDATE, big, 1), null, 1);
        int total = PushPayload.sizeOf(m.data()) + m.title().getBytes(java.nio.charset.StandardCharsets.UTF_8).length
                + m.body().getBytes(java.nio.charset.StandardCharsets.UTF_8).length;
        assertTrue(total <= PushPayload.MAX_BYTES - 300, "alert + veri APNs 4 KB sinirini asmamali: " + total);
        assertEquals("4", m.data().get("eventId"));
        assertEquals("EVENT_UPDATE", m.data().get("style"));
    }

    @Test
    void broadcastEnrichmentHasNoRecipientButBroadcastMarker() {
        PushMessage news = message(NotificationType.NEWS, null, Map.of("newsId", "7", "imageUrl", "https://www.bingol.edu.tr/m/1.jpg"));
        PushMessage rich = RichPushPayload.enrichBroadcast(news, "https://bukampus.com.tr", "tr");
        assertTrue(RichPushPayload.isRich(rich));
        assertEquals("1", rich.data().get("broadcast"));
        assertFalse(rich.data().containsKey("recipientId"));
        assertEquals("https://www.bingol.edu.tr/m/1.jpg", rich.data().get("imageUrl"));
        assertEquals("BU_ANNOUNCEMENT", rich.category());
    }
}
