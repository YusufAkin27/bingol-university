package edu.bingol.backend.admin;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.mail.MailOutboxRepository;
import edu.bingol.backend.mail.MailStatus;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.health.contributor.Health;
import org.springframework.boot.health.contributor.HealthIndicator;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Operasyon paneli uclari (yalniz ADMIN: /api/admin/** SecurityConfig'te ADMIN). Panel prod'da
 * /actuator/health ayrintisina ulasamadigi icin bilesen durumlarini buradan okur. POST uclari
 * AuditInterceptor ile denetim kaydina yazilir.
 */
@RestController
@RequestMapping("/api/admin/ops")
public class AdminOpsController {

    private static final Pattern BACKUP_METRIC =
            Pattern.compile("^backup_last_success_timestamp_seconds\\s+([0-9.eE+]+)\\s*$", Pattern.MULTILINE);

    private final Map<String, HealthIndicator> indicators;
    private final MailOutboxRepository outbox;
    private final RateLimiter limiter;
    private final Path backupFile;
    private final long backupMaxAgeHours;

    public AdminOpsController(Map<String, HealthIndicator> indicators, MailOutboxRepository outbox, RateLimiter limiter,
                              @Value("${app.ops.backup-status-file:/var/backups/last_success}") String backupFile,
                              @Value("${app.ops.backup-max-age-hours:36}") long backupMaxAgeHours) {
        this.indicators = indicators;
        this.outbox = outbox;
        this.limiter = limiter;
        this.backupFile = Path.of(backupFile);
        this.backupMaxAgeHours = backupMaxAgeHours;
    }

    public record ComponentStatus(String status, Map<String, Object> details) {}

    public record OpsHealth(String status, Map<String, ComponentStatus> components) {}

    public record MailStats(long pending, long sending, long dead, long sentLast24h, Long oldestPendingAgeSeconds) {}

    public record Requeued(int requeued, long skipped) {}

    public record BackupStatus(String status, Instant lastSuccessAt, Instant lastAttemptAt, Long sizeBytes,
                               String message) {}

    @GetMapping("/health")
    public OpsHealth health() {
        limiter.check("admin:ops:" + CurrentUser.id(), 60, Duration.ofMinutes(1));
        Map<String, ComponentStatus> out = new LinkedHashMap<>();
        String overall = "UP";
        for (Map.Entry<String, HealthIndicator> e : indicators.entrySet()) {
            String code;
            Map<String, Object> details;
            try {
                Health h = e.getValue().health();
                code = h.getStatus().getCode();
                details = new LinkedHashMap<>(h.getDetails());
            } catch (RuntimeException ex) {
                code = "DOWN";
                details = Map.of();
            }
            out.put(componentName(e.getKey()), new ComponentStatus(code, details));
            overall = worse(overall, code);
        }
        return new OpsHealth(overall, out);
    }

    @GetMapping("/mail-outbox/stats")
    public MailStats mailStats() {
        limiter.check("admin:ops:" + CurrentUser.id(), 60, Duration.ofMinutes(1));
        Instant now = Instant.now();
        Instant oldest = outbox.oldestPendingCreatedAt();
        return new MailStats(
                outbox.countByStatus(MailStatus.PENDING) + outbox.countByStatus(MailStatus.FAILED),
                0,
                outbox.countByStatus(MailStatus.DEAD),
                outbox.countByStatusAndSentAtAfter(MailStatus.SENT, now.minus(Duration.ofHours(24))),
                oldest == null ? null : Math.max(0, Duration.between(oldest, now).getSeconds()));
    }

    @PostMapping("/mail-outbox/retry-dead")
    public Requeued retryDead() {
        limiter.check("admin:ops:retry:" + CurrentUser.id(), 10, Duration.ofMinutes(10));
        // Icerigi silinmis / suresi dolmus kod postalari yeniden alinmaz; sayilari acikca doner (skipped).
        Instant now = Instant.now();
        long dead = outbox.countByStatus(MailStatus.DEAD);
        int requeued = outbox.requeueDead(now, now.minus(Duration.ofMinutes(10)));
        return new Requeued(requeued, Math.max(0, dead - requeued));
    }

    /**
     * Yedekleme durumu: BE2'nin yazdigi durum dosyasi. Icinde {@code backup_last_success_timestamp_seconds <sn>}
     * satiri varsa o zaman, yoksa dosyanin degistirilme zamani son basari sayilir. Dosya yoksa UNKNOWN.
     */
    @GetMapping("/backup-status")
    public BackupStatus backupStatus() {
        limiter.check("admin:ops:" + CurrentUser.id(), 60, Duration.ofMinutes(1));
        return readBackup(backupFile, backupMaxAgeHours, Instant.now());
    }

    static BackupStatus readBackup(Path file, long maxAgeHours, Instant now) {
        try {
            if (!Files.isRegularFile(file)) {
                return new BackupStatus("UNKNOWN", null, null, null, null);
            }
            Instant last = Files.getLastModifiedTime(file).toInstant();
            long size = Files.size(file);
            if (size <= 64 * 1024) {
                Matcher m = BACKUP_METRIC.matcher(Files.readString(file, StandardCharsets.UTF_8));
                if (m.find()) {
                    last = Instant.ofEpochSecond((long) Double.parseDouble(m.group(1)));
                }
            }
            boolean fresh = Duration.between(last, now).toHours() < maxAgeHours;
            return new BackupStatus(fresh ? "OK" : "FAILED", last, last, null,
                    fresh ? null : "Son basarili yedek " + maxAgeHours + " saatten eski");
        } catch (IOException | RuntimeException e) {
            return new BackupStatus("UNKNOWN", null, null, null, "Durum dosyasi okunamadi");
        }
    }

    /** "dbHealthIndicator" / "redisHealthContributor" -> "db" / "redis"; "mailQueue" aynen kalir. */
    static String componentName(String beanName) {
        return beanName.replaceAll("(HealthIndicator|HealthContributor)$", "");
    }

    private static String worse(String a, String b) {
        return rank(b) > rank(a) ? b : a;
    }

    private static int rank(String code) {
        return switch (code) {
            case "DOWN", "OUT_OF_SERVICE" -> 3;
            case "WARN" -> 2;
            case "UNKNOWN" -> 1;
            default -> 0;
        };
    }
}
