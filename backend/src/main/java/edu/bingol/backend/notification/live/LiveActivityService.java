package edu.bingol.backend.notification.live;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.event.EventRsvp;
import edu.bingol.backend.event.EventRsvpRepository;
import edu.bingol.backend.event.UserEvent;
import edu.bingol.backend.event.UserEventRepository;
import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * iOS Canli Etkinlik kayitlari. Yalniz kullanicinin KENDI sureci: katildigi (GOING) etkinlik ya da kendi girdigi
 * sinav. Baska kullanicinin etkinligi/sinavi icin kayit acilmaz (404 benzeri genel hata, varlik sizdirmaz).
 * Jeton cihazdan gelir; bildirim yukune konmaz, log'a yazilmaz.
 */
@Service
public class LiveActivityService {

    private static final Logger log = LoggerFactory.getLogger(LiveActivityService.class);

    static final int MAX_ACTIVE_PER_USER = 5;
    /** iOS: bir Canli Etkinlik en cok 8 saat etkin + 4 saat kilit ekraninda; sunucu kaydi bunu asmaz. */
    static final Duration MAX_LIFETIME = Duration.ofHours(12);

    public record Registration(String activityId, LiveActivity.Kind kind, Long refId, String pushToken) {}

    public record Status(boolean apnsConfigured, int maxActive) {}

    private final LiveActivityRepository repo;
    private final EventRsvpRepository rsvps;
    private final UserEventRepository events;
    private final JdbcTemplate jdbc;
    private final ApnsLiveActivitySender apns;

    public LiveActivityService(LiveActivityRepository repo, EventRsvpRepository rsvps, UserEventRepository events,
                               JdbcTemplate jdbc, ApnsLiveActivitySender apns) {
        this.repo = repo;
        this.rsvps = rsvps;
        this.events = events;
        this.jdbc = jdbc;
        this.apns = apns;
    }

    public Status status() {
        return new Status(apns.configured(), MAX_ACTIVE_PER_USER);
    }

    /** Kaydi olusturur ya da (ayni activityId) jetonu gunceller; idempotenttir. */
    @Transactional
    public void register(Long userId, Registration r, Instant now) {
        Instant end = refEnd(userId, r.kind(), r.refId());
        Instant expires = end == null ? now.plus(MAX_LIFETIME)
                : min(now.plus(MAX_LIFETIME), end.plus(Duration.ofHours(1)));
        if (!expires.isAfter(now)) {
            throw invalidRef();
        }
        LiveActivity a = repo.findByUserIdAndActivityId(userId, r.activityId()).orElse(null);
        if (a == null) {
            if (repo.countActive(userId, now) >= MAX_ACTIVE_PER_USER) {
                throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "LIVE_ACTIVITY_LIMIT",
                        "En fazla " + MAX_ACTIVE_PER_USER + " canlı etkinlik başlatabilirsiniz.",
                        String.valueOf(MAX_ACTIVE_PER_USER));
            }
            a = new LiveActivity();
            a.setUserId(userId);
            a.setActivityId(r.activityId());
        }
        a.setKind(r.kind());
        a.setRefId(r.refId());
        if (r.pushToken() != null && !r.pushToken().isBlank()) {
            a.setPushToken(r.pushToken());
        }
        a.setExpiresAt(expires);
        a.setUpdatedAt(now);
        a.setEndedAt(null);
        try {
            repo.saveAndFlush(a);
        } catch (DataIntegrityViolationException e) {
            // Es zamanli ayni kayit: zaten var, sorun degil (idempotans).
            log.debug("Canli etkinlik kaydi zaten var (user {})", userId);
        }
    }

    /** Cihazda biten/kapatilan etkinlik; olmayan kayit sessizce basaridir. */
    @Transactional
    public void end(Long userId, String activityId, Instant now) {
        repo.findByUserIdAndActivityId(userId, activityId).ifPresent(a -> {
            a.setEndedAt(now);
            a.setPushToken(null);
            repo.save(a);
        });
    }

    /**
     * Etkinlik/sinav iptal ya da silinince o surece bagli etkin Canli Etkinlikleri APNs ile bitirir.
     * APNs yapilandirilmamissa yalniz kayitlar kapatilir (cihazdaki etkinlik kendi suresinde biter).
     * Cagirana istisna sizdirmaz.
     */
    @Transactional
    public int endForRef(LiveActivity.Kind kind, Long refId, Instant now) {
        try {
            List<LiveActivity> list = repo.activeForRef(kind, refId, now);
            for (LiveActivity a : list) {
                Map<String, Object> state = new LinkedHashMap<>();
                state.put("phase", "ended");
                state.put("target", now.getEpochSecond() - 978307200L); // Swift Date: 2001-01-01'den saniye
                state.put("label", "");
                state.put("detail", "");
                apns.end(a.getPushToken(), state);
                a.setEndedAt(now);
                a.setPushToken(null);
            }
            repo.saveAll(list);
            return list.size();
        } catch (RuntimeException e) {
            log.warn("Canli etkinlik sonlandirma basarisiz ({} {}): {}", kind, refId, e.toString());
            return 0;
        }
    }

    @Scheduled(cron = "0 17 * * * *", zone = "Europe/Istanbul")
    @Transactional
    public void cleanup() {
        try {
            int n = repo.deleteOld(Instant.now().minus(Duration.ofDays(1)));
            if (n > 0) {
                log.info("Canli etkinlik temizligi: {} kayit silindi", n);
            }
        } catch (RuntimeException e) {
            log.warn("Canli etkinlik temizligi basarisiz: {}", e.toString());
        }
    }

    /** Kullanicinin kendi sureci degilse hata; donus: bitis ani (bilinmiyorsa null). */
    private Instant refEnd(Long userId, LiveActivity.Kind kind, Long refId) {
        if (kind == LiveActivity.Kind.EVENT) {
            boolean going = rsvps.findByEventIdAndUserId(refId, userId)
                    .map(x -> x.getStatus() == EventRsvp.Status.GOING).orElse(false);
            UserEvent ev = going ? events.findById(refId).orElse(null) : null;
            if (ev == null || ev.getStatus() != UserEvent.Status.ACTIVE) {
                throw invalidRef();
            }
            return ev.getEndsAt() != null ? ev.getEndsAt()
                    : ev.getStartsAt() == null ? null : ev.getStartsAt().plus(Duration.ofHours(3));
        }
        List<Timestamp> rows = jdbc.queryForList(
                "SELECT COALESCE(ends_at, starts_at + INTERVAL '3 hours') FROM tt_exam WHERE id = ? AND user_id = ?",
                Timestamp.class, refId, userId);
        if (rows.isEmpty() || rows.get(0) == null) {
            throw invalidRef();
        }
        return rows.get(0).toInstant();
    }

    private static ApiException invalidRef() {
        return new ApiException(HttpStatus.NOT_FOUND, "LIVE_ACTIVITY_REF_INVALID",
                "Canlı etkinlik başlatılamadı: kayıt bulunamadı ya da süresi geçti.");
    }

    private static Instant min(Instant a, Instant b) {
        return a.isBefore(b) ? a : b;
    }
}
