package edu.bingol.backend.observability;

import edu.bingol.backend.config.SchedulerLock;
import edu.bingol.backend.dbmaint.admin.RetentionPurgeService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.UserRepository;
import java.time.Duration;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Depolama doluluk uyarisi: 15 dakikada bir (hafif sorgu; {@link JobMonitor} izler) {@link StorageUsageService} olcer.
 * Yuzde >= {@code storage-warn-percent} WARN, >= {@code storage-crit-percent} CRIT. Yoneticilere UYGULAMA ICI bildirim
 * gider (e-posta GONDERILMEZ: kota zayif); spam yok: yalniz durum KOTULESINCE (UNKNOWN/OK -> WARN/CRIT, WARN -> CRIT)
 * ve ayni seviyede kalinirsa gunde en cok bir tekrar. Durum Redis'te (cok ornekte ortak); Redis yoksa uyari atlanir.
 * Ayni turda nabzi kesilmis elle temizlik kayitlari INTERRUPTED isaretlenir.
 */
@Component
public class StorageAlertJob {

    private static final Logger log = LoggerFactory.getLogger(StorageAlertJob.class);
    /** {@link SystemOverviewService} gosterge anahtari. */
    public static final String INDICATOR_KEY = "storage";
    static final String STATE_KEY = "ds:storage:state";
    static final String REPEAT_KEY = "ds:storage:repeat";

    private final StorageUsageService usage;
    private final StringRedisTemplate redis;
    private final SchedulerLock lock;
    private final UserRepository users;
    private final NotificationService notifications;
    private final RetentionPurgeService purges;

    public StorageAlertJob(StorageUsageService usage, StringRedisTemplate redis, SchedulerLock lock,
                           UserRepository users, NotificationService notifications, RetentionPurgeService purges) {
        this.usage = usage;
        this.redis = redis;
        this.lock = lock;
        this.users = users;
        this.notifications = notifications;
        this.purges = purges;
    }

    @Scheduled(fixedDelayString = "${app.observability.storage-check-ms:900000}", initialDelay = 180_000)
    public void scheduled() {
        lock.tryRun("storage-alert", Duration.ofMinutes(10), this::check);
    }

    /** Servis sozlesmesi: istisna sizdirmaz. */
    void check() {
        try {
            purges.markStale();
            StorageUsageService.Report r = usage.fresh();
            IndicatorStatus now = r.status();
            String previous = redis.opsForValue().get(STATE_KEY);
            redis.opsForValue().set(STATE_KEY, now.name());
            if (now != IndicatorStatus.WARN && now != IndicatorStatus.CRIT) {
                redis.delete(REPEAT_KEY); // duzeldi: sonraki kotulesme hemen bildirilsin
                return;
            }
            boolean notify;
            if (worsened(previous, now)) {
                redis.opsForValue().set(REPEAT_KEY, "1", Duration.ofHours(24));
                notify = true;
            } else {
                notify = Boolean.TRUE.equals(redis.opsForValue().setIfAbsent(REPEAT_KEY, "1", Duration.ofHours(24)));
            }
            if (notify) {
                notifyAdmins(r);
            }
        } catch (RuntimeException e) {
            log.warn("Depolama uyarisi kontrolu basarisiz: {}", e.toString());
        }
    }

    /** UNKNOWN/OK/ilk -> WARN|CRIT ya da WARN -> CRIT. Ayni seviye ya da dusus kotulesme degildir. */
    static boolean worsened(String previous, IndicatorStatus now) {
        if (now != IndicatorStatus.WARN && now != IndicatorStatus.CRIT) {
            return false;
        }
        if (IndicatorStatus.CRIT.name().equals(previous)) {
            return false;
        }
        if (IndicatorStatus.WARN.name().equals(previous)) {
            return now == IndicatorStatus.CRIT;
        }
        return true;
    }

    private void notifyAdmins(StorageUsageService.Report r) {
        String pct = String.valueOf(r.worstPercent());
        String key = r.status() == IndicatorStatus.CRIT ? "obs.storageCrit" : "obs.storageWarn";
        for (UserRepository.UserLang admin : users.audienceAdmins()) {
            try {
                notifications.sendTemplated(admin.getId(), NotificationType.SYSTEM, key,
                        Map.of("type", "STORAGE_ALERT", "route", "/admin/data-retention"), pct);
            } catch (RuntimeException e) {
                log.warn("Depolama uyari bildirimi gonderilemedi: {}", e.toString());
            }
        }
    }
}
