package edu.bingol.backend.admin.users.extras;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimitedException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.export.DataExporter;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.Test;

class AdminUserExportServiceTest {

    private static final String REASON = "KVKK basvurusu uzerine kullanici adina disa aktarma";

    private final UserRepository users = mock(UserRepository.class);
    private final RateLimiter limiter = mock(RateLimiter.class);
    private final Clock clock = Clock.fixed(Instant.parse("2026-10-28T10:00:00Z"), ZoneOffset.UTC);
    private final AdminUserExportService service = new AdminUserExportService(List.of(
            DataExporter.of("tickets", id -> List.of("t" + id)),
            DataExporter.of("profile", id -> Map.of("id", id)),
            DataExporter.of("broken", id -> {
                throw new IllegalStateException("boom");
            })), users, limiter, clock);

    private void user(long id, UserStatus status) {
        User u = new User();
        u.setId(id);
        u.setStatus(status);
        when(users.findById(id)).thenReturn(Optional.of(u));
    }

    @Test
    void exportsAllSectionsSortedWithBrokenSectionMarked() {
        user(7, UserStatus.ACTIVE);

        Map<String, Object> out = service.export(7L, REASON, "7");

        assertEquals(List.of("exportedAt", "subjectUserId", "broken", "profile", "tickets"),
                List.copyOf(out.keySet()));
        assertEquals(Map.of("error", "SECTION_UNAVAILABLE"), out.get("broken"));
        assertEquals(7L, out.get("subjectUserId"));
        // gunluk sinir: hedef kullanici basina 1 / 24 saat
        verify(limiter).check("admexp:7", 1, Duration.ofDays(1));
    }

    @Test
    void shortReasonIsRejectedBeforeLimitIsConsumed() {
        user(7, UserStatus.ACTIVE);
        ApiException e = assertThrows(ApiException.class, () -> service.export(7L, "sadece on dokuz kar", "7"));
        assertEquals("REASON_REQUIRED", e.code());
        verify(limiter, never()).check(anyString(), anyInt(), any());
    }

    @Test
    void secondConfirmationMustMatchTheUserId() {
        user(7, UserStatus.ACTIVE);
        for (String bad : new String[] {null, "", "8", "seven", "07x"}) {
            ApiException e = assertThrows(ApiException.class, () -> service.export(7L, REASON, bad));
            assertEquals("EXPORT_CONFIRM_MISMATCH", e.code());
        }
        verify(limiter, never()).check(anyString(), anyInt(), any());
    }

    @Test
    void dailyLimitPropagatesAs429() {
        user(7, UserStatus.ACTIVE);
        doThrow(new RateLimitedException(10800)).when(limiter).check(eq("admexp:7"), eq(1), any());
        assertThrows(RateLimitedException.class, () -> service.export(7L, REASON, "7"));
    }

    @Test
    void deletedOrMissingUserIsNotFound() {
        user(7, UserStatus.DELETED);
        assertEquals("USER_NOT_FOUND", assertThrows(ApiException.class, () -> service.export(7L, REASON, "7")).code());
        when(users.findById(8L)).thenReturn(Optional.empty());
        assertTrue(assertThrows(ApiException.class, () -> service.export(8L, REASON, "8")).status().is4xxClientError());
        verify(limiter, never()).check(anyString(), anyInt(), any());
    }
}
