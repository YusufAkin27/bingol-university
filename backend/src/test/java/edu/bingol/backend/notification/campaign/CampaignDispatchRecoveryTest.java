package edu.bingol.backend.notification.campaign;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.notification.NotificationPrefRepository;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationService.BulkResult;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.notification.campaign.AudienceResolver.Member;
import edu.bingol.backend.notification.campaign.AudienceResolver.Resolved;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/**
 * P04 (K8): SENDING'de takili kampanya FAILED olur + "yeniden gonder"; kismi basarisizlik "SENT" gibi yazilmaz; yeniden
 * gonderim ilerleme isaretinden devam eder (gidenlere ikinci kez gitmez).
 */
class CampaignDispatchRecoveryTest {

    private final PushCampaignRepository campaigns = mock(PushCampaignRepository.class);
    private final AudienceResolver resolver = mock(AudienceResolver.class);
    private final NotificationService notifications = mock(NotificationService.class);
    private CampaignService service;

    @BeforeEach
    void setUp() {
        service = new CampaignService(campaigns, resolver, mock(NotificationPrefRepository.class), notifications,
                mock(CampaignCreateGuard.class));
    }

    private PushCampaign campaign() {
        PushCampaign c = new PushCampaign();
        c.setId(5L);
        c.setCreatedBy(1L);
        c.setType(NotificationType.ANNOUNCEMENT);
        c.setAudienceType(PushCampaign.AudienceType.ALL);
        c.setTitleTr("T");
        c.setBodyTr("B");
        c.setStatus(PushCampaign.Status.SENDING);
        c.setScheduledAt(Instant.now());
        when(campaigns.findById(5L)).thenReturn(Optional.of(c));
        return c;
    }

    private void audience(int n) {
        List<Member> members = new ArrayList<>();
        for (long i = 1; i <= n; i++) {
            members.add(new Member(i, "tr", "Kisi " + i, "k" + i + "@bingol.edu.tr"));
        }
        when(resolver.resolve(any(), any(), any())).thenReturn(new Resolved(members, List.of()));
    }

    @Test
    void whenEveryChunkFailsTheCampaignIsFailedNotSentWithZeroRecipients() {
        PushCampaign c = campaign();
        audience(10);
        when(notifications.sendBulkDetailed(anyCollection(), any(), anyString(), anyString(), anyMap(), anyString()))
                .thenReturn(new BulkResult(0, 1, 1));

        service.dispatch(5L);

        assertEquals(PushCampaign.Status.FAILED, c.getStatus());
        assertNotNull(c.getError());
        assertTrue(c.getError().contains("Hiçbir"));
        assertNotNull(c.getFinishedAt());
    }

    @Test
    void partialChunkFailureKeepsSentStatusButRecordsTheWarning() {
        PushCampaign c = campaign();
        audience(1200); // 500 + 500 + 200 -> 3 ilerleme parcasi
        when(notifications.sendBulkDetailed(anyCollection(), any(), anyString(), anyString(), anyMap(), anyString()))
                .thenReturn(new BulkResult(500, 1, 0), new BulkResult(0, 1, 1), new BulkResult(200, 1, 0));

        service.dispatch(5L);

        assertEquals(PushCampaign.Status.SENT, c.getStatus());
        assertEquals(700, c.getRecipientCount());
        assertTrue(c.getError().startsWith("Kısmi"), c.getError());
        assertEquals(1200L, c.getLastUserId());
    }

    @Test
    void progressMarkerIsSavedAfterEveryChunk() {
        PushCampaign c = campaign();
        audience(1200);
        when(notifications.sendBulkDetailed(anyCollection(), any(), anyString(), anyString(), anyMap(), anyString()))
                .thenReturn(new BulkResult(500, 1, 0));

        service.dispatch(5L);

        // 3 parca + son durum kaydi
        verify(campaigns, times(4)).save(c);
        assertNull(c.getError());
        assertEquals(PushCampaign.Status.SENT, c.getStatus());
    }

    @Test
    void resendContinuesAfterLastUserIdAndAccumulatesCount() {
        PushCampaign c = campaign();
        c.setLastUserId(3L);
        c.setRecipientCount(3);
        audience(5);
        when(notifications.sendBulkDetailed(anyCollection(), any(), anyString(), anyString(), anyMap(), anyString()))
                .thenReturn(new BulkResult(2, 1, 0));

        service.dispatch(5L);

        @SuppressWarnings("unchecked")
        ArgumentCaptor<java.util.Collection<Long>> sentTo = ArgumentCaptor.forClass(java.util.Collection.class);
        verify(notifications).sendBulkDetailed(sentTo.capture(), eq(NotificationType.ANNOUNCEMENT), anyString(), anyString(),
                anyMap(), anyString());
        assertEquals(List.of(4L, 5L), new ArrayList<>(sentTo.getValue())); // 1..3'e ikinci kez gitmez
        assertEquals(5, c.getRecipientCount());
        assertEquals(PushCampaign.Status.SENT, c.getStatus());
    }

    @Test
    void resolverFailureMarksCampaignFailed() {
        PushCampaign c = campaign();
        when(resolver.resolve(any(), any(), any())).thenThrow(new IllegalStateException("db"));

        service.dispatch(5L);

        assertEquals(PushCampaign.Status.FAILED, c.getStatus());
        verify(notifications, never()).sendBulkDetailed(anyCollection(), any(), anyString(), anyString(), anyMap(),
                anyString());
    }

    @Test
    void recoverStaleFailsLongSilentSendingCampaignsWithoutRescheduling() {
        when(campaigns.failStale(any(), anyString())).thenReturn(2);

        service.recoverStale();

        ArgumentCaptor<Instant> cutoff = ArgumentCaptor.forClass(Instant.class);
        verify(campaigns).failStale(cutoff.capture(), anyString());
        // varsayilan 30 dk: esik yaklasik simdi - 30 dk
        long minutes = java.time.Duration.between(cutoff.getValue(), Instant.now()).toMinutes();
        assertTrue(minutes >= 29 && minutes <= 31, "esik " + minutes);
        verify(campaigns, never()).resendIfFailed(any());
    }

    @Test
    void resendOnlyWorksForFailedCampaigns() {
        PushCampaign c = campaign();
        c.setStatus(PushCampaign.Status.SENT);
        when(campaigns.resendIfFailed(5L)).thenReturn(0);

        ApiException e = assertThrows(ApiException.class, () -> service.resend(5L));
        assertEquals("CAMPAIGN_NOT_RESENDABLE", e.code());

        when(campaigns.resendIfFailed(5L)).thenReturn(1);
        assertEquals(5L, service.resend(5L).getId());
    }
}
