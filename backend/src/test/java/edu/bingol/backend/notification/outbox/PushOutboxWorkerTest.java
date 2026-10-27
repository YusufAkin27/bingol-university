package edu.bingol.backend.notification.outbox;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.config.SchedulerLock;
import edu.bingol.backend.notification.Device;
import edu.bingol.backend.notification.DeviceRepository;
import edu.bingol.backend.notification.fcm.FakeFcmSender;
import edu.bingol.backend.notification.fcm.PushMessage;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

/** Push kuyruk isleyicisi: gonderim, geri cekilme, DEAD, gecersiz token, kurtarma, metrikler (servis katmani; SKIP LOCKED yok). */
class PushOutboxWorkerTest {

    private final JsonMapper json = JsonMapper.builder().build();
    private PushOutboxRepository repo;
    private DeviceRepository devices;
    private FakeFcmSender fcm;
    private SimpleMeterRegistry metrics;
    private PushOutboxWorker worker;
    private long nextId = 1;

    @BeforeEach
    void setUp() {
        repo = mock(PushOutboxRepository.class);
        devices = mock(DeviceRepository.class);
        fcm = new FakeFcmSender();
        metrics = new SimpleMeterRegistry();
        worker = new PushOutboxWorker(repo, devices, fcm, json, metrics, mock(SchedulerLock.class), false, 500, 3, 24);
    }

    private Device device(long id, String token) {
        Device d = new Device();
        d.setId(id);
        d.setUserId(100 + id);
        d.setFcmToken(token);
        d.setPlatform("android");
        return d;
    }

    private PushOutbox row(Device d, PushMessage m) {
        PushOutbox o = new PushOutbox();
        o.setId(nextId++);
        o.setUserId(d.getUserId());
        o.setDeviceId(d.getId());
        o.setPayloadJson(json.writeValueAsString(m));
        o.setStatus(PushOutboxStatus.SENDING);
        return o;
    }

    private static PushMessage msg(String title) {
        return PushMessage.simple(title, "govde", Map.of("type", "SYSTEM"), null);
    }

    private void devicesAre(Device... ds) {
        when(devices.findAllById(any())).thenReturn(List.of(ds));
    }

    @Test
    void successfulSendMarksSentAndGroupsSamePayloadIntoOneCall() {
        Device a = device(1, "tokA");
        Device b = device(2, "tokB");
        devicesAre(a, b);
        List<PushOutbox> rows = List.of(row(a, msg("Merhaba")), row(b, msg("Merhaba")));

        worker.process(rows, Instant.now());

        assertThat(rows).allMatch(r -> r.getStatus() == PushOutboxStatus.SENT && r.getSentAt() != null);
        assertThat(fcm.messages()).hasSize(1); // ayni yuk: tek multicast
        assertThat(fcm.last().tokens()).containsExactlyInAnyOrder("tokA", "tokB");
        assertThat(metrics.counter("push.outbox.sent").count()).isEqualTo(2.0);
        verify(repo).saveAll(rows);
    }

    @Test
    void differentPayloadsAreSentSeparately() {
        Device a = device(1, "tokA");
        Device b = device(2, "tokB");
        devicesAre(a, b);
        worker.process(List.of(row(a, msg("Bir")), row(b, msg("Iki"))), Instant.now());
        assertThat(fcm.messages()).extracting(PushMessage::title).containsExactlyInAnyOrder("Bir", "Iki");
    }

    @Test
    void transientFailureRetriesWithBackoffThenGoesDead() {
        Device a = device(1, "tokA");
        devicesAre(a);
        fcm.failTransient("tokA", 10);
        PushOutbox r = row(a, msg("X"));
        Instant now = Instant.now();

        worker.process(List.of(r), now);
        assertThat(r.getStatus()).isEqualTo(PushOutboxStatus.FAILED);
        assertThat(r.getAttempts()).isEqualTo(1);
        assertThat(r.getNextAttemptAt()).isAfter(now);
        assertThat(r.getLastError()).doesNotContain("tokA");

        r.setStatus(PushOutboxStatus.SENDING);
        worker.process(List.of(r), now);
        assertThat(r.getStatus()).isEqualTo(PushOutboxStatus.FAILED);
        assertThat(r.getNextAttemptAt()).isAfter(now.plus(Duration.ofSeconds(60))); // ikinci adim daha uzun

        r.setStatus(PushOutboxStatus.SENDING);
        worker.process(List.of(r), now);
        assertThat(r.getStatus()).isEqualTo(PushOutboxStatus.DEAD); // maxAttempts=3
        assertThat(metrics.counter("push.outbox.dead").count()).isEqualTo(1.0);
        assertThat(metrics.counter("push.outbox.failed").count()).isEqualTo(3.0);
    }

    @Test
    void unregisteredTokenDeletesDeviceAndGoesDeadWithoutRetry() {
        Device a = device(1, "tokA");
        Device b = device(2, "tokB");
        devicesAre(a, b);
        fcm.markInvalid("tokA");
        PushOutbox ra = row(a, msg("X"));
        PushOutbox rb = row(b, msg("X"));

        worker.process(List.of(ra, rb), Instant.now());

        assertThat(ra.getStatus()).isEqualTo(PushOutboxStatus.DEAD);
        assertThat(ra.getLastError()).contains("UNREGISTERED").doesNotContain("tokA");
        assertThat(rb.getStatus()).isEqualTo(PushOutboxStatus.SENT);
        verify(devices).deleteByFcmTokenIn(Set.of("tokA"));
    }

    @Test
    void missingDeviceGoesDeadWithoutSending() {
        Device a = device(1, "tokA");
        when(devices.findAllById(any())).thenReturn(List.of()); // cihaz silinmis
        PushOutbox r = row(a, msg("X"));

        worker.process(List.of(r), Instant.now());

        assertThat(r.getStatus()).isEqualTo(PushOutboxStatus.DEAD);
        assertThat(fcm.messages()).isEmpty();
    }

    @Test
    void tooOldMessageIsDroppedNotSent() {
        Device a = device(1, "tokA");
        devicesAre(a);
        PushOutbox r = row(a, msg("X"));
        r.setCreatedAt(Instant.now().minus(Duration.ofHours(30)));

        worker.process(List.of(r), Instant.now());

        assertThat(r.getStatus()).isEqualTo(PushOutboxStatus.DEAD);
        assertThat(r.getLastError()).contains("suresi doldu");
        assertThat(fcm.messages()).isEmpty();
    }

    @Test
    void senderExceptionIsNotLeakedAndRowsAreRetried() {
        Device a = device(1, "tokA");
        devicesAre(a);
        edu.bingol.backend.notification.fcm.FcmSender boom = new edu.bingol.backend.notification.fcm.FcmSender() {
            @Override
            public List<String> send(java.util.Collection<String> tokens, String title, String body, Map<String, String> data) {
                throw new IllegalStateException("secret-token-in-message");
            }

            @Override
            public edu.bingol.backend.notification.fcm.SendResult deliver(java.util.Collection<String> tokens, PushMessage m) {
                throw new IllegalStateException("secret-token-in-message");
            }
        };
        PushOutboxWorker w = new PushOutboxWorker(repo, devices, boom, json, metrics, mock(SchedulerLock.class), false, 500, 3, 24);
        PushOutbox r = row(a, msg("X"));

        w.process(List.of(r), Instant.now());

        assertThat(r.getStatus()).isEqualTo(PushOutboxStatus.FAILED);
        assertThat(r.getLastError()).isEqualTo("IllegalStateException");
    }

    @Test
    void largeGroupIsSplitIntoChunksOf500() {
        List<Device> ds = new ArrayList<>();
        List<PushOutbox> rows = new ArrayList<>();
        PushMessage m = msg("Toplu");
        for (int i = 1; i <= 1100; i++) {
            Device d = device(i, "tok" + i);
            ds.add(d);
            rows.add(row(d, m));
        }
        when(devices.findAllById(any())).thenReturn(ds);

        worker.process(rows, Instant.now());

        assertThat(fcm.messages()).hasSize(3); // 500 + 500 + 100
        assertThat(rows).allMatch(r -> r.getStatus() == PushOutboxStatus.SENT);
    }

    @Test
    void rowsNoLongerSendingAreSkipped() {
        Device a = device(1, "tokA");
        devicesAre(a);
        PushOutbox r = row(a, msg("X"));
        r.setStatus(PushOutboxStatus.SENT);

        worker.process(List.of(r), Instant.now());

        assertThat(fcm.messages()).isEmpty();
    }

    @Test
    void processDueClaimsAndSendsButDoesNothingWhenFcmDisabled() {
        Device a = device(1, "tokA");
        devicesAre(a);
        PushOutbox r = row(a, msg("X"));
        when(repo.claimDue(any(), any(), anyInt())).thenReturn(List.of(r.getId()));
        when(repo.findAllById(any())).thenReturn(List.of(r));

        worker.processDue();
        assertThat(r.getStatus()).isEqualTo(PushOutboxStatus.SENT);

        fcm.setEnabled(false);
        worker.processDue();
        // FCM kapaliyken ikinci kez claim yapilmaz: kayitlar PENDING'de bekler
        verify(repo, org.mockito.Mockito.times(1)).claimDue(any(), any(), anyInt());
    }

    @Test
    void restartRecoversStaleSendingRows() {
        when(repo.recoverStale(any())).thenReturn(4);
        worker.recoverOnStartup();
        verify(repo).recoverStale(any());
    }

    @Test
    void recoveryFailureNeverThrows() {
        when(repo.recoverStale(any())).thenThrow(new IllegalStateException("db down"));
        worker.recoverOnStartup(); // exception sizmaz
        when(repo.claimDue(any(), any(), anyInt())).thenThrow(new IllegalStateException("db down"));
        worker.processDue();
    }

    @Test
    void purgeDeletesFinishedAndStuckRows() {
        worker.purgeNow();
        verify(repo).deleteByStatusBefore(org.mockito.ArgumentMatchers.eq(PushOutboxStatus.SENT), any());
        verify(repo).deleteByStatusBefore(org.mockito.ArgumentMatchers.eq(PushOutboxStatus.DEAD), any());
        verify(repo).deleteByStatusInBefore(anyCollection(), any());
        verify(repo, never()).deleteAll();
    }

    @Test
    void backoffGrowsAndIsCapped() {
        assertThat(PushOutboxBackoff.delay(1)).isEqualTo(Duration.ofSeconds(30));
        assertThat(PushOutboxBackoff.delay(2)).isEqualTo(Duration.ofMinutes(2));
        assertThat(PushOutboxBackoff.delay(99)).isEqualTo(Duration.ofHours(6));
    }
}
