package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

import edu.bingol.backend.notification.fcm.PushMessage;
import java.util.Map;
import org.junit.jupiter.api.Test;

/** A13-01: Android `tag` yalniz collapseKey varken; tur/thread adi etiket olmaz. */
class PushMessagesTagTest {

    @Test
    void announcementWithoutCollapseKeyHasNoTag() {
        Map<String, String> p = PushPayload.build(NotificationType.ANNOUNCEMENT, null, Map.of("announcementId", "5"), 1);
        PushMessage m = PushMessages.of(NotificationType.ANNOUNCEMENT, "t", "b", p, null, null);
        assertFalse(m.data().containsKey("tag"));
        assertEquals("announcement", m.data().get("threadId")); // iOS gruplamasi kalir
    }

    @Test
    void systemConversationNotificationDoesNotUseConvTag() {
        Map<String, String> p = PushPayload.build(NotificationType.SYSTEM, null, Map.of("conversationId", "5"), 1);
        PushMessage m = PushMessages.of(NotificationType.SYSTEM, "t", "b", p, null, null);
        assertFalse(m.data().containsKey("tag"));
        assertEquals("conv:5", m.data().get("threadId"));
    }

    @Test
    void collapseKeyBecomesTag() {
        Map<String, String> p = PushPayload.build(NotificationType.MESSAGE, null, Map.of("conversationId", "5"), 1);
        PushMessage m = PushMessages.of(NotificationType.MESSAGE, "t", "b", p, "conv:5", 2);
        assertEquals("conv:5", m.data().get("tag"));
    }
}
