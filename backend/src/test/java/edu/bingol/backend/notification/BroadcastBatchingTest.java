package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.notification.fcm.PushMessage;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/**
 * P04: genel yayin tek islemde tum kullanici/cihaz listesini tarayip satir satir yazmaz; kullanici kimligi araliklariyla
 * (parca basina kendi kisa ifadesi) ilerler, uygulama ici kayit ve push ayri adimlardir.
 */
class BroadcastBatchingTest {

    private final NotificationRepository notifications = mock(NotificationRepository.class);
    private final DeviceRepository devices = mock(DeviceRepository.class);
    private final PushDispatcher dispatcher = mock(PushDispatcher.class);
    private final BroadcastWriter writer = mock(BroadcastWriter.class);
    private NotificationService svc;

    @BeforeEach
    void setUp() {
        svc = new NotificationService(notifications, mock(NotificationPrefRepository.class),
                mock(NotificationSubtypePrefRepository.class), devices, dispatcher, mock(I18n.class), PushGate.OPEN,
                RecipientGuard.ALLOW_ALL);
        svc.setBroadcastWriter(writer);
        when(writer.supported()).thenReturn(true);
        when(dispatcher.enabled()).thenReturn(true);
        when(dispatcher.rangeBroadcastSupported()).thenReturn(true);
    }

    @Test
    void thirtyThousandUsersAreWrittenInThirtyRangesNotOneTransactionOrOneTokenList() {
        // 30 aralik: 1000, 2000 ... 30000, sonra bitti
        when(writer.upperBound(anyLong(), eq(BroadcastWriter.RANGE))).thenAnswer(inv -> {
            long after = inv.getArgument(0);
            return after >= 30_000 ? null : after + 1000;
        });

        svc.broadcast(NotificationType.NEWS, "Baslik", "Govde", Map.of("newsId", "5"));

        verify(writer, times(30)).insertNotifications(eq(NotificationType.NEWS), eq("Baslik"), eq("Govde"), anyString(),
                eq("news"), isNull(), anyLong(), anyLong());
        verify(dispatcher, times(30)).dispatchRange(any(PushMessage.class), eq("news"), isNull(), anyLong(), anyLong());
        // ilk ve son aralik: (0,1000] ve (29000,30000]
        verify(writer).insertNotifications(any(), any(), any(), any(), any(), any(), eq(0L), eq(1000L));
        verify(writer).insertNotifications(any(), any(), any(), any(), any(), any(), eq(29_000L), eq(30_000L));
        // eski tam tarama yolu KULLANILMAZ (LIMIT'siz token listesi ve tek ifadelik tum-kullanici INSERT'u)
        verify(devices, never()).tokensForBroadcast(anyString());
        verify(notifications, never()).insertForAll(anyString(), anyString(), anyString(), any(), anyString());
    }

    @Test
    void aFailedRangeDoesNotStopLaterRangesAndPushStillRuns() {
        when(writer.upperBound(anyLong(), eq(BroadcastWriter.RANGE))).thenAnswer(inv -> {
            long after = inv.getArgument(0);
            return after >= 3000 ? null : after + 1000;
        });
        // 2. aralikta (1000,2000] kullanici satiri yazimi statement_timeout ile dusuyor
        doThrow(new IllegalStateException("statement timeout")).when(writer)
                .insertNotifications(any(), any(), any(), any(), any(), any(), eq(1000L), eq(2000L));

        svc.broadcast(NotificationType.ANNOUNCEMENT, "T", "B", Map.of());

        verify(writer, times(3)).insertNotifications(any(), any(), any(), any(), any(), any(), anyLong(), anyLong());
        // satir yazimi dusen aralikta bile push adimi calisir (iki adim ayri try)
        verify(dispatcher, times(3)).dispatchRange(any(PushMessage.class), eq("announcements"), isNull(), anyLong(),
                anyLong());
    }

    @Test
    void localizedBroadcastRunsOncePerLanguageWithLanguageFilter() {
        when(writer.upperBound(anyLong(), eq(BroadcastWriter.RANGE))).thenAnswer(inv -> {
            long after = inv.getArgument(0);
            return after >= 1000 ? null : after + 1000;
        });

        svc.broadcastLocalized(NotificationType.NEWS, l -> "t-" + l.code(), l -> "b-" + l.code(), Map.of());

        for (Lang l : Lang.values()) {
            verify(writer).insertNotifications(eq(NotificationType.NEWS), eq("t-" + l.code()), eq("b-" + l.code()), any(),
                    eq("news"), eq(l.code()), eq(0L), eq(1000L));
        }
        ArgumentCaptor<PushMessage> msg = ArgumentCaptor.forClass(PushMessage.class);
        verify(dispatcher, times(Lang.values().length)).dispatchRange(msg.capture(), eq("news"), anyString(), eq(0L),
                eq(1000L));
        assertTrue(msg.getAllValues().stream().anyMatch(m -> "t-tr".equals(m.title())));
    }

    @Test
    void fcmDisabledSkipsPushButStillWritesInboxRows() {
        when(dispatcher.enabled()).thenReturn(false);
        when(writer.upperBound(anyLong(), eq(BroadcastWriter.RANGE))).thenAnswer(inv -> (long) inv.getArgument(0) >= 1000 ? null : 1000L);

        svc.broadcast(NotificationType.NEWS, "T", "B", Map.of());

        verify(writer, times(1)).insertNotifications(any(), any(), any(), any(), any(), any(), anyLong(), anyLong());
        verify(dispatcher, never()).dispatchRange(any(), any(), any(), anyLong(), anyLong());
    }

    @Test
    void unsupportedDatabaseFallsBackToLegacyPath() {
        when(writer.supported()).thenReturn(false);
        when(devices.tokensForBroadcast("news")).thenReturn(List.of());

        svc.broadcast(NotificationType.NEWS, "T", "B", Map.of());

        verify(notifications).insertForAll(eq("NEWS"), eq("T"), eq("B"), any(), eq("news"));
        verify(writer, never()).upperBound(anyLong(), org.mockito.ArgumentMatchers.anyInt());
        assertEquals(0, 0);
    }
}
