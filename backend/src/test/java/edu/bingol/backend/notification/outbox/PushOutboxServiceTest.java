package edu.bingol.backend.notification.outbox;

import static org.assertj.core.api.Assertions.assertThat;

import edu.bingol.backend.notification.Device;
import edu.bingol.backend.notification.DeviceRepository;
import edu.bingol.backend.notification.fcm.PushMessage;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

/** Kalici push kuyrugu (H2): kayit, cihaz cozumleme, tekillestirme, ozet, olu kayitlari yeniden deneme, temizlik. */
@SpringBootTest
class PushOutboxServiceTest {

    @Autowired PushOutboxService service;
    @Autowired PushOutboxRepository repo;
    @Autowired DeviceRepository devices;
    @Autowired UserRepository users;

    private final PushMessage message = new PushMessage("Baslik", "Govde", Map.of("type", "SYSTEM"), null, null, null, null, null, true);

    @BeforeEach
    void clean() {
        repo.deleteAll();
    }

    private Device device() {
        User u = new User();
        u.setEmail("o" + UUID.randomUUID().toString().substring(0, 8) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName("Kuyruk Test");
        u.setEmailVerified(true);
        u = users.saveAndFlush(u);
        Device d = new Device();
        d.setUserId(u.getId());
        d.setFcmToken("tok-" + UUID.randomUUID());
        d.setPlatform("android");
        return devices.saveAndFlush(d);
    }

    @Test
    void enqueueResolvesDevicesAndStoresNoRawToken() {
        Device a = device();
        Device b = device();

        int n = service.enqueueTokens(List.of(a.getFcmToken(), b.getFcmToken(), "bilinmeyen-token"), message, null);

        assertThat(n).isEqualTo(2); // bilinmeyen token atlanir
        List<PushOutbox> rows = repo.findAll();
        assertThat(rows).hasSize(2).allSatisfy(r -> {
            assertThat(r.getStatus()).isEqualTo(PushOutboxStatus.PENDING);
            assertThat(r.getPriority()).isEqualTo((short) 1); // highPriority
            assertThat(r.getFcmTokenHash()).hasSize(64).isNotEqualTo(a.getFcmToken());
            assertThat(r.getPayloadJson()).contains("Baslik").doesNotContain(a.getFcmToken()).doesNotContain(b.getFcmToken());
        });
        assertThat(rows).extracting(PushOutbox::getDeviceId).containsExactlyInAnyOrder(a.getId(), b.getId());
    }

    @Test
    void dedupeKeySkipsDeviceThatAlreadyHasPendingMessage() {
        Device a = device();
        assertThat(service.enqueueTokens(List.of(a.getFcmToken()), message, "poll:1:opened")).isEqualTo(1);
        assertThat(service.enqueueTokens(List.of(a.getFcmToken()), message, "poll:1:opened")).isZero();
        assertThat(service.enqueueTokens(List.of(a.getFcmToken()), message, "poll:2:opened")).isEqualTo(1);
        assertThat(repo.count()).isEqualTo(2);
    }

    @Test
    void enqueueForUserTargetsAllUserDevices() {
        Device a = device();
        Device second = new Device();
        second.setUserId(a.getUserId());
        second.setFcmToken("tok-" + UUID.randomUUID());
        second.setPlatform("ios");
        devices.saveAndFlush(second);

        assertThat(service.enqueueForUser(a.getUserId(), message, null)).isEqualTo(2);
    }

    @Test
    void statsReportQueueStateAndOldestPending() {
        Device a = device();
        service.enqueueTokens(List.of(a.getFcmToken()), message, null);
        PushOutbox dead = repo.findAll().get(0);
        PushOutbox old = new PushOutbox();
        old.setPayloadJson("{}");
        old.setDeviceId(a.getId());
        old.setStatus(PushOutboxStatus.DEAD);
        repo.save(old);

        PushOutboxService.Stats s = service.stats();

        assertThat(s.pending()).isEqualTo(1);
        assertThat(s.dead()).isEqualTo(1);
        assertThat(s.oldestPendingAgeSeconds()).isNotNull().isGreaterThanOrEqualTo(0);
        assertThat(dead.getId()).isNotNull();
    }

    @Test
    void retryDeadMovesDeadRowsBackToPendingWithResetCounters() {
        Device a = device();
        service.enqueueTokens(List.of(a.getFcmToken()), message, null);
        PushOutbox r = repo.findAll().get(0);
        r.setStatus(PushOutboxStatus.DEAD);
        r.setAttempts(6);
        r.setLastError("x");
        repo.saveAndFlush(r);

        assertThat(service.retryDead()).isEqualTo(1);

        PushOutbox again = repo.findById(r.getId()).orElseThrow();
        assertThat(again.getStatus()).isEqualTo(PushOutboxStatus.PENDING);
        assertThat(again.getAttempts()).isZero();
        assertThat(service.retryDead()).isZero();
    }

    @Test
    void recoverStaleOnlyTouchesExpiredLeases() {
        Device a = device();
        service.enqueueTokens(List.of(a.getFcmToken(), device().getFcmToken()), message, null);
        List<PushOutbox> rows = repo.findAll();
        rows.get(0).setStatus(PushOutboxStatus.SENDING);
        rows.get(0).setLeaseUntil(Instant.now().minus(Duration.ofMinutes(1))); // cokmus surec
        rows.get(1).setStatus(PushOutboxStatus.SENDING);
        rows.get(1).setLeaseUntil(Instant.now().plus(Duration.ofMinutes(4))); // yasayan surec
        repo.saveAllAndFlush(rows);

        assertThat(repo.recoverStale(Instant.now())).isEqualTo(1);

        assertThat(repo.findById(rows.get(0).getId()).orElseThrow().getStatus()).isEqualTo(PushOutboxStatus.PENDING);
        assertThat(repo.findById(rows.get(1).getId()).orElseThrow().getStatus()).isEqualTo(PushOutboxStatus.SENDING);
    }

    @Test
    void purgeDeletesOnlyOldFinishedRows() {
        Device a = device();
        PushOutbox oldSent = row(a, PushOutboxStatus.SENT, Instant.now().minus(Duration.ofDays(8)));
        PushOutbox freshSent = row(a, PushOutboxStatus.SENT, Instant.now());
        PushOutbox oldDead = row(a, PushOutboxStatus.DEAD, Instant.now().minus(Duration.ofDays(8)));
        repo.saveAll(List.of(oldSent, freshSent, oldDead));

        int n = repo.deleteByStatusBefore(PushOutboxStatus.SENT, Instant.now().minus(PushOutboxWorker.SENT_RETENTION));

        assertThat(n).isEqualTo(1);
        assertThat(repo.count()).isEqualTo(2); // taze SENT ve 8 gunluk DEAD (DEAD 30 gun tutulur) kalir
    }

    @Test
    void purgeUserRemovesTheUsersPendingPush() {
        Device a = device();
        service.enqueueTokens(List.of(a.getFcmToken()), message, null);
        assertThat(service.purgeUser(a.getUserId())).isEqualTo(1);
        assertThat(repo.count()).isZero();
    }

    private PushOutbox row(Device d, PushOutboxStatus status, Instant created) {
        PushOutbox o = new PushOutbox();
        o.setUserId(d.getUserId());
        o.setDeviceId(d.getId());
        o.setPayloadJson("{}");
        o.setStatus(status);
        o.setCreatedAt(created);
        return o;
    }
}
