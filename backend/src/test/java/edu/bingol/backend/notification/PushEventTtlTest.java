package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.time.Instant;
import java.util.Map;
import org.junit.jupiter.api.Test;

class PushEventTtlTest {

    private final Instant now = Instant.parse("2026-11-07T10:00:00Z");

    @Test
    void ttlIsCappedByEventEnd() {
        Map<String, String> p = Map.of("eventEndsAt", "2026-11-07T10:30:00Z");
        assertEquals(1800, PushMessages.ttlSeconds(NotificationType.EVENT, null, p, now));
        assertEquals(1800, PushMessages.ttlSeconds(NotificationType.EVENT, NotificationSubtype.EVENT_REMINDER, p, now));
    }

    @Test
    void farEndKeepsDefaultAndPastEndGetsFloor() {
        assertEquals(86_400, PushMessages.ttlSeconds(NotificationType.EVENT, null,
                Map.of("eventEndsAt", "2026-12-07T10:30:00Z"), now));
        assertEquals(60, PushMessages.ttlSeconds(NotificationType.EVENT, null,
                Map.of("eventEndsAt", "2026-11-07T09:00:00Z"), now));
    }

    @Test
    void otherTypesAndBadValuesIgnored() {
        assertEquals(86_400 * 7, PushMessages.ttlSeconds(NotificationType.MESSAGE, null,
                Map.of("eventEndsAt", "2026-11-07T10:01:00Z"), now));
        assertEquals(86_400, PushMessages.ttlSeconds(NotificationType.EVENT, null, Map.of("eventEndsAt", "x"), now));
    }
}
