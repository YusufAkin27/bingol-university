package edu.bingol.backend.moderation;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.accessban.UserDeviceLog;
import edu.bingol.backend.accessban.UserDeviceLogRepository;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.moderation.dto.ModerationDtos.CreateReportRequest;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;

/**
 * T-057: gorunmeyen hedefe rapor 404 (varlik oracle'i yok), ayni cihaz/IP kumesindeki raporlayicilar tek sayilir
 * (cete ile otomatik gizleme), kulup icin yuksek esik + yonetici onceligi.
 */
class ReportVisibilityClusterTest {

    private static final long OWNER = 10L;
    private static final long TARGET = 77L;

    private final ReportRepository reports = mock(ReportRepository.class);
    private final ReportTargetHandler handler = mock(ReportTargetHandler.class);
    private final ModerationNotifier notifier = mock(ModerationNotifier.class);
    private final ModerationTargetStateRepository states = mock(ModerationTargetStateRepository.class);
    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    private final UserDeviceLogRepository logs = mock(UserDeviceLogRepository.class);
    private final ModerationProperties props = new ModerationProperties(3, 24, 3, 180, 5, 30, 7, 30);
    private ReportService service;

    @BeforeEach
    void setUp() {
        when(handler.type()).thenReturn(ReportTargetType.EVENT);
        when(handler.exists(TARGET)).thenReturn(true);
        when(handler.exists(anyLong(), eq(TARGET))).thenReturn(true);
        when(handler.ownerId(TARGET)).thenReturn(Optional.of(OWNER));
        when(handler.reversible()).thenReturn(true);
        when(reports.save(any(Report.class))).thenAnswer(i -> {
            Report r = i.getArgument(0);
            r.setId(500L);
            return r;
        });
        when(states.findByTargetTypeAndTargetId(any(), eq(TARGET))).thenReturn(Optional.empty());
        service = new ReportService(reports, List.of(handler), mock(UserModerationService.class), notifier, states,
                mock(StrikeService.class), props, redis);
        service.setClusters(new ReporterClusters(logs));
    }

    @AfterEach
    void clearContext() {
        SecurityContextHolder.clearContext();
    }

    private CreateReportRequest req(ReportTargetType type) {
        return new CreateReportRequest(type, TARGET, ReportReason.INAPPROPRIATE, null);
    }

    private static UserDeviceLog row(long user, String device, String ip) {
        UserDeviceLog l = new UserDeviceLog();
        l.setUserId(user);
        l.setDeviceHash(device);
        l.setIp(ip);
        return l;
    }

    @Test
    void invisibleTargetIsIndistinguishableFromMissing() {
        // exists(id) true (kayit var) ama raporlayan goremiyor -> olmayanla ayni 404
        when(handler.exists(1L, TARGET)).thenReturn(false);

        ApiException e = assertThrows(ApiException.class, () -> service.create(1L, req(ReportTargetType.EVENT)));

        assertEquals("TARGET_NOT_FOUND", e.code());
        assertEquals(404, e.status().value());
        verify(reports, never()).save(any());
    }

    @Test
    void adminReporterUsesUnrestrictedExistence() {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(
                1L, null, List.of(new SimpleGrantedAuthority("ROLE_ADMIN"))));
        when(handler.exists(1L, TARGET)).thenReturn(false);

        service.create(1L, req(ReportTargetType.EVENT));

        verify(reports).save(any(Report.class));
    }

    @Test
    void threeAccountsOnOneDeviceDoNotTriggerAutoHide() {
        when(reports.eligibleOpenReporterIds(eq(ReportTargetType.EVENT), eq(TARGET), any(Instant.class)))
                .thenReturn(List.of(1L, 2L, 3L));
        when(logs.findByUserIdIn(any())).thenReturn(List.of(row(1, "devA", "10.0.0.1"), row(2, "devA", "10.0.0.2"),
                row(3, "devA", "10.0.0.3")));
        when(logs.userCountsByIp(any())).thenReturn(List.of());
        when(reports.countOpenReporters(ReportTargetType.EVENT, TARGET)).thenReturn(3L);

        service.create(1L, req(ReportTargetType.EVENT));

        verify(handler, never()).hide(anyLong());
        verify(reports).updateOpenPriority(ReportTargetType.EVENT, TARGET, 30);
    }

    @Test
    void threeIndependentAccountsStillTriggerAutoHide() {
        when(reports.eligibleOpenReporterIds(eq(ReportTargetType.EVENT), eq(TARGET), any(Instant.class)))
                .thenReturn(List.of(1L, 2L, 3L));
        when(logs.findByUserIdIn(any())).thenReturn(List.of(row(1, "devA", "10.0.0.1"), row(2, "devB", "10.0.0.2"),
                row(3, "devC", "10.0.0.3")));
        when(logs.userCountsByIp(any())).thenReturn(List.of());
        when(reports.countOpenReporters(ReportTargetType.EVENT, TARGET)).thenReturn(3L);

        service.create(1L, req(ReportTargetType.EVENT));

        verify(handler).hide(TARGET);
        verify(states).markHidden("EVENT", TARGET, "AUTO");
    }

    @Test
    void sharedLowTrafficIpClustersAccountsButCampusNatDoesNot() {
        ReporterClusters c = new ReporterClusters(logs);
        // 3 hesap farkli cihaz ama ayni (az kullanicili) IP: tek kume
        when(logs.findByUserIdIn(any())).thenReturn(List.of(row(1, "devA", "1.1.1.1"), row(2, "devB", "1.1.1.1"),
                row(3, "devC", "1.1.1.1")));
        when(logs.userCountsByIp(any())).thenReturn(java.util.Collections.singletonList(new Object[] {"1.1.1.1", 3L}));
        assertEquals(1, c.independentCount(List.of(1L, 2L, 3L)));

        // Ayni IP'yi 200 farkli kullanici paylasiyorsa (kampus NAT'i) sinyal sayilmaz
        when(logs.userCountsByIp(any())).thenReturn(java.util.Collections.singletonList(new Object[] {"1.1.1.1", 200L}));
        assertEquals(3, c.independentCount(List.of(1L, 2L, 3L)));
    }

    @Test
    void missingDeviceHeaderIsNotACluster() {
        ReporterClusters c = new ReporterClusters(logs);
        when(logs.findByUserIdIn(any())).thenReturn(List.of(row(1, UserDeviceLog.NO_DEVICE, "9.9.9.1"),
                row(2, UserDeviceLog.NO_DEVICE, "9.9.9.2")));
        when(logs.userCountsByIp(any())).thenReturn(List.of());
        assertEquals(2, c.independentCount(List.of(1L, 2L)));
    }

    @Test
    void clusteringCanBeDisabled() {
        ReporterClusters c = new ReporterClusters(logs);
        c.configure(false, 5);
        assertEquals(3, c.independentCount(List.of(1L, 2L, 3L)));
        verify(logs, never()).findByUserIdIn(any());
    }

    @Test
    void clubThresholdIsFiveAndEscalatesPriorityInsteadOfHiding() {
        ReportTargetHandler club = mock(ReportTargetHandler.class);
        when(club.type()).thenReturn(ReportTargetType.COMMUNITY);
        when(club.exists(anyLong(), eq(TARGET))).thenReturn(true);
        when(club.exists(TARGET)).thenReturn(true);
        when(club.ownerId(TARGET)).thenReturn(Optional.of(OWNER));
        when(club.reversible()).thenReturn(false);
        service = new ReportService(reports, List.of(club), mock(UserModerationService.class), notifier, states,
                mock(StrikeService.class), props, redis);
        service.setClusters(new ReporterClusters(logs));
        when(logs.findByUserIdIn(any())).thenReturn(List.of());
        assertEquals(5, service.thresholdFor(ReportTargetType.COMMUNITY));
        assertEquals(3, service.thresholdFor(ReportTargetType.EVENT));

        // 4 bagimsiz rapor: esik 5'in altinda -> yukseltme yok
        when(reports.eligibleOpenReporterIds(eq(ReportTargetType.COMMUNITY), eq(TARGET), any(Instant.class)))
                .thenReturn(List.of(1L, 2L, 3L, 4L));
        when(reports.countOpenReporters(ReportTargetType.COMMUNITY, TARGET)).thenReturn(4L);
        service.create(11L, req(ReportTargetType.COMMUNITY));
        verify(reports).updateOpenPriority(ReportTargetType.COMMUNITY, TARGET, 40);

        // 5 bagimsiz rapor: gizlenmez (geri alinamaz tur) ama yonetici onceligi +200
        when(reports.eligibleOpenReporterIds(eq(ReportTargetType.COMMUNITY), eq(TARGET), any(Instant.class)))
                .thenReturn(List.of(1L, 2L, 3L, 4L, 5L));
        when(reports.countOpenReporters(ReportTargetType.COMMUNITY, TARGET)).thenReturn(5L);
        service.create(12L, req(ReportTargetType.COMMUNITY));
        verify(reports).updateOpenPriority(ReportTargetType.COMMUNITY, TARGET, 50 + ReportService.ESCALATION_PRIORITY);
        verify(club, never()).hide(anyLong());
    }
}
