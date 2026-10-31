package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.notification.fcm.PushMessage;
import java.util.Map;
import org.junit.jupiter.api.Test;

/** Sinav hatirlatmasi push'unun yuku: kanal, oncelik, TTL, yonlendirme alanlari (mobil Sinavlar ekranina gider). */
class ExamReminderPushMessageTest {

    @Test
    void examReminderUsesAcademicChannelHighPriorityShortTtlAndExamTarget() {
        Map<String, String> payload = PushPayload.build(NotificationType.ANNOUNCEMENT, NotificationSubtype.EXAM_REMINDER,
                Map.of("target", "EXAM", "value", "42", "examId", "42"), 1);
        assertEquals("EXAM", payload.get("targetType"));
        assertEquals("42", payload.get("targetId"));
        assertEquals("EXAM_REMINDER", payload.get("subtype"));

        PushMessage m = PushMessages.of(NotificationType.ANNOUNCEMENT, NotificationSubtype.EXAM_REMINDER, "Sinav hatirlatmasi",
                "gövde", payload, "exam:42:1793000000", 3);
        assertEquals("academic", m.channelId());
        assertTrue(m.highPriority());
        assertEquals(3600, m.ttlSeconds());
        assertEquals("exam:42:1793000000", m.data().get("tag"));
        assertEquals("academic", m.data().get("threadId"));
        assertEquals("academic", m.data().get("channelId"));
    }

    @Test
    void otherAnnouncementsKeepTheirChannel() {
        Map<String, String> payload = PushPayload.build(NotificationType.ANNOUNCEMENT, NotificationSubtype.ACADEMIC_ANNOUNCEMENT,
                Map.of("announcementId", "5"), 1);
        PushMessage m = PushMessages.of(NotificationType.ANNOUNCEMENT, NotificationSubtype.ACADEMIC_ANNOUNCEMENT, "t", "b",
                payload, null, null);
        assertEquals("announcement", m.channelId());
        assertEquals(3 * 86_400, m.ttlSeconds());
    }
}
