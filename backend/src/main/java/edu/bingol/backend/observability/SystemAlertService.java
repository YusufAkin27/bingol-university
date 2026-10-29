package edu.bingol.backend.observability;

import edu.bingol.backend.config.SchedulerLock;
import edu.bingol.backend.mail.MailService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.UserRepository;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Yoneticiye proaktif uyari: genel durum CRIT'e GECTIGINDE (onceki dakika CRIT degildi) bir kez uyarir; en cok
 * {@code app.observability.alert-interval-minutes} (60) dakikada bir. Birincil kanal uygulama ici bildirimdir
 * (mail kuyrugu cokukse e-posta guvenilmez); {@code app.observability.alert-email} doluysa ayrica kuyruk DISINDA,
 * aninda e-posta denenir. Durum Redis'te tutulur (cok ornekte ortak); Redis yoksa uyari atlanir (zaten CRIT'tir).
 */
@Component
public class SystemAlertService {

    private static final Logger log = LoggerFactory.getLogger(SystemAlertService.class);
    static final String STATE_KEY = "obs:state";
    static final String THROTTLE_KEY = "obs:alert:sent";

    private final SystemOverviewService overview;
    private final ObservabilityProperties props;
    private final StringRedisTemplate redis;
    private final SchedulerLock lock;
    private final UserRepository users;
    private final NotificationService notifications;
    private final MailService mail;

    public SystemAlertService(SystemOverviewService overview, ObservabilityProperties props,
                              StringRedisTemplate redis, SchedulerLock lock, UserRepository users,
                              NotificationService notifications, MailService mail) {
        this.overview = overview;
        this.props = props;
        this.redis = redis;
        this.lock = lock;
        this.users = users;
        this.notifications = notifications;
        this.mail = mail;
    }

    /** Her dakika; ilk calisma 2 dk gecikmeli (zamanlayicilar ilk turlarini tamamlasin). */
    @Scheduled(fixedDelay = 60_000, initialDelay = 120_000)
    public void scheduled() {
        if (!props.alertEnabled()) {
            return;
        }
        lock.tryRun("obs-alert", Duration.ofSeconds(50), this::check);
    }

    /** Servis sozlesmesi: istisna sizdirmaz. */
    void check() {
        try {
            SystemOverviewService.Overview o = overview.evaluate(edu.bingol.backend.i18n.Lang.DEFAULT.locale());
            String previous = redis.opsForValue().get(STATE_KEY);
            // Depolama dolulugu kendi uyari isi (StorageAlertJob) ile bildirilir: burada ikilenmesin
            IndicatorStatus overall = overallExcept(o, StorageAlertJob.INDICATOR_KEY);
            redis.opsForValue().set(STATE_KEY, overall.name());
            if (!shouldAlert(previous, overall)) {
                return;
            }
            Boolean first = redis.opsForValue().setIfAbsent(THROTTLE_KEY, "1",
                    Duration.ofMinutes(Math.max(1, props.alertIntervalMinutes())));
            if (!Boolean.TRUE.equals(first)) {
                return; // son bir saatte zaten uyarildi
            }
            notifyAdmins(o);
        } catch (RuntimeException e) {
            log.warn("Sistem uyarisi kontrolu basarisiz: {}", e.toString());
        }
    }

    /** Genel durum, verilen gosterge anahtari haric. */
    static IndicatorStatus overallExcept(SystemOverviewService.Overview o, String excludedKey) {
        IndicatorStatus s = IndicatorStatus.UNKNOWN;
        for (Map.Entry<String, Indicator> e : o.indicators().entrySet()) {
            if (!e.getKey().equals(excludedKey)) {
                s = IndicatorStatus.worse(s, e.getValue().status());
            }
        }
        return s;
    }

    /** OK/WARN/UNKNOWN/ilk -> CRIT gecisinde true; CRIT'te kalmak tekrar uyari uretmez. */
    static boolean shouldAlert(String previous, IndicatorStatus now) {
        return now == IndicatorStatus.CRIT && !IndicatorStatus.CRIT.name().equals(previous);
    }

    private void notifyAdmins(SystemOverviewService.Overview o) {
        List<String> crit = o.critKeys().stream().filter(k -> !k.equals(StorageAlertJob.INDICATOR_KEY)).toList();
        String summary = String.join(", ", crit.stream().limit(6).toList());
        String count = String.valueOf(crit.size());
        for (UserRepository.UserLang admin : users.audienceAdmins()) {
            try {
                notifications.sendTemplated(admin.getId(), NotificationType.SYSTEM, "obs.alert",
                        Map.of("type", "SYSTEM_ALERT", "route", "/admin/system"), count, summary);
            } catch (RuntimeException e) {
                log.warn("Yonetici uyari bildirimi gonderilemedi: {}", e.toString());
            }
        }
        String to = props.alertEmail();
        if (to != null && !to.isBlank()) {
            String subject = "[BU Kampus] Sistem uyarisi (CRIT): " + count + " gosterge";
            String plain = "CRIT gostergeler: " + summary + "\nAyrinti: yonetim paneli > Sistem durumu.";
            boolean sent = mail.sendRich(to.trim(), subject, plain, "<p>" + escape(plain).replace("\n", "<br>") + "</p>", null);
            if (!sent) {
                log.warn("Sistem uyari e-postasi gonderilemedi ({})", LogMasking.email(to));
            }
        }
    }

    private static String escape(String s) {
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;");
    }
}
