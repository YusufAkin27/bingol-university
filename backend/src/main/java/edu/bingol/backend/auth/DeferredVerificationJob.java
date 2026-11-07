package edu.bingol.backend.auth;

import edu.bingol.backend.auth.token.VerificationService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.SchedulerLock;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.mail.MailDailyQuota;
import edu.bingol.backend.observability.LogMasking;
import edu.bingol.backend.profile.ProfileService;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Kota asiminda ertelenmis dogrulama hesaplari icin otomatik tamamlama (QT-BE).
 *
 * <p>{@link #sendCodes}: kota bosalinca (yeni kota gunu / kalan pay) dogrulanmamis ertelenmis hesaplara, EN ESKI KAYIT
 * ONCE, dogrulama kodunu e-posta kuyruguna ekler. Kayit dogrulama postalari oncelikli kalir: is yalniz kimliksiz kayit
 * butcesinin KALAN payinin {@code max-share-of-remaining} (0.5) kadarini kullanir; saglayici kotasi tamamen doluysa hic
 * gondermez. Kullanici basina kota gunu basina en cok 1 posta ({@code verification_mailed_at}; el ile
 * {@code resend} ayri sinirdir). Cok ornekte {@link SchedulerLock} ile tek ornek; satir "sahiplenme" UPDATE'i ayrica
 * cift gonderimi onler.
 *
 * <p>{@link #purgeExpired}: {@code retention-days} (14) gunden eski, hala dogrulanmamis ertelenmis hesaplar HESAP SILME
 * (anonimlestirme) yolundan gecer ({@link ProfileService#anonymizeAccount} -> AccountDataPurger kapsami; KVKK).
 *
 * <p>Servis sozlesmesi: istisna sizdirmaz.
 */
@Component
public class DeferredVerificationJob {

    private static final Logger log = LoggerFactory.getLogger(DeferredVerificationJob.class);
    static final int PURGE_BATCH = 200;

    private final JdbcTemplate jdbc;
    private final VerificationService verification;
    private final ProfileService profiles;
    private final MailDailyQuota quota;
    private final SchedulerLock lock;
    private final Clock clock;
    private final boolean enabled;
    private final double maxShareOfRemaining;
    private final int maxPerRun;
    private final int retentionDays;

    @Autowired
    public DeferredVerificationJob(JdbcTemplate jdbc, VerificationService verification, ProfileService profiles,
                                   MailDailyQuota quota, SchedulerLock lock,
                                   @Value("${app.auth.deferred-verification.enabled:true}") boolean enabled,
                                   @Value("${app.auth.deferred-verification.max-share-of-remaining:0.5}") double maxShare,
                                   @Value("${app.auth.deferred-verification.max-per-run:200}") int maxPerRun,
                                   @Value("${app.auth.deferred-verification.retention-days:14}") int retentionDays) {
        this(jdbc, verification, profiles, quota, lock, Clock.systemUTC(), enabled, maxShare, maxPerRun, retentionDays);
    }

    DeferredVerificationJob(JdbcTemplate jdbc, VerificationService verification, ProfileService profiles,
                            MailDailyQuota quota, SchedulerLock lock, Clock clock, boolean enabled, double maxShare,
                            int maxPerRun, int retentionDays) {
        this.jdbc = jdbc;
        this.verification = verification;
        this.profiles = profiles;
        this.quota = quota;
        this.lock = lock;
        this.clock = clock;
        this.enabled = enabled;
        this.maxShareOfRemaining = Math.max(0, Math.min(1, maxShare));
        this.maxPerRun = Math.max(0, maxPerRun);
        this.retentionDays = Math.max(1, retentionDays);
    }

    @Scheduled(fixedDelayString = "${app.auth.deferred-verification.poll-ms:3600000}",
            initialDelayString = "${app.auth.deferred-verification.initial-delay-ms:300000}")
    public void scheduledSend() {
        try {
            if (lock == null) {
                sendCodes(clock.instant());
            } else {
                lock.tryRun("deferred-verification", Duration.ofMinutes(10), () -> sendCodes(clock.instant()));
            }
        } catch (RuntimeException e) {
            log.warn("Ertelenmis dogrulama kod gorevi basarisiz: {}", e.toString());
        }
    }

    @Scheduled(cron = "${app.auth.deferred-verification.purge-cron:0 20 3 * * *}", zone = "Europe/Istanbul")
    public void scheduledPurge() {
        try {
            if (lock == null) {
                purgeExpired(clock.instant());
            } else {
                lock.tryRun("deferred-verification-purge", Duration.ofMinutes(30), () -> purgeExpired(clock.instant()));
            }
        } catch (RuntimeException e) {
            log.warn("Ertelenmis dogrulama temizligi basarisiz: {}", e.toString());
        }
    }

    /** Bu calismada kuyruga alinabilecek kod sayisi (kota bilgisi yoksa yalniz maxPerRun). */
    int budget() {
        if (quota == null || !quota.enabled()) {
            return maxPerRun;
        }
        if (quota.exhausted()) {
            return 0;
        }
        long share = (long) Math.floor(quota.publicRemaining(MailDailyQuota.CodeKind.REGISTRATION) * maxShareOfRemaining);
        return (int) Math.max(0, Math.min(maxPerRun, share));
    }

    /** @return kuyruga alinan kod sayisi */
    public int sendCodes(Instant now) {
        if (!enabled) {
            return 0;
        }
        int sent = 0;
        try {
            int budget = budget();
            if (budget <= 0) {
                return 0;
            }
            Instant dayStart = quota != null ? quota.dayStart(now) : now.truncatedTo(ChronoUnit.DAYS);
            Timestamp day = Timestamp.from(dayStart);
            List<Row> rows = jdbc.query("SELECT id, email, language FROM app_user "
                    + "WHERE verification_deferred = TRUE AND email_verified = FALSE AND status = 'ACTIVE' "
                    + "AND (verification_mailed_at IS NULL OR verification_mailed_at < ?) "
                    + "ORDER BY created_at, id LIMIT " + budget,
                    (rs, n) -> new Row(rs.getLong("id"), rs.getString("email"), rs.getString("language")), day);
            for (Row r : rows) {
                if (sendOne(r, now, day)) {
                    sent++;
                }
            }
            if (sent > 0) {
                log.info("Ertelenmis dogrulama: {} kod e-postasi kuyruga alindi (butce {})", sent, budget);
            }
        } catch (RuntimeException e) {
            log.warn("Ertelenmis dogrulama kod gorevi hatasi: {}", e.toString());
        }
        return sent;
    }

    private boolean sendOne(Row r, Instant now, Timestamp day) {
        try {
            // Sahiplen: yalniz bugun henuz postalanmamis satir (cok ornekte de cift gonderim yok)
            int claimed = jdbc.update("UPDATE app_user SET verification_mailed_at = ? WHERE id = ? "
                    + "AND verification_deferred = TRUE AND email_verified = FALSE "
                    + "AND (verification_mailed_at IS NULL OR verification_mailed_at < ?)",
                    Timestamp.from(now), r.id(), day);
            if (claimed != 1) {
                return false;
            }
            try {
                verification.issue(r.email(), Lang.of(r.language()));
                return true;
            } catch (ApiException e) {
                // 180 sn bekleme: kullanici az once kendisi kod istedi; bugun zaten postalanmis sayilir
                log.debug("Ertelenmis dogrulama kodu atlandi ({}): {}", LogMasking.email(r.email()), e.code());
                return false;
            } catch (RuntimeException e) {
                jdbc.update("UPDATE app_user SET verification_mailed_at = NULL WHERE id = ?", r.id());
                log.warn("Ertelenmis dogrulama kodu kuyruga alinamadi ({}): {}", LogMasking.email(r.email()), e.toString());
                return false;
            }
        } catch (RuntimeException e) {
            log.warn("Ertelenmis dogrulama satiri islenemedi (user {}): {}", r.id(), e.toString());
            return false;
        }
    }

    /** @return anonimlestirilen hesap sayisi */
    public int purgeExpired(Instant now) {
        if (!enabled) {
            return 0;
        }
        int purged = 0;
        try {
            Timestamp before = Timestamp.from(now.minus(Duration.ofDays(retentionDays)));
            List<Long> ids = jdbc.query("SELECT id FROM app_user WHERE verification_deferred = TRUE "
                    + "AND email_verified = FALSE AND status <> 'DELETED' AND created_at < ? "
                    + "ORDER BY created_at, id LIMIT " + PURGE_BATCH, (rs, n) -> rs.getLong("id"), before);
            for (Long id : ids) {
                try {
                    profiles.anonymizeAccount(id);
                    purged++;
                } catch (RuntimeException e) {
                    log.warn("Ertelenmis dogrulanmamis hesap temizlenemedi (user {}): {}", id, e.toString());
                }
            }
            if (purged > 0) {
                log.info("Ertelenmis dogrulama: {} gunden eski {} dogrulanmamis hesap anonimlestirildi", retentionDays, purged);
            }
        } catch (RuntimeException e) {
            log.warn("Ertelenmis dogrulama temizligi hatasi: {}", e.toString());
        }
        return purged;
    }

    private record Row(long id, String email, String language) {
    }
}
