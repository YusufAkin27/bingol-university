package edu.bingol.backend.notification.outbox;

import edu.bingol.backend.common.Hashing;
import edu.bingol.backend.notification.Device;
import edu.bingol.backend.notification.DeviceRepository;
import edu.bingol.backend.notification.fcm.FcmSender;
import edu.bingol.backend.notification.fcm.PushMessage;
import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.MeterRegistry;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.json.JsonMapper;

/**
 * Kalici push kuyrugunun yazma ve yonetim yuzu. NotificationService / kampanyalar PushDispatcher uzerinden buraya yazar;
 * gonderimi {@link PushOutboxWorker} yapar. Servis sozlesmesi: cagirana "FCM kapali" gibi beklenen durumlar exception sizdirmaz.
 */
@Service
@ConditionalOnProperty(name = "app.push.outbox.enabled", havingValue = "true", matchIfMissing = true)
public class PushOutboxService {

    private static final Logger log = LoggerFactory.getLogger(PushOutboxService.class);
    /** IN (...) listeleri icin parca boyutu. */
    static final int CHUNK = 500;

    /** Yonetici ozeti. */
    public record Stats(boolean enabled, boolean holdWhenDisabled, long pending, long sending, long failed, long dead,
                        long sentLast24h, Long oldestPendingAgeSeconds, Instant oldestPendingAt) {
    }

    private final PushOutboxRepository repo;
    private final DeviceRepository devices;
    private final FcmSender fcm;
    private final JsonMapper json;
    private final MeterRegistry metrics;
    private final ApplicationEventPublisher events;
    private final boolean holdWhenDisabled;

    public PushOutboxService(PushOutboxRepository repo, DeviceRepository devices, FcmSender fcm, JsonMapper json,
                             MeterRegistry metrics, ApplicationEventPublisher events,
                             @Value("${app.push.outbox.hold-when-disabled:false}") boolean holdWhenDisabled) {
        this.repo = repo;
        this.devices = devices;
        this.fcm = fcm;
        this.json = json;
        this.metrics = metrics;
        this.events = events;
        this.holdWhenDisabled = holdWhenDisabled;
        Gauge.builder("push.outbox.pending", this, s -> s.safeCount(PushOutboxStatus.PENDING) + s.safeCount(PushOutboxStatus.FAILED))
                .register(metrics);
    }

    private double safeCount(PushOutboxStatus st) {
        try {
            return repo.countByStatus(st);
        } catch (RuntimeException e) {
            return Double.NaN;
        }
    }

    public boolean holdWhenDisabled() {
        return holdWhenDisabled;
    }

    /** FCM etkin degilse ve tutma ayari kapaliysa kayit yazmanin anlami yoktur (birikmesin). */
    public boolean accepting() {
        return fcm.enabled() || holdWhenDisabled;
    }

    /** Dolduruldugunda kuyruga yazilmayip atlanan cihaz sayisini sayar (FCM kapali, tutma kapali). */
    public void skipped(int count) {
        metrics.counter("push.outbox.skipped").increment(count);
    }

    /**
     * Token listesine mesaj yazar (cihaz kimligine cozulur; bilinmeyen token atlanir).
     * @return yazilan kayit sayisi
     */
    @Transactional
    public int enqueueTokens(Collection<String> tokens, PushMessage message, String dedupeKey) {
        if (tokens == null || tokens.isEmpty()) {
            return 0;
        }
        List<String> all = List.copyOf(tokens);
        List<Device> found = new ArrayList<>();
        for (int i = 0; i < all.size(); i += CHUNK) {
            found.addAll(devices.findByFcmTokenIn(all.subList(i, Math.min(i + CHUNK, all.size()))));
        }
        return enqueueDevices(found, message, dedupeKey);
    }

    /** Kullanicinin tum cihazlarina. */
    @Transactional
    public int enqueueForUser(Long userId, PushMessage message, String dedupeKey) {
        return enqueueDevices(devices.findByUserId(userId), message, dedupeKey);
    }

    /** Verilen cihazlara tek mesaj; ayni dedupeKey ile bekleyen kaydi olan cihaz atlanir. */
    @Transactional
    public int enqueueDevices(Collection<Device> targets, PushMessage message, String dedupeKey) {
        if (targets == null || targets.isEmpty()) {
            return 0;
        }
        String payload;
        try {
            payload = json.writeValueAsString(message);
        } catch (RuntimeException e) {
            log.warn("Push yuku serilestirilemedi: {}", e.getClass().getSimpleName());
            return 0;
        }
        String key = dedupeKey == null ? null : dedupeKey.substring(0, Math.min(dedupeKey.length(), 120));
        short priority = (short) (message.highPriority() ? 1 : 0);
        Instant now = Instant.now();
        List<PushOutbox> rows = new ArrayList<>(targets.size());
        for (Device d : targets) {
            if (key != null && repo.existsActive(key, d.getId())) {
                continue;
            }
            PushOutbox o = new PushOutbox();
            o.setUserId(d.getUserId());
            o.setDeviceId(d.getId());
            o.setFcmTokenHash(Hashing.sha256(d.getFcmToken()));
            o.setPayloadJson(payload);
            o.setPriority(priority);
            o.setNextAttemptAt(now);
            o.setCreatedAt(now);
            o.setDedupeKey(key);
            o.setCampaignId(campaignIdOf(message));
            o.setMsgType(message.category() == null ? null
                    : message.category().substring(0, Math.min(message.category().length(), 24)));
            rows.add(o);
        }
        if (rows.isEmpty()) {
            return 0;
        }
        repo.saveAll(rows);
        metrics.counter("push.outbox.enqueued").increment(rows.size());
        events.publishEvent(new PushQueued(rows.size()));
        return rows.size();
    }

    /** Yuktaki data.campaignId (yonetici kampanyasi); sayi degilse null. */
    static Long campaignIdOf(PushMessage message) {
        String v = message.data() == null ? null : message.data().get("campaignId");
        if (v == null || v.isBlank() || v.length() > 18) {
            return null;
        }
        try {
            return Long.valueOf(v.trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    public Stats stats() {
        Instant now = Instant.now();
        Instant oldest = repo.oldestPendingAt();
        return new Stats(fcm.enabled(), holdWhenDisabled,
                repo.countByStatus(PushOutboxStatus.PENDING), repo.countByStatus(PushOutboxStatus.SENDING),
                repo.countByStatus(PushOutboxStatus.FAILED), repo.countByStatus(PushOutboxStatus.DEAD),
                repo.countByStatusAndSentAtAfter(PushOutboxStatus.SENT, now.minus(Duration.ofHours(24))),
                oldest == null ? null : Math.max(0, Duration.between(oldest, now).toSeconds()), oldest);
    }

    /** DEAD kayitlari PENDING'e dondurur (deneme sayaci sifirlanir). */
    public int retryDead() {
        int n = repo.requeueDead(Instant.now());
        if (n > 0) {
            events.publishEvent(new PushQueued(n));
        }
        return n;
    }

    /** Hesap silme: kullanicinin bekleyen push'lari silinir. */
    public int purgeUser(Long userId) {
        return repo.deleteByUser(userId);
    }
}
