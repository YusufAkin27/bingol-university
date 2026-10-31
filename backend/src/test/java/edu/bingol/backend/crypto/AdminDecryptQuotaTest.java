package edu.bingol.backend.crypto;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import edu.bingol.backend.admin.chat.AdminChatFeedService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimitedException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.crypto.MessageAccessAuditRepository.Entry;
import java.time.Duration;
import java.util.List;
import org.junit.jupiter.api.Test;

/** T-015: yonetici sohbet cozme kotasi (saatlik istek, tek istekte mesaj) ve genel akis suzgec zorunlulugu. */
class AdminDecryptQuotaTest {

    private final MessageAccessAuditRepository audit = mock(MessageAccessAuditRepository.class);
    private final RateLimiter limiter = mock(RateLimiter.class);

    private AdminDecryptService svc(int perHour, int maxMessages) {
        var props = new CryptoProperties("", "", "", false, true, 300, 1024, perHour, maxMessages);
        var s = new AdminDecryptService(props, mock(MessageCipher.class), audit);
        s.setLimiter(limiter);
        return s;
    }

    private static Entry entry(long admin, int count) {
        return new Entry(admin, 5L, 10L, count, 1L, 2L, "yeterince uzun bir gerekce", "ip", "VIEW_MESSAGES");
    }

    @Test
    void everyRecordCountsAgainstTheHourlyAdminQuota() {
        svc(30, 200).record(List.of(entry(7, 3)), "ip");

        verify(limiter).check("admindecrypt:7", 30, Duration.ofHours(1));
        verify(audit).insertAll(List.of(entry(7, 3)));
    }

    @Test
    void quotaExceededIs429AndNothingIsAuditedOrReturned() {
        doThrow(new RateLimitedException(120)).when(limiter).check(eq("admindecrypt:7"), anyInt(), org.mockito.ArgumentMatchers.any());

        RateLimitedException e = assertThrows(RateLimitedException.class,
                () -> svc(2, 200).record(List.of(entry(7, 1)), "ip"));

        assertEquals(429, e.status().value());
        assertEquals(120, e.retryAfterSeconds());
        verify(audit, never()).insertAll(org.mockito.ArgumentMatchers.anyList());
    }

    @Test
    void quotasAreIndependentPerAdmin() {
        var s = svc(30, 200);
        s.record(List.of(entry(7, 1)), "ip");
        s.record(List.of(entry(8, 1)), "ip");

        verify(limiter).check("admindecrypt:7", 30, Duration.ofHours(1));
        verify(limiter).check("admindecrypt:8", 30, Duration.ofHours(1));
    }

    @Test
    void tooManyMessagesInOneCallIs400() {
        ApiException e = assertThrows(ApiException.class,
                () -> svc(30, 10).record(List.of(entry(7, 6), entry(7, 6)), "ip"));

        assertEquals("DECRYPT_BATCH_TOO_LARGE", e.code());
        assertEquals(400, e.status().value());
        verify(audit, never()).insertAll(org.mockito.ArgumentMatchers.anyList());
        verify(limiter, never()).check(org.mockito.ArgumentMatchers.anyString(), anyInt(), org.mockito.ArgumentMatchers.any());
    }

    @Test
    void emptyRecordIsFree() {
        svc(30, 200).record(List.of(), "ip");
        verify(limiter, never()).check(org.mockito.ArgumentMatchers.anyString(), anyInt(), org.mockito.ArgumentMatchers.any());
    }

    @Test
    void reasonMinimumIsTwentyCharacters() {
        assertEquals(20, AdminDecryptService.MIN_REASON);
        assertTrue(AdminDecryptService.SYSTEM_REASON.length() >= 10);
        var req = new org.springframework.mock.web.MockHttpServletRequest();
        org.springframework.web.context.request.RequestContextHolder.setRequestAttributes(
                new org.springframework.web.context.request.ServletRequestAttributes(req));
        try {
            edu.bingol.backend.admin.AuditContext.of(req).reason("on bes karakterli g"); // 19 karakter
            ApiException e = assertThrows(ApiException.class, () -> svc(30, 200).requireReason());
            assertEquals("REASON_REQUIRED", e.code());
            edu.bingol.backend.admin.AuditContext.of(req).reason("yirmi karakterli gerekce");
            svc(30, 200).requireReason(); // gecer
        } finally {
            org.springframework.web.context.request.RequestContextHolder.resetRequestAttributes();
        }
    }

    @Test
    void generalFeedNeedsAUserSenderOrConversationFilter() {
        ApiException e = assertThrows(ApiException.class, () -> AdminChatFeedService.requireScope(null, null, null));
        assertEquals("FEED_FILTER_REQUIRED", e.code());
        assertEquals(400, e.status().value());
        AdminChatFeedService.requireScope(1L, null, null);
        AdminChatFeedService.requireScope(null, 2L, null);
        AdminChatFeedService.requireScope(null, null, 3L);
    }
}
