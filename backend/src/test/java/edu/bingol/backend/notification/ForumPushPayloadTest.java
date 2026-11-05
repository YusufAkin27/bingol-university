package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.notification.fcm.PushMessage;
import java.util.LinkedHashMap;
import java.util.Map;
import org.junit.jupiter.api.Test;

/** Forum bildirimlerinin push yuku sozlesmesi: hedef, stil, kanal, TTL, thread, gorsel kurali (docs/changes/forum-e.md). */
class ForumPushPayloadTest {

    private static Map<String, String> topicData() {
        Map<String, String> d = new LinkedHashMap<>();
        d.put("target", "FORUM_TOPIC");
        d.put("value", "42");
        d.put("topicId", "42");
        d.put("forumKind", "FORUM_TOPIC_LIKE");
        d.put("senderName", "Anonim #3");
        d.put("sourceName", "Yemekhane");
        d.put("imageUrl", "https://bukampus.com.tr/s/f/42/img");
        return d;
    }

    @Test
    void forumTargetsBecomeTargetTypeAndTargetIdWithSocialStyle() {
        Map<String, String> p = PushPayload.build(NotificationType.FORUM, NotificationSubtype.FORUM_TOPIC_LIKE, topicData(), 1);
        assertEquals("FORUM", p.get("type"));
        assertEquals("FORUM_TOPIC_LIKE", p.get("subtype"));
        assertEquals("FORUM_TOPIC", p.get("targetType"));
        assertEquals("42", p.get("targetId"));
        assertEquals("42", p.get("topicId"));
        assertEquals("SOCIAL", p.get("style"));
        assertEquals("SOCIAL", p.get("category"));
    }

    @Test
    void commentTargetCarriesTopicIdToo() {
        Map<String, String> d = new LinkedHashMap<>();
        d.put("target", "FORUM_COMMENT");
        d.put("value", "500");
        d.put("topicId", "42");
        d.put("commentId", "500");
        Map<String, String> p = PushPayload.build(NotificationType.FORUM, NotificationSubtype.FORUM_COMMENT_REPLY, d, 1);
        assertEquals("FORUM_COMMENT", p.get("targetType"));
        assertEquals("500", p.get("targetId"));
        assertEquals("42", p.get("topicId"));
    }

    @Test
    void forumPushUsesSocialChannelOneDayTtlAndTopicThread() {
        Map<String, String> p = PushPayload.build(NotificationType.FORUM, NotificationSubtype.FORUM_TOPIC_LIKE, topicData(), 1);
        PushMessage m = PushMessages.of(NotificationType.FORUM, NotificationSubtype.FORUM_TOPIC_LIKE, "t", "b", p,
                "fotl:42:1", 3);
        assertEquals("social", m.channelId());
        assertEquals(86_400, m.ttlSeconds());
        assertEquals("forum-42", m.threadId());
        assertEquals("BU_SOCIAL", m.category());
        assertFalse(m.highPriority());
    }

    @Test
    void moderationIsSystemWithModerationStyleAndHighPriority() {
        Map<String, String> d = new LinkedHashMap<>();
        d.put("target", "FORUM_TOPIC");
        d.put("value", "42");
        d.put("topicId", "42");
        d.put("moderation", "1");
        d.put("forumKind", "FORUM_MODERATION");
        Map<String, String> p = PushPayload.build(NotificationType.SYSTEM, null, d, 1);
        assertEquals("MODERATION", p.get("style"));
        assertEquals("FORUM_TOPIC", p.get("targetType"));
        PushMessage m = PushMessages.of(NotificationType.SYSTEM, "t", "b", p, "fomod:t42:REMOVE", null);
        assertTrue(m.highPriority());
        assertEquals("BU_MODERATION", m.category());
    }

    @Test
    void richPayloadKeepsSenderSourceAndOwnHostImageButNeverAnIdentity() {
        Map<String, String> p = PushPayload.build(NotificationType.FORUM, NotificationSubtype.FORUM_TOPIC_LIKE, topicData(), 1);
        PushMessage m = PushMessages.of(NotificationType.FORUM, NotificationSubtype.FORUM_TOPIC_LIKE, "t", "b", p,
                "fotl:42:1", null);
        PushMessage rich = RichPushPayload.enrich(m, "https://bukampus.com.tr", "tr", 7L);
        assertEquals("SOCIAL", rich.data().get("style"));
        assertEquals("Anonim #3", rich.data().get("senderName"));
        assertEquals("Yemekhane", rich.data().get("sourceName"));
        assertEquals("https://bukampus.com.tr/s/f/42/img", rich.data().get("imageUrl"));
        assertFalse(rich.data().containsKey("senderAvatarUrl"));
        assertFalse(rich.data().containsKey("userId"));
        assertFalse(rich.data().containsKey("actorId"));
    }

    @Test
    void forumTypeMapsToCommunitiesFlagAndSubtypesBelongToForum() {
        assertEquals("communities", NotificationType.FORUM.prefColumn());
        for (NotificationSubtype s : NotificationSubtype.values()) {
            if (s.name().startsWith("FORUM_")) {
                assertEquals(NotificationType.FORUM, s.parent());
                assertTrue(s.name().length() <= 32, "bildirim.subtype VARCHAR(32): " + s);
            }
        }
        assertTrue(NotificationType.FORUM.name().length() <= 24, "bildirim.type VARCHAR(24)");
    }

    @Test
    void presentationCategoryIsSocial() {
        assertEquals("SOCIAL", NotificationPresentation.category(NotificationType.FORUM, "FORUM_TOPIC_COMMENT",
                Map.of("targetType", "FORUM_COMMENT")));
    }
}
