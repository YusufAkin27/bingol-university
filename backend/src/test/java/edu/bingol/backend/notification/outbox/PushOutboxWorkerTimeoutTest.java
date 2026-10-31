package edu.bingol.backend.notification.outbox;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.config.SchedulerLock;
import edu.bingol.backend.notification.Device;
import edu.bingol.backend.notification.DeviceRepository;
import edu.bingol.backend.notification.fcm.FcmSender;
import edu.bingol.backend.notification.fcm.PushMessage;
import edu.bingol.backend.notification.fcm.SendResult;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

/** T-074 (A2-10): takili FCM cagrisi turu sonsuza dek bloklamaz; zamanlayici is parcacigi FCM'i beklemez. */
class PushOutboxWorkerTimeoutTest {

    private final JsonMapper json = JsonMapper.builder().build();

    /** "stuck" basligli mesajda donmez (kilit acilana dek bekler), digerlerinde hemen basarili doner. */
    private static final class HangingFcm implements FcmSender {
        final CountDownLatch release = new CountDownLatch(1);
        final CountDownLatch entered = new CountDownLatch(1);
        volatile String callerThread;

        @Override
        public List<String> send(Collection<String> tokens, String title, String body, Map<String, String> data) {
            return List.of();
        }

        @Override
        public SendResult deliver(Collection<String> tokens, PushMessage m) {
            if ("stuck".equals(m.title())) {
                callerThread = Thread.currentThread().getName();
                entered.countDown();
                // Gercek bir HttpURLConnection okumasi gibi kesmeyi (interrupt) yok sayar: yalniz serbest birakilinca doner
                long end = System.nanoTime() + TimeUnit.SECONDS.toNanos(30);
                while (release.getCount() > 0 && System.nanoTime() < end) {
                    try {
                        release.await(50, TimeUnit.MILLISECONDS);
                    } catch (InterruptedException ignored) {
                        // yok sayilir
                    }
                }
            }
            return new SendResult(List.of(), List.of());
        }
    }

    private Device device(long id, String token) {
        Device d = new Device();
        d.setId(id);
        d.setUserId(100 + id);
        d.setFcmToken(token);
        d.setPlatform("android");
        return d;
    }

    private PushOutbox row(long id, Device d, String title) {
        PushOutbox o = new PushOutbox();
        o.setId(id);
        o.setUserId(d.getUserId());
        o.setDeviceId(d.getId());
        o.setPayloadJson(json.writeValueAsString(PushMessage.simple(title, "govde", Map.of("type", "SYSTEM"), null)));
        o.setStatus(PushOutboxStatus.SENDING);
        return o;
    }

    private PushOutboxWorker worker(PushOutboxRepository repo, DeviceRepository devices, FcmSender fcm) {
        return new PushOutboxWorker(repo, devices, fcm, json, new SimpleMeterRegistry(), mock(SchedulerLock.class),
                false, 500, 3, 24);
    }

    @Test
    void stuckGroupIsCancelledAndRetriedWhileHealthyGroupIsSent() {
        PushOutboxRepository repo = mock(PushOutboxRepository.class);
        DeviceRepository devices = mock(DeviceRepository.class);
        HangingFcm fcm = new HangingFcm();
        Device a = device(1, "tokA");
        Device b = device(2, "tokB");
        when(devices.findAllById(any())).thenReturn(List.of(a, b));
        PushOutboxWorker w = worker(repo, devices, fcm);
        w.setGroupSendTimeoutMs(300);
        PushOutbox stuck = row(1, a, "stuck");
        PushOutbox ok = row(2, b, "ok");

        long t0 = System.nanoTime();
        w.process(List.of(stuck, ok), Instant.now());
        long ms = (System.nanoTime() - t0) / 1_000_000;

        fcm.release.countDown();
        assertThat(ms).as("tur FCM'i sonsuza dek beklememeli").isLessThan(10_000);
        assertThat(ok.getStatus()).isEqualTo(PushOutboxStatus.SENT);
        assertThat(stuck.getStatus()).isEqualTo(PushOutboxStatus.FAILED);
        assertThat(stuck.getErrorCode()).isEqualTo("SEND_TIMEOUT");
        assertThat(stuck.getNextAttemptAt()).isAfter(Instant.now());
    }

    @Test
    void pollReturnsImmediatelyAndRunsFcmOffTheCallerThread() throws Exception {
        PushOutboxRepository repo = mock(PushOutboxRepository.class);
        DeviceRepository devices = mock(DeviceRepository.class);
        HangingFcm fcm = new HangingFcm();
        Device a = device(1, "tokA");
        PushOutbox stuck = row(1, a, "stuck");
        when(devices.findAllById(any())).thenReturn(List.of(a));
        when(repo.claimDue(any(), any(), anyInt())).thenReturn(List.of(stuck.getId()));
        when(repo.findAllById(any())).thenReturn(List.of(stuck));
        PushOutboxWorker w = worker(repo, devices, fcm);

        long t0 = System.nanoTime();
        w.poll(); // zamanlayici is parcacigi: yalniz siraya koyar
        long ms = (System.nanoTime() - t0) / 1_000_000;

        assertThat(ms).as("poll() FCM'i beklememeli").isLessThan(2_000);
        assertThat(fcm.entered.await(5, TimeUnit.SECONDS)).isTrue();
        assertThat(fcm.callerThread).isEqualTo("push-outbox-nudge");
        // takili tur surerken ikinci poll() de bloklamaz
        long t1 = System.nanoTime();
        w.poll();
        assertThat((System.nanoTime() - t1) / 1_000_000).isLessThan(2_000);
        fcm.release.countDown();
        w.shutdown();
    }
}
