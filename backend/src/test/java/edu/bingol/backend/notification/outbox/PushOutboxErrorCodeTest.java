package edu.bingol.backend.notification.outbox;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.config.SchedulerLock;
import edu.bingol.backend.notification.Device;
import edu.bingol.backend.notification.DeviceRepository;
import edu.bingol.backend.notification.fcm.FakeFcmSender;
import edu.bingol.backend.notification.fcm.PushMessage;
import edu.bingol.backend.notification.fcm.SendResult;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import java.time.Duration;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

/** P14: isleyici hata KODUNU kayda yazar (yonetici hata listesi bu kodlara gore gruplar); kampanya baglantisi yazilir. */
class PushOutboxErrorCodeTest {

    private final JsonMapper json = JsonMapper.builder().build();
    private DeviceRepository devices;
    private FakeFcmSender fcm;
    private PushOutboxWorker worker;
    private long nextId = 1;

    @BeforeEach
    void setUp() {
        devices = mock(DeviceRepository.class);
        fcm = new FakeFcmSender();
        worker = new PushOutboxWorker(mock(PushOutboxRepository.class), devices, fcm, json, new SimpleMeterRegistry(),
                mock(SchedulerLock.class), false, 500, 3, 24);
    }

    private Device device(long id, String token) {
        Device d = new Device();
        d.setId(id);
        d.setUserId(100 + id);
        d.setFcmToken(token);
        d.setPlatform("android");
        return d;
    }

    private PushOutbox row(Device d) {
        PushOutbox o = new PushOutbox();
        o.setId(nextId++);
        o.setDeviceId(d.getId());
        o.setUserId(d.getUserId());
        o.setPayloadJson(json.writeValueAsString(PushMessage.simple("T", "B", Map.of("type", "SYSTEM"), null)));
        o.setStatus(PushOutboxStatus.SENDING);
        return o;
    }

    @Test
    void invalidTokenGetsUnregisteredCodeAndSuccessClearsIt() {
        Device a = device(1, "tokA");
        Device b = device(2, "tokB");
        when(devices.findAllById(any())).thenReturn(List.of(a, b));
        fcm.markInvalid("tokA");
        PushOutbox ra = row(a);
        PushOutbox rb = row(b);
        rb.setErrorCode("OLD");

        worker.process(List.of(ra, rb), Instant.now());

        assertThat(ra.getStatus()).isEqualTo(PushOutboxStatus.DEAD);
        assertThat(ra.getErrorCode()).isEqualTo("UNREGISTERED");
        assertThat(rb.getStatus()).isEqualTo(PushOutboxStatus.SENT);
        assertThat(rb.getErrorCode()).isNull();
    }

    @Test
    void transientFailureWithoutDetailGetsUnavailableAndSenderCodeWins() {
        Device a = device(1, "tokA");
        when(devices.findAllById(any())).thenReturn(List.of(a));
        fcm.failTransient("tokA", 5);
        PushOutbox r = row(a);
        worker.process(List.of(r), Instant.now());
        assertThat(r.getStatus()).isEqualTo(PushOutboxStatus.FAILED);
        assertThat(r.getErrorCode()).isEqualTo("UNAVAILABLE");

        // gonderici ayrintili kod doner (QUOTA_EXCEEDED): kayda o yazilir
        PushOutboxWorker w = new PushOutboxWorker(mock(PushOutboxRepository.class), devices, new FakeFcmSender() {
            @Override
            public SendResult deliver(Collection<String> tokens, PushMessage m) {
                return new SendResult(List.of(), List.copyOf(tokens), Map.of("tokA", "QUOTA_EXCEEDED"));
            }
        }, json, new SimpleMeterRegistry(), mock(SchedulerLock.class), false, 500, 3, 24);
        PushOutbox r2 = row(a);
        w.process(List.of(r2), Instant.now());
        assertThat(r2.getErrorCode()).isEqualTo("QUOTA_EXCEEDED");
    }

    @Test
    void permanentErrorIsDeadWithCodeNotSentAndKeepsTheDevice() {
        Device a = device(1, "tokA");
        when(devices.findAllById(any())).thenReturn(List.of(a));
        PushOutboxWorker w = new PushOutboxWorker(mock(PushOutboxRepository.class), devices, new FakeFcmSender() {
            @Override
            public SendResult deliver(Collection<String> tokens, PushMessage m) {
                // iOS: APNs anahtari yuklenmemis -> THIRD_PARTY_AUTH_ERROR (kalici; token gecerli)
                return new SendResult(List.of(), List.of(), Map.of("tokA", "THIRD_PARTY_AUTH_ERROR"), List.copyOf(tokens));
            }
        }, json, new SimpleMeterRegistry(), mock(SchedulerLock.class), false, 500, 3, 24);
        PushOutbox r = row(a);

        w.process(List.of(r), Instant.now());

        assertThat(r.getStatus()).isEqualTo(PushOutboxStatus.DEAD); // eskiden "SENT" sayilirdi
        assertThat(r.getErrorCode()).isEqualTo("THIRD_PARTY_AUTH_ERROR");
        assertThat(w.errorCodeCounts()).containsEntry("THIRD_PARTY_AUTH_ERROR", 1L);
        org.mockito.Mockito.verify(devices, org.mockito.Mockito.never()).deleteByFcmTokenIn(any());
    }

    @Test
    void differentPayloadGroupsAreAllSentWhenProcessedTogether() {
        Device a = device(1, "tokA");
        Device b = device(2, "tokB");
        Device c = device(3, "tokC");
        when(devices.findAllById(any())).thenReturn(List.of(a, b, c));
        List<PushOutbox> rows = new java.util.ArrayList<>();
        for (Device d : List.of(a, b, c)) {
            PushOutbox o = row(d);
            o.setPayloadJson(json.writeValueAsString(PushMessage.simple("T" + d.getId(), "B", Map.of("type", "MESSAGE"), null)));
            rows.add(o);
        }

        worker.process(rows, Instant.now());

        assertThat(rows).allMatch(r -> r.getStatus() == PushOutboxStatus.SENT);
        assertThat(fcm.messages()).hasSize(3);
    }

    @Test
    void ttlSecondsSurvivesQueueSerialization() {
        PushMessage m = new PushMessage("T", "B", Map.of("type", "MESSAGE"), "conv:1", "conv:1", "chat", "MESSAGE", 3, true,
                604_800);
        PushMessage back = json.readValue(json.writeValueAsString(m), PushMessage.class);
        assertThat(back.ttlSeconds()).isEqualTo(604_800);
        // ttl alanindan once yazilmis kuyruk satiri (eski surum) hala okunur
        PushMessage old = json.readValue("{\"title\":\"T\",\"body\":\"B\",\"data\":{},\"highPriority\":true}", PushMessage.class);
        assertThat(old.ttlSeconds()).isNull();
    }

    @Test
    void expiredAndMissingDeviceGetOwnCodes() {
        Device a = device(1, "tokA");
        when(devices.findAllById(any())).thenReturn(List.of(a));
        PushOutbox old = row(a);
        old.setCreatedAt(Instant.now().minus(Duration.ofHours(48)));
        Device ghost = device(99, "ghost");
        PushOutbox missing = row(ghost);

        worker.process(List.of(old, missing), Instant.now());

        assertThat(old.getErrorCode()).isEqualTo("EXPIRED");
        assertThat(missing.getErrorCode()).isEqualTo("DEVICE_MISSING");
    }

    @Test
    void campaignIdIsParsedFromPayloadData() {
        PushMessage withCampaign = PushMessage.simple("T", "B", Map.of("campaignId", "42"), null);
        assertThat(PushOutboxService.campaignIdOf(withCampaign)).isEqualTo(42L);
        assertThat(PushOutboxService.campaignIdOf(PushMessage.simple("T", "B", Map.of("campaignId", "x1"), null))).isNull();
        assertThat(PushOutboxService.campaignIdOf(PushMessage.simple("T", "B", Map.of(), null))).isNull();
        assertThat(PushOutboxService.campaignIdOf(PushMessage.simple("T", "B", Map.of("campaignId", "99999999999999999999"), null)))
                .isNull();
    }
}
