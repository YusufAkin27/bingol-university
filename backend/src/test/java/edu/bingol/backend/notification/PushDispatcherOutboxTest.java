package edu.bingol.backend.notification;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.notification.fcm.FakeFcmSender;
import edu.bingol.backend.notification.fcm.PushMessage;
import edu.bingol.backend.notification.outbox.PushOutboxService;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

/** PushDispatcher kalici kuyruk yolu: yazma, FCM kapali (tutma acik/kapali), kuyruk hatasinda bellek yoluna dusme. */
class PushDispatcherOutboxTest {

    private final FakeFcmSender fcm = new FakeFcmSender();
    private final DeviceRepository devices = mock(DeviceRepository.class);
    private final PushOutboxService outbox = mock(PushOutboxService.class);
    private final PushMessage message = PushMessage.simple("T", "B", Map.of(), null);

    @Test
    void dispatchWritesToPersistentQueueInsteadOfSendingDirectly() {
        when(outbox.accepting()).thenReturn(true);
        PushDispatcher d = new PushDispatcher(fcm, devices, outbox);

        d.dispatch(List.of("a", "b"), message);

        verify(outbox).enqueueTokens(List.of("a", "b"), message, null);
        assertThat(fcm.messages()).isEmpty(); // dogrudan gonderim yok: isleyici gonderir
        d.shutdown();
    }

    @Test
    void fcmDisabledAndNotHoldingSkipsAndCountsWithoutQueueing() {
        fcm.setEnabled(false);
        when(outbox.accepting()).thenReturn(false);
        when(outbox.holdWhenDisabled()).thenReturn(false);
        PushDispatcher d = new PushDispatcher(fcm, devices, outbox);

        assertThat(d.enabled()).isFalse();
        d.dispatch(List.of("a", "b", "c"), message);

        verify(outbox).skipped(3);
        verify(outbox, never()).enqueueTokens(any(), any(), any());
        d.shutdown();
    }

    @Test
    void holdWhenDisabledKeepsPushPendingEvenWithoutFcm() {
        fcm.setEnabled(false);
        when(outbox.accepting()).thenReturn(true);
        when(outbox.holdWhenDisabled()).thenReturn(true);
        PushDispatcher d = new PushDispatcher(fcm, devices, outbox);

        assertThat(d.enabled()).isTrue(); // NotificationService push'u uretmeye devam eder
        assertThat(d.fcmEnabled()).isFalse();
        d.dispatch(List.of("a"), message);

        verify(outbox).enqueueTokens(List.of("a"), message, null);
        d.shutdown();
    }

    @Test
    void queueWriteFailureFallsBackToInMemoryPathWhenFcmIsUp() throws Exception {
        when(outbox.accepting()).thenReturn(true);
        when(outbox.enqueueTokens(any(), any(), any())).thenThrow(new IllegalStateException("db down"));
        PushDispatcher d = new PushDispatcher(fcm, devices, outbox);

        d.dispatch(List.of("a"), message);

        for (int i = 0; i < 40 && fcm.messages().isEmpty(); i++) {
            Thread.sleep(50);
        }
        assertThat(fcm.messages()).hasSize(1);
        assertThat(d.failureCount()).isEqualTo(1);
        d.shutdown();
    }

    @Test
    void withoutOutboxBehavesAsBefore() {
        PushDispatcher d = new PushDispatcher(fcm, devices);
        fcm.setEnabled(false);
        assertThat(d.enabled()).isFalse();
        d.dispatch(List.of("a"), message);
        assertThat(fcm.messages()).isEmpty();
        verify(outbox, never()).skipped(anyInt());
        verify(outbox, never()).enqueueTokens(any(), eq(message), any());
        d.shutdown();
    }
}
