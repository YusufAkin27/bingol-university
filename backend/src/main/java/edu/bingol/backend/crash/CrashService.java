package edu.bingol.backend.crash;

import edu.bingol.backend.crash.CrashDtos.ReportRequest;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Locale;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Anonim cokme raporu alimi: sunucuda ikinci kez maskeler, imzaya gore {@code crash_group}'a toplar, olay ekler
 * (grup basina son {@code app.crash.max-events-per-group} olay), surum dagilimini gunceller, cozulmus grup yeni
 * surumde tekrarlarsa yeniden acar. Yeni/yeniden acilan grup yoneticiye ozet bildirim icin sayaca yazilir
 * ({@link CrashAlertService}); istek yolunda bildirim gonderilmez. PostgreSQL'e ozel SQL (ON CONFLICT, FOR UPDATE):
 * H2 testlerinde degil, duman betigiyle (scripts/smoke-crash-reports.sh) dogrulanir.
 */
@Service
public class CrashService {

    private static final Logger log = LoggerFactory.getLogger(CrashService.class);

    private final NamedParameterJdbcTemplate jdbc;
    private final StringRedisTemplate redis;
    private final Clock clock;
    private final int maxEvents;

    public CrashService(NamedParameterJdbcTemplate jdbc, StringRedisTemplate redis, Clock clock,
                        @Value("${app.crash.max-events-per-group:50}") int maxEvents) {
        this.jdbc = jdbc;
        this.redis = redis;
        this.clock = clock;
        this.maxEvents = Math.max(5, Math.min(maxEvents, 500));
    }

    /** Sonuc: grup kimligi ve (yeni acildi | yeniden acildi) bilgisi. */
    public record Outcome(long groupId, boolean created, boolean reopened) {
    }

    @Transactional
    public Outcome record(ReportRequest r) {
        Instant now = clock.instant();
        String errorType = CrashScrubber.text(r.errorType(), 160);
        if (errorType == null) {
            errorType = "Unknown";
        }
        String stack = CrashScrubber.stack(r.stackTrace());
        String message = CrashScrubber.text(r.message(), 300);
        String platform = platform(r.platform());
        String version = r.appVersion().strip();
        String signature = CrashScrubber.signature(errorType, stack);
        Instant occurred = occurredAt(r.occurredAt(), now);

        MapSqlParameterSource gp = new MapSqlParameterSource()
                .addValue("sig", signature).addValue("type", errorType).addValue("msg", message)
                .addValue("top", CrashScrubber.topFrame(stack)).addValue("v", version)
                .addValue("now", Timestamp.from(now));
        int inserted = jdbc.update("INSERT INTO crash_group (signature, error_type, message_sample, top_frame, "
                + "first_seen_at, last_seen_at, first_version, last_version) "
                + "VALUES (:sig, :type, :msg, :top, :now, :now, :v, :v) ON CONFLICT (signature) DO NOTHING", gp);
        boolean created = inserted == 1;

        Map<String, Object> g = jdbc.queryForMap("SELECT id, status, last_version, fixed_in_version, "
                + "resolved_at_version FROM crash_group WHERE signature = :sig FOR UPDATE", gp);
        long groupId = ((Number) g.get("id")).longValue();
        String status = (String) g.get("status");
        String lastVersion = (String) g.get("last_version");
        boolean reopened = !created && "RESOLVED".equals(status)
                && shouldReopen(version, (String) g.get("fixed_in_version"), (String) g.get("resolved_at_version"));

        MapSqlParameterSource up = new MapSqlParameterSource()
                .addValue("id", groupId).addValue("now", Timestamp.from(now))
                .addValue("lastV", lastVersion == null || CrashScrubber.compareVersions(version, lastVersion) >= 0
                        ? version : lastVersion)
                .addValue("msg", message).addValue("reopen", reopened);
        jdbc.update("UPDATE crash_group SET event_count = event_count + 1, last_seen_at = :now, "
                + "last_version = :lastV, message_sample = COALESCE(message_sample, :msg), "
                + "status = CASE WHEN :reopen THEN 'NEW' ELSE status END, "
                + "reopen_count = reopen_count + CASE WHEN :reopen THEN 1 ELSE 0 END, "
                + "status_by = CASE WHEN :reopen THEN 'system' ELSE status_by END, "
                + "status_at = CASE WHEN :reopen THEN :now ELSE status_at END, "
                + "status_reason = CASE WHEN :reopen THEN NULL ELSE status_reason END, "
                + "fixed_in_version = CASE WHEN :reopen THEN NULL ELSE fixed_in_version END, "
                + "resolved_at_version = CASE WHEN :reopen THEN NULL ELSE resolved_at_version END "
                + "WHERE id = :id", up);

        jdbc.update("INSERT INTO crash_event (group_id, app_version, platform, os_version, device_model, screen, "
                        + "fatal, message, stack, occurred_at, received_at) "
                        + "VALUES (:g, :v, :p, :os, :model, :screen, :fatal, :msg, :stack, :occ, :now)",
                new MapSqlParameterSource().addValue("g", groupId).addValue("v", version).addValue("p", platform)
                        .addValue("os", CrashScrubber.text(r.osVersion(), 64))
                        .addValue("model", CrashScrubber.text(r.deviceModel(), 64))
                        .addValue("screen", CrashScrubber.text(r.screen(), 80))
                        .addValue("fatal", Boolean.TRUE.equals(r.fatal())).addValue("msg", message)
                        .addValue("stack", stack).addValue("occ", Timestamp.from(occurred))
                        .addValue("now", Timestamp.from(now)));
        jdbc.update("INSERT INTO crash_group_version (group_id, app_version, platform, cnt, last_seen_at) "
                        + "VALUES (:g, :v, :p, 1, :now) ON CONFLICT (group_id, app_version, platform) "
                        + "DO UPDATE SET cnt = crash_group_version.cnt + 1, last_seen_at = EXCLUDED.last_seen_at",
                new MapSqlParameterSource().addValue("g", groupId).addValue("v", version).addValue("p", platform)
                        .addValue("now", Timestamp.from(now)));
        trim(groupId);

        if (created || reopened) {
            markPending();
        }
        return new Outcome(groupId, created, reopened);
    }

    /** Grup basina yalniz son N olay kalir (id ARTAN: en yeni = en buyuk). */
    private void trim(long groupId) {
        jdbc.update("DELETE FROM crash_event WHERE group_id = :g AND id < "
                        + "(SELECT id FROM crash_event WHERE group_id = :g ORDER BY id DESC LIMIT 1 OFFSET :off)",
                Map.of("g", groupId, "off", maxEvents - 1));
    }

    /** Yoneticiye ozet bildirimi icin bekleyen yeni-grup sayaci (Redis yoksa sessizce atlanir). */
    private void markPending() {
        try {
            redis.opsForValue().increment(CrashAlertService.PENDING_KEY);
            redis.expire(CrashAlertService.PENDING_KEY, Duration.ofDays(2));
        } catch (RuntimeException e) {
            log.debug("Cokme bildirim sayaci yazilamadi: {}", e.toString());
        }
    }

    /**
     * Yeniden acma kurali: yonetici duzeltme surumu bildirdiyse o surum ve sonrasi; bildirmediyse cozuldugu andaki
     * son surumden YENI bir surum (eski surumdeki gec gelen raporlar grubu yeniden acmaz).
     */
    static boolean shouldReopen(String version, String fixedIn, String resolvedAt) {
        if (fixedIn != null && !fixedIn.isBlank()) {
            return CrashScrubber.compareVersions(version, fixedIn) >= 0;
        }
        return resolvedAt != null && CrashScrubber.compareVersions(version, resolvedAt) > 0;
    }

    static String platform(String p) {
        String s = p == null ? "" : p.strip().toUpperCase(Locale.ROOT);
        return switch (s) {
            case "ANDROID", "IOS" -> s;
            default -> "OTHER";
        };
    }

    /** Istemci saati: yoksa, gelecekte (>5 dk) ya da 30 gunden eskiyse alim zamani. */
    static Instant occurredAt(Instant client, Instant now) {
        if (client == null || client.isAfter(now.plus(Duration.ofMinutes(5)))
                || client.isBefore(now.minus(Duration.ofDays(30)))) {
            return now;
        }
        return client;
    }
}
