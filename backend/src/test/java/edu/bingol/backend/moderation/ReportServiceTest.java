package edu.bingol.backend.moderation;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.moderation.dto.ModerationDtos.CreateReportRequest;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

class ReportServiceTest {

    private static final long OWNER = 10L;
    private static final long TARGET = 77L;
    private static final ReportTargetType TYPE = ReportTargetType.USER_AVATAR;

    private final ReportRepository reports = mock(ReportRepository.class);
    private final ReportTargetHandler handler = mock(ReportTargetHandler.class);
    private final UserModerationService userModeration = mock(UserModerationService.class);
    private final ModerationNotifier notifier = mock(ModerationNotifier.class);
    private final ModerationTargetStateRepository states = mock(ModerationTargetStateRepository.class);
    private final StrikeService strikes = mock(StrikeService.class);
    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    @SuppressWarnings("unchecked")
    private final ValueOperations<String, String> ops = mock(ValueOperations.class);
    private final ModerationProperties props = new ModerationProperties(3, 24, 3, 180, 5, 30, 7, 30);
    private ReportService service;

    @BeforeEach
    void setUp() {
        when(handler.type()).thenReturn(TYPE);
        when(handler.exists(TARGET)).thenReturn(true);
        when(handler.ownerId(TARGET)).thenReturn(Optional.of(OWNER));
        when(handler.reversible()).thenReturn(true);
        when(redis.opsForValue()).thenReturn(ops);
        when(reports.save(any(Report.class))).thenAnswer(i -> {
            Report r = i.getArgument(0);
            r.setId(500L);
            return r;
        });
        when(states.findByTargetTypeAndTargetId(TYPE, TARGET)).thenReturn(Optional.empty());
        service = new ReportService(reports, List.of(handler), userModeration, notifier, states, strikes, props, redis);
    }

    private CreateReportRequest req() {
        return new CreateReportRequest(TYPE, TARGET, ReportReason.INAPPROPRIATE, null);
    }

    @Test
    void autoHidesWhenEligibleReportersReachThreshold() {
        when(reports.countEligibleOpenReporters(eq(TYPE), eq(TARGET), any(Instant.class))).thenReturn(3L);
        when(reports.countOpenReporters(TYPE, TARGET)).thenReturn(3L);

        Report r = service.create(1L, req());

        verify(handler).hide(TARGET);
        verify(states).markHidden("USER_AVATAR", TARGET, "AUTO");
        verify(notifier).autoHidden(OWNER, TYPE, TARGET);
        // 3 raporlayici * 10 + gizli 100
        verify(reports).updateOpenPriority(TYPE, TARGET, 130);
        assertEquals(130, r.getPriority());
    }

    @Test
    void doesNotAutoHideBelowThresholdOrWithNewAccounts() {
        // Esik 3; yeterince eski hesaptan yalnizca 2 rapor (digerleri yeni hesap) sayilir
        when(reports.countEligibleOpenReporters(eq(TYPE), eq(TARGET), any(Instant.class))).thenReturn(2L);
        when(reports.countOpenReporters(TYPE, TARGET)).thenReturn(5L);

        service.create(1L, req());

        verify(handler, never()).hide(anyLong());
        verify(states, never()).markHidden(anyString(), anyLong(), anyString());
        verify(reports).updateOpenPriority(TYPE, TARGET, 50);
    }

    @Test
    void doesNotAutoHideIrreversibleTypes() {
        when(handler.reversible()).thenReturn(false);
        when(reports.countEligibleOpenReporters(eq(TYPE), eq(TARGET), any(Instant.class))).thenReturn(10L);
        when(reports.countOpenReporters(TYPE, TARGET)).thenReturn(10L);

        service.create(1L, req());

        verify(handler, never()).hide(anyLong());
    }

    @Test
    void thresholdZeroDisablesAutoHide() {
        ModerationProperties off = new ModerationProperties(0, 24, 3, 180, 5, 30, 7, 30);
        service = new ReportService(reports, List.of(handler), userModeration, notifier, states, strikes, off, redis);
        when(reports.countOpenReporters(TYPE, TARGET)).thenReturn(9L);

        service.create(1L, req());

        verify(handler, never()).hide(anyLong());
        verify(reports, never()).countEligibleOpenReporters(any(), anyLong(), any());
    }

    @Test
    void restrictedReporterIsRejected() {
        when(redis.hasKey(ReportService.RESTRICT_KEY_PREFIX + "1")).thenReturn(true);

        ApiException e = assertThrows(ApiException.class, () -> service.create(1L, req()));

        assertEquals("REPORTING_RESTRICTED", e.code());
        verify(reports, never()).save(any());
    }

    @Test
    void repeatReportOnSameTargetIsRejected() {
        when(reports.existsByReporterIdAndTargetTypeAndTargetIdAndCreatedAtAfter(eq(1L), eq(TYPE), eq(TARGET),
                any(Instant.class))).thenReturn(true);

        ApiException e = assertThrows(ApiException.class, () -> service.create(1L, req()));

        assertEquals("ALREADY_REPORTED", e.code());
    }

    @Test
    void cannotReportOwnContent() {
        ApiException e = assertThrows(ApiException.class, () -> service.create(OWNER, req()));
        assertEquals("CANNOT_REPORT_SELF", e.code());
    }

    private Report openReport(long id, long reporter) {
        Report r = new Report();
        r.setId(id);
        r.setReporterId(reporter);
        r.setTargetType(TYPE);
        r.setTargetId(TARGET);
        r.setReason(ReportReason.SPAM);
        return r;
    }

    @Test
    void dismissRestoresAutoHiddenContentWithoutStrike() {
        Report r = openReport(1L, 2L);
        when(reports.findById(1L)).thenReturn(Optional.of(r));
        when(reports.findByTargetTypeAndTargetIdAndStatus(TYPE, TARGET, Report.Status.OPEN)).thenReturn(List.of(r));
        ModerationTargetState st = new ModerationTargetState();
        st.setHiddenBy(ModerationTargetState.HiddenBy.AUTO);
        when(states.findByTargetTypeAndTargetId(TYPE, TARGET)).thenReturn(Optional.of(st));

        service.resolve(1L, 99L, Report.Resolution.DISMISS, null, null);

        verify(handler).unhide(TARGET);
        verify(states).clear(TYPE, TARGET);
        verify(notifier).restored(OWNER, TYPE, TARGET);
        verify(notifier).reporterOutcome(2L, false);
        verify(strikes, never()).record(anyLong(), any(), any());
        assertEquals(Report.Status.RESOLVED, r.getStatus());
    }

    @Test
    void hideRecordsStrikeMarksAdminHiddenAndNotifiesBothSides() {
        Report r = openReport(1L, 2L);
        Report r2 = openReport(2L, 3L);
        when(reports.findById(1L)).thenReturn(Optional.of(r));
        when(reports.findByTargetTypeAndTargetIdAndStatus(TYPE, TARGET, Report.Status.OPEN)).thenReturn(List.of(r, r2));
        when(notifier.reasonText(OWNER, "SPAM")).thenReturn("Spam");

        service.resolve(1L, 99L, Report.Resolution.HIDE, null, "spam");

        verify(handler).hide(TARGET);
        verify(states).markHidden("USER_AVATAR", TARGET, "ADMIN");
        verify(notifier).removed(OWNER, TYPE, TARGET, "Spam");
        verify(strikes).record(OWNER, r, Report.Resolution.HIDE);
        verify(notifier).reporterOutcome(2L, true);
        verify(notifier).reporterOutcome(3L, true);
        assertEquals("SPAM", r2.getReasonCode());
    }

    @Test
    void invalidReasonCodeRejected() {
        ApiException e = assertThrows(ApiException.class,
                () -> service.resolve(1L, 99L, Report.Resolution.HIDE, null, "NOPE"));
        assertEquals("REASON_CODE_INVALID", e.code());
    }

    @Test
    void manyDismissedReportsRestrictReporter() {
        when(reports.countByReporterIdAndResolutionAndResolvedAtAfter(eq(2L), eq(Report.Resolution.DISMISS),
                any(Instant.class))).thenReturn(5L);
        when(redis.hasKey(ReportService.RESTRICT_KEY_PREFIX + "2")).thenReturn(false);

        service.restrictIfAbusive(2L);

        verify(ops).set(eq(ReportService.RESTRICT_KEY_PREFIX + "2"), eq("1"), eq(Duration.ofDays(7)));
        verify(notifier).reporterRestricted(2L, 7);
    }

    @Test
    void fewDismissedReportsDoNotRestrict() {
        when(reports.countByReporterIdAndResolutionAndResolvedAtAfter(eq(2L), any(), any(Instant.class))).thenReturn(4L);

        service.restrictIfAbusive(2L);

        verify(notifier, never()).reporterRestricted(anyLong(), anyInt());
    }
}
