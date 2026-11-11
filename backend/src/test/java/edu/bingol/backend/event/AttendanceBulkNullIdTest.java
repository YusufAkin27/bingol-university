package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.config.JwtProperties;
import java.time.Instant;
import java.util.Arrays;
import org.junit.jupiter.api.Test;

/** Toplu yoklamada userIds icinde null: 500 (NPE) degil 400 VALIDATION_ERROR. */
class AttendanceBulkNullIdTest {

    private final AttendanceService svc = new AttendanceService(mock(EventService.class), mock(EventRsvpRepository.class),
            mock(EventAttendanceRepository.class),
            new CheckinCodeService(new JwtProperties("test-secret-test-secret-test-secret-1234", 15, 30)),
            mock(CommunityService.class));

    @Test
    void nullUserIdIsRejectedAs400() {
        ApiException ex = assertThrows(ApiException.class,
                () -> svc.bulkStatus(new Actor(1L, false), 5L, "PRESENT", Arrays.asList(7L, null), false, Instant.now()));
        assertEquals(400, ex.status().value());
        assertEquals("VALIDATION_ERROR", ex.code());
    }
}
