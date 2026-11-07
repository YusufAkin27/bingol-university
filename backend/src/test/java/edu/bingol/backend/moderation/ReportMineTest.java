package edu.bingol.backend.moderation;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.moderation.ReportController.MyReportView;
import java.lang.reflect.RecordComponent;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

/** B6: "Sikayetlerim" yalniz raportorun kendi raporlarinin GENEL durumunu doner; hedef/karar/not/raportor sizmaz. */
class ReportMineTest {

    private final ReportService service = mock(ReportService.class);
    private final RateLimiter limiter = mock(RateLimiter.class);
    private final ReportController controller = new ReportController(service, limiter);

    @AfterEach
    void clear() {
        SecurityContextHolder.clearContext();
    }

    private static Report report(long id, Report.Status status) {
        Report r = new Report();
        r.setId(id);
        r.setReporterId(7L);
        r.setTargetType(ReportTargetType.FORUM_TOPIC);
        r.setTargetId(4242L);
        r.setReason(ReportReason.SPAM);
        r.setNote("gizli not");
        r.setStatus(status);
        r.setResolution(status == Report.Status.RESOLVED ? Report.Resolution.SUSPEND_USER : null);
        r.setResolvedBy(99L);
        r.setReasonCode("MODERATOR_NOTE");
        r.setCreatedAt(Instant.parse("2026-11-01T10:00:00Z"));
        r.setResolvedAt(status == Report.Status.RESOLVED ? Instant.parse("2026-11-02T10:00:00Z") : null);
        return r;
    }

    private static void login(Long id) {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(id, null, List.of()));
    }

    @Test
    void viewHasNoTargetIdResolutionNoteOrModeratorFields() {
        List<String> names = Arrays.stream(MyReportView.class.getRecordComponents()).map(RecordComponent::getName).toList();
        assertEquals(List.of("id", "targetType", "reason", "status", "createdAt", "resolvedAt"), names);
        for (String banned : List.of("targetId", "resolution", "note", "reporterId", "resolvedBy", "priority", "reasonCode")) {
            assertFalse(names.contains(banned), banned);
        }
    }

    @Test
    void returnsOwnReportsWithGeneralStatusAndCursor() {
        login(7L);
        List<Report> rows = new ArrayList<>(List.of(report(30, Report.Status.RESOLVED), report(20, Report.Status.OPEN),
                report(10, Report.Status.OPEN)));
        when(service.mine(eq(7L), eq(null), eq(3))).thenReturn(rows);

        CursorPage<MyReportView> page = controller.mine(null, 2);

        assertEquals(2, page.items().size());
        assertEquals(20L, page.nextCursor());
        assertEquals("RESOLVED", page.items().get(0).status());
        assertEquals("FORUM_TOPIC", page.items().get(0).targetType());
        assertTrue(page.items().get(0).resolvedAt() != null);
        assertNull(page.items().get(1).resolvedAt());
        verify(limiter).check("report:mine:7", 60, Duration.ofMinutes(1));
    }

    @Test
    void queriesOnlyTheCallersId() {
        login(8L);
        when(service.mine(eq(8L), eq(5L), eq(21))).thenReturn(List.of());
        CursorPage<MyReportView> page = controller.mine(5L, 20);
        assertTrue(page.items().isEmpty());
        assertNull(page.nextCursor());
        verify(service).mine(8L, 5L, 21);
    }
}
