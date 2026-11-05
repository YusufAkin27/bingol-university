package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.*;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest
class NotificationPresentationTest {
    @Autowired NotificationInboxService inbox;
    @Autowired NotificationRepository notifications;
    @Autowired UserRepository users;

    private Long user() {
        User user = new User();
        user.setEmail("presentation-" + UUID.randomUUID() + "@bingol.edu.tr");
        user.setPasswordHash("x");
        user.setDisplayName("Notification test");
        user.setEmailVerified(true);
        return users.saveAndFlush(user).getId();
    }

    private Notification row(Long uid, NotificationType type, String subtype, String data) {
        Notification n = new Notification();
        n.setUserId(uid);
        n.setType(type);
        n.setTitle("Title");
        n.setBody("Body");
        n.setSubtype(subtype);
        n.setData(data);
        return notifications.saveAndFlush(n);
    }

    @Test
    void categoriesAreFilteredBeforePaginationAndDoNotLeakOtherUsers() {
        Long uid = user();
        row(uid, NotificationType.EVENT, null, "{\"eventId\":\"1\"}");
        row(uid, NotificationType.EVENT, "EVENT_ADMISSION", "{\"eventId\":\"2\"}");
        row(uid, NotificationType.ANNOUNCEMENT, "EXAM_REMINDER", "{\"examId\":\"1\"}");
        row(uid, NotificationType.COMMUNITY, null, "{\"pollId\":\"1\"}");
        row(uid, NotificationType.FOLLOW_REQUEST, null, "{\"userId\":\"2\"}");
        row(uid, NotificationType.SYSTEM, null, "{}");
        row(uid, NotificationType.NEWS, null, null);
        row(uid, NotificationType.MESSAGE, null, "{}");
        row(user(), NotificationType.EVENT, null, "{}");
        var first = inbox.list(uid, null, 1, null, false, "EVENT");
        assertEquals(1, first.items().size());
        assertNotNull(first.nextCursor());
        var second = inbox.list(uid, first.nextCursor(), 1, null, false, "EVENT");
        assertEquals(1, second.items().size());
        assertNotEquals(first.items().get(0).id(), second.items().get(0).id());
        assertNull(second.nextCursor());
        assertEquals(7, first.unreadCount());
        for (String category : new String[]{"EVENT", "ACADEMIC", "POLL", "SOCIAL", "SYSTEM", "ANNOUNCEMENT"}) {
            var page = inbox.list(uid, null, 20, null, false, category);
            assertFalse(page.items().isEmpty());
            assertTrue(page.items().stream().allMatch(n -> category.equals(n.getCategory())));
        }
        inbox.markRead(uid, null, true);
        assertTrue(inbox.list(uid, null, 20, null, true, "EVENT").items().isEmpty());
        assertThrows(ApiException.class, () -> inbox.list(uid, null, 20, null, false, "UNKNOWN"));
    }

    @Test
    void categoryDetectionUsesTargetKeysRatherThanUnrelatedValues() {
        Long uid = user();
        row(uid, NotificationType.EVENT, null, "{\"label\":\"POLL_RESULT\",\"note\":\"EXAM\"}");
        row(uid, NotificationType.ANNOUNCEMENT, null, "{\"target\": \"POLL_CLOSING\",\"value\":\"1\"}");
        row(uid, NotificationType.ANNOUNCEMENT, null, "{\"targetType\":\"ACADEMIC_EXAM\",\"targetId\":\"2\"}");
        assertEquals(1, inbox.list(uid, null, 20, null, false, "EVENT").items().size());
        assertEquals(1, inbox.list(uid, null, 20, null, false, "POLL").items().size());
        assertEquals(1, inbox.list(uid, null, 20, null, false, "ACADEMIC").items().size());
    }

    @Test
    void pushCategoryCannotBeSpoofedAndMalformedLegacyDataIsSafe() {
        var data = PushPayload.build(NotificationType.EVENT, null, Map.of("category", "SYSTEM", "eventId", "1"), 1);
        assertEquals("EVENT", data.get("category"));
        assertEquals("POLL", PushPayload.build(NotificationType.ANNOUNCEMENT, null, Map.of("pollId", "1"), 1).get("category"));
        assertEquals("ACADEMIC", PushPayload.build(NotificationType.ANNOUNCEMENT, NotificationSubtype.EXAM_REMINDER, Map.of(), 1).get("category"));
        assertTrue(NotificationPresentation.data("bad json").isEmpty());
        assertTrue(NotificationPresentation.data("null").isEmpty());
    }
}
