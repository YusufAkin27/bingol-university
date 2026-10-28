package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.google.firebase.messaging.MessagingErrorCode;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.notification.fcm.FakeFcmSender;
import edu.bingol.backend.notification.fcm.FcmErrors;
import edu.bingol.backend.notification.fcm.PushMessage;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class PushDeliveryTest {

    private final NotificationRepository notifications = mock(NotificationRepository.class);
    private final NotificationPrefRepository prefs = mock(NotificationPrefRepository.class);
    private final NotificationSubtypePrefRepository subtypePrefs = mock(NotificationSubtypePrefRepository.class);
    private final DeviceRepository devices = mock(DeviceRepository.class);
    private final I18n i18n = mock(I18n.class);
    private final FakeFcmSender fcm = new FakeFcmSender();
    private final List<Runnable> timers = new ArrayList<>();
    private final List<Long> delays = new ArrayList<>();
    private final PushDispatcher dispatcher = new PushDispatcher(fcm, devices, Runnable::run, (task, ms) -> {
        timers.add(task);
        delays.add(ms);
    });
    private final NotificationService svc =
            new NotificationService(notifications, prefs, subtypePrefs, devices, dispatcher, i18n);

    private static Device device(String token) {
        Device d = new Device();
        d.setFcmToken(token);
        return d;
    }

    @BeforeEach
    void setUp() {
        when(notifications.save(any(Notification.class))).thenAnswer(i -> i.getArgument(0));
        when(prefs.findById(anyLong())).thenReturn(Optional.empty());
        when(subtypePrefs.findByUserIdAndSubtype(anyLong(), anyString())).thenReturn(Optional.empty());
        when(notifications.findFirstByUserIdAndCollapseKeyAndReadAtIsNullOrderByIdDesc(anyLong(), anyString()))
                .thenReturn(Optional.empty());
        when(devices.findByUserId(1L)).thenReturn(List.of(device("tok-aaaaaaaaaaaaaaaa")));
        when(i18n.langOf(anyLong())).thenReturn(Lang.TR);
    }

    @Test
    void disabledModeStillWritesInboxButSkipsPush() {
        fcm.setEnabled(false);

        svc.send(1L, NotificationType.NEWS, "T", "B", Map.of("newsId", "3"));

        verify(notifications).save(any(Notification.class));
        verify(devices, never()).findByUserId(1L);
        assertTrue(fcm.sent().isEmpty());
    }

    @Test
    void badgeIsUnreadCountAndPlatformFieldsAreSet() {
        when(notifications.countByUserIdAndReadAtIsNull(1L)).thenReturn(7L);

        svc.send(1L, NotificationType.MESSAGE, "Ali", "Merhaba", Map.of("conversationId", "9"));

        PushMessage m = fcm.messages().get(0);
        assertEquals(7, m.badge());
        assertEquals("conv:9", m.threadId());
        assertEquals("chat", m.channelId());
        assertEquals("MESSAGE", m.category());
        assertTrue(m.highPriority());
        assertEquals("CONVERSATION", m.data().get("targetType"));
        assertEquals("9", m.data().get("targetId"));
    }

    @Test
    void broadcastCarriesNoBadge() {
        when(devices.tokensForBroadcast("news")).thenReturn(List.of("tok-aaaaaaaaaaaaaaaa"));

        svc.broadcast(NotificationType.NEWS, "T", "B", Map.of("newsId", "1"));

        assertNull(fcm.messages().get(0).badge());
        assertEquals("announcement", fcm.messages().get(0).channelId());
    }

    @Test
    void droppedPushIsCountedWhenQueueIsFull() {
        PushDispatcher full = new PushDispatcher(fcm, devices, r -> {
            throw new java.util.concurrent.RejectedExecutionException("dolu");
        }, (task, ms) -> { });
        full.dispatch(List.of("tok-aaaaaaaaaaaaaaaa", "tok-bbbbbbbbbbbbbbbb"),
                edu.bingol.backend.notification.fcm.PushMessage.simple("T", "B", Map.of(), null));
        org.junit.jupiter.api.Assertions.assertEquals(2, full.droppedCount());
        org.junit.jupiter.api.Assertions.assertEquals(1, full.failureCount());
    }

    @Test
    void invalidTokensAreRemoved() {
        fcm.markInvalid("tok-aaaaaaaaaaaaaaaa");

        svc.send(1L, NotificationType.EVENT, "T", "B", Map.of("eventId", "2"));

        verify(devices).deleteByFcmTokenIn(List.of("tok-aaaaaaaaaaaaaaaa"));
    }

    @Test
    void transientFailureRetriesWithExponentialBackoff() {
        fcm.failTransient("tok-aaaaaaaaaaaaaaaa", 2);

        svc.send(1L, NotificationType.EVENT, "T", "B", Map.of("eventId", "2"));
        assertEquals(1, timers.size());
        assertEquals(5_000L, delays.get(0));

        timers.remove(0).run();
        assertEquals(1, timers.size());
        assertEquals(20_000L, delays.get(1));

        timers.remove(0).run(); // ucuncu deneme basarili
        assertTrue(timers.isEmpty());
        assertEquals(1, fcm.sent().size());
        assertEquals(0, dispatcher.failureCount());
        assertEquals(2, dispatcher.retryCount());
    }

    @Test
    void givesUpAfterMaxRetries() {
        fcm.failTransient("tok-aaaaaaaaaaaaaaaa", 100);

        svc.send(1L, NotificationType.EVENT, "T", "B", Map.of("eventId", "2"));
        for (int i = 0; i < PushDispatcher.MAX_RETRIES; i++) {
            timers.remove(0).run();
        }

        assertTrue(timers.isEmpty());
        assertEquals(1, dispatcher.failureCount());
        assertEquals(PushDispatcher.MAX_RETRIES, dispatcher.retryCount());
    }

    @Test
    void largeListsAreSplitInto500Chunks() {
        List<String> tokens = new ArrayList<>();
        for (int i = 0; i < 1100; i++) {
            tokens.add("tok-" + String.format("%016d", i));
        }

        dispatcher.dispatch(tokens, PushMessage.simple("T", "B", Map.of(), null));

        assertEquals(3, fcm.messages().size());
        assertEquals(1100, dispatcher.deliveredCount());
    }

    @Test
    void deviceCleanupDeletesStaleTokens() {
        when(devices.deleteStale(any(Instant.class))).thenReturn(4);

        assertEquals(4, new DeviceCleanupJob(devices, 60).run(Instant.now()));
        assertEquals(0, new DeviceCleanupJob(devices, 0).run(Instant.now()));
    }

    @Test
    void errorClassification() {
        assertEquals(FcmErrors.Kind.INVALID_TOKEN, FcmErrors.classify(MessagingErrorCode.UNREGISTERED, null));
        assertEquals(FcmErrors.Kind.INVALID_TOKEN,
                FcmErrors.classify(MessagingErrorCode.INVALID_ARGUMENT, "The registration token is not valid"));
        assertEquals(FcmErrors.Kind.PERMANENT, FcmErrors.classify(MessagingErrorCode.INVALID_ARGUMENT, "bad payload"));
        assertEquals(FcmErrors.Kind.RETRYABLE, FcmErrors.classify(MessagingErrorCode.UNAVAILABLE, null));
        assertEquals(FcmErrors.Kind.RETRYABLE, FcmErrors.classify(MessagingErrorCode.QUOTA_EXCEEDED, null));
        assertEquals(FcmErrors.Kind.RETRYABLE, FcmErrors.classify(null, null));
        assertFalse(FcmErrors.classify(MessagingErrorCode.THIRD_PARTY_AUTH_ERROR, null) == FcmErrors.Kind.RETRYABLE);
    }
}
