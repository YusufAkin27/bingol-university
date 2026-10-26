package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.HashMap;
import java.util.Map;
import org.junit.jupiter.api.Test;

class PushPayloadTest {

    @Test
    void alwaysHasTypeAndDerivesTargetValue() {
        Map<String, String> p = PushPayload.build(NotificationType.COMMUNITY, NotificationSubtype.COMMUNITY_JOIN,
                Map.of("communityId", "12"), 1);
        assertEquals("COMMUNITY", p.get("type"));
        assertEquals("COMMUNITY_JOIN", p.get("subtype"));
        assertEquals("COMMUNITY", p.get("target"));
        assertEquals("12", p.get("value"));
        assertNull(p.get("count"));
    }

    @Test
    void postWinsOverCommunityAndExplicitTargetIsKept() {
        Map<String, String> p = PushPayload.build(NotificationType.COMMUNITY, null,
                Map.of("communityId", "1", "postId", "9"), 1);
        assertEquals("POST", p.get("target"));
        assertEquals("9", p.get("value"));

        Map<String, String> c = PushPayload.build(NotificationType.SYSTEM, null,
                Map.of("target", "URL", "value", "https://a.b", "campaignId", "3"), 1);
        assertEquals("URL", c.get("target"));
        assertEquals("https://a.b", c.get("value"));
    }

    @Test
    void nullDataAndReservedKeys() {
        Map<String, String> p = PushPayload.build(NotificationType.NEWS, null, null, 1);
        assertEquals("NEWS", p.get("type"));
        assertFalse(p.containsKey("target"));

        Map<String, String> r = PushPayload.build(NotificationType.NEWS, null,
                Map.of("google.x", "1", "gcm_y", "2", "from", "3", "newsId", "4"), 1);
        assertFalse(r.containsKey("google.x"));
        assertFalse(r.containsKey("gcm_y"));
        assertFalse(r.containsKey("from"));
        assertEquals("4", r.get("newsId"));
    }

    @Test
    void countOnlyWhenGrouped() {
        assertEquals("5", PushPayload.build(NotificationType.MESSAGE, null, Map.of(), 5).get("count"));
    }

    @Test
    void enforcesFourKbLimitKeepingContractKeys() {
        Map<String, String> big = new HashMap<>();
        big.put("conversationId", "42");
        big.put("junk1", "x".repeat(3000));
        big.put("junk2", "y".repeat(3000));
        Map<String, String> p = PushPayload.build(NotificationType.MESSAGE, NotificationSubtype.MESSAGE_GROUP, big, 3);

        assertTrue(PushPayload.sizeOf(p) <= PushPayload.MAX_BYTES, "boyut " + PushPayload.sizeOf(p));
        assertEquals("MESSAGE", p.get("type"));
        assertEquals("CONVERSATION", p.get("target"));
        assertEquals("42", p.get("value"));
        assertEquals("3", p.get("count"));
    }

    @Test
    void oversizedValueIsTruncatedToFit() {
        Map<String, String> p = PushPayload.build(NotificationType.SYSTEM, null,
                Map.of("target", "URL", "value", "https://x.y/" + "a".repeat(6000)), 1);
        assertTrue(PushPayload.sizeOf(p) <= PushPayload.MAX_BYTES);
        assertEquals("URL", p.get("target"));
    }
}
