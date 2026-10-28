package edu.bingol.backend.admin.bulk;

import edu.bingol.backend.admin.bulk.BulkDtos.MenuSourceStatus;
import edu.bingol.backend.admin.bulk.BulkDtos.NewsSourceStatus;
import edu.bingol.backend.admin.bulk.BulkDtos.SourceName;
import edu.bingol.backend.admin.bulk.BulkDtos.SourcesStatus;
import edu.bingol.backend.admin.bulk.BulkDtos.SyncResult;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.menu.MenuSyncService;
import edu.bingol.backend.news.ContentType;
import edu.bingol.backend.news.NewsSyncService;
import edu.bingol.backend.status.StatusService;
import edu.bingol.backend.status.SyncStatus;
import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

/**
 * Kaynak (haber/duyuru/etkinlik + yemek listesi) durumunu mevcut {@link StatusService} ve tablo sayilarindan
 * toplulastirir; elle senkronizasyonu SAATTE 3 ile sinirlar (scraper kurali: kaynak siteye yalniz zamanlayici istek
 * atar, elle tetikleme istisnadir). Bu sinif kaynak siteye kendisi istek ATMAZ; mevcut senkron servisini cagirir.
 */
@Service
public class SourcesService {

    /** Kaynak basina saatlik elle senkron hakki (tum yoneticiler icin ortak). */
    public static final int SYNC_PER_HOUR = 3;
    private static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");
    private static final int MESSAGE_MAX = 200;

    private final StatusService status;
    private final JdbcTemplate jdbc;
    private final NewsSyncService newsSync;
    private final MenuSyncService menuSync;
    private final RateLimiter limiter;

    public SourcesService(StatusService status, JdbcTemplate jdbc, NewsSyncService newsSync, MenuSyncService menuSync,
                          RateLimiter limiter) {
        this.status = status;
        this.jdbc = jdbc;
        this.newsSync = newsSync;
        this.menuSync = menuSync;
        this.limiter = limiter;
    }

    public SourcesStatus status() {
        SyncStatus ns = find(StatusService.NEWS);
        SyncStatus ms = find(StatusService.MENU);
        Map<String, Long> byType = new LinkedHashMap<>();
        for (ContentType t : ContentType.values()) {
            byType.put(t.name(), count("SELECT COUNT(*) FROM news_item WHERE type = ?", t.name()));
        }
        long total = byType.values().stream().mapToLong(Long::longValue).sum();
        NewsSourceStatus news = new NewsSourceStatus(maint(ns), iso(ns == null ? null : ns.getLastSuccessAt()),
                iso(ns == null ? null : ns.getLastAttemptAt()), msg(ns),
                count("SELECT COUNT(*) FROM news_item WHERE fetched_at >= ?",
                        Timestamp.from(Instant.now().minus(Duration.ofDays(7)))),
                total, count("SELECT COUNT(*) FROM news_item WHERE hidden = TRUE"), byType);
        LocalDate today = LocalDate.now(ZONE);
        MenuSourceStatus menu = new MenuSourceStatus(maint(ms), iso(ms == null ? null : ms.getLastSuccessAt()),
                iso(ms == null ? null : ms.getLastAttemptAt()), msg(ms), count("SELECT COUNT(*) FROM menu_day"),
                count("SELECT COUNT(*) FROM menu_day WHERE menu_date >= ?", java.sql.Date.valueOf(today)),
                count("SELECT COUNT(*) FROM menu_day WHERE image_url IS NOT NULL"));
        return new SourcesStatus(news, menu, SYNC_PER_HOUR);
    }

    /** Elle senkron (saatte 3, kaynak basina ortak sayac; asilirsa 429 + Retry-After). Senkron hata firlatmaz. */
    public SyncResult sync(SourceName source) {
        limiter.check("sources-sync:" + source.name(), SYNC_PER_HOUR, Duration.ofHours(1));
        if (source == SourceName.NEWS) {
            Map<ContentType, Integer> r = newsSync.sync();
            Map<String, Integer> detail = new LinkedHashMap<>();
            int total = 0;
            if (r != null) {
                for (Map.Entry<ContentType, Integer> e : r.entrySet()) {
                    detail.put(e.getKey().name(), e.getValue());
                    total += e.getValue() == null ? 0 : e.getValue();
                }
            }
            return new SyncResult(source.name(), total, detail);
        }
        int changed = menuSync.sync();
        return new SyncResult(source.name(), changed, Map.of("changed", changed));
    }

    private SyncStatus find(String source) {
        return status.all().stream().filter(s -> source.equals(s.getSource())).findFirst().orElse(null);
    }

    private static boolean maint(SyncStatus s) {
        return s != null && s.getState() == SyncStatus.State.MAINTENANCE;
    }

    /** Son mesaj kisaltilir (ham hata ayrintisi panele tasmasin). */
    private static String msg(SyncStatus s) {
        if (s == null || s.getMessage() == null) {
            return null;
        }
        String m = s.getMessage().strip();
        return m.length() <= MESSAGE_MAX ? m : m.substring(0, MESSAGE_MAX) + "...";
    }

    private static String iso(Instant i) {
        return i == null ? null : i.toString();
    }

    private long count(String sql, Object... args) {
        Long n = jdbc.queryForObject(sql, Long.class, args);
        return n == null ? 0 : n;
    }
}
