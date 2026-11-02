package edu.bingol.backend.dbmaint;

import edu.bingol.backend.analytics.DateRange;
import edu.bingol.backend.analytics.usage.UsageBuckets;
import edu.bingol.backend.analytics.usage.UsageFeatures;
import edu.bingol.backend.analytics.usage.UsagePrivacy;
import edu.bingol.backend.config.SchedulerLock;
import java.time.Clock;
import java.time.Duration;
import java.time.LocalDate;
import java.util.Map;
import java.util.function.Function;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Kullanim istatistikleri toplulastirmasi (V1220): analytics_event -> analytics_usage_day / _screen_daily /
 * _screen_dur_daily / _action_daily / _flow_daily / _hour_daily / _segment_daily / _feature_snapshot. Istanbul gunu,
 * gun gun ve idempotent (gunun satirlari silinip yeniden yazilir, tek islemde). Hicbir cikti tabloda kullanici kimligi YOK.
 *
 * <p>Gunun ham olaylari BIR KEZ gecici tabloya (ON COMMIT DROP) alinir, tum ozetler ondan uretilir: ham tablo gun
 * basina tek taranir. Gece (dbmaint 03:00) tamamlanmamis gunler + son {@code recomputeDays} gun yeniden hesaplanir
 * (gec gelen olaylar); bugun icin kismi satirlar {@code app.analytics.usage-live-ms} (15 dk) araliginda tazelenir
 * (complete = false). Sorgular PostgreSQL'e ozeldir (H2'de calismaz): scripts/smoke-usage-stats.sh dogrular.
 */
@Component
public class UsageRollup {

    private static final Logger log = LoggerFactory.getLogger(UsageRollup.class);

    /** Ham olay saklamasi (45 gun) icinde kalmak icin en fazla bu kadar gun geriye gidilir. */
    static final int MAX_CATCHUP_DAYS = 44;
    /** Ozellik penceresi (gun): son gunde biten 30 gunluk tekil kullanici. */
    static final int FEATURE_WINDOW_DAYS = 30;
    /** Gunluk akis kenari ust siniri. */
    static final int MAX_EDGES_PER_DAY = 500;
    /** Yaygin bakim sorgulari icin 2 dk; ozellik penceresi taramasi 10 dk. */
    static final long TIMEOUT_MS = 120_000;
    static final long FEATURE_TIMEOUT_MS = 600_000;

    private static final String TABLES_BY_DAY = "analytics_usage_day,analytics_screen_daily,analytics_screen_dur_daily,"
            + "analytics_action_daily,analytics_flow_daily,analytics_hour_daily,analytics_segment_daily";

    private static final String DAY_FILTER = "created_at >= (CAST(:day AS timestamp) AT TIME ZONE 'Europe/Istanbul') "
            + "AND created_at < ((CAST(:day AS timestamp) + interval '1 day') AT TIME ZONE 'Europe/Istanbul')";

    /** Yasam dongusu ve hata telemetrisi (app_error) olaylari: kullanici eylemi sayilmaz. */
    private static final String LIFECYCLE = "'screen_view','app_open','app_background','app_error'";

    private final NamedParameterJdbcTemplate jdbc;
    private final Clock clock;
    private final SchedulerLock lock;
    private final int k;

    /** Gec gelen olaylar (alim 7 gune kadar geriye kabul eder) icin her gece yeniden hesaplanan son gun sayisi. */
    @Value("${app.analytics.usage-recompute-days:2}")
    private int recomputeDays = 2;

    @Value("${app.analytics.usage-live-ms:900000}")
    private long liveMs = 900_000;

    @Autowired
    public UsageRollup(NamedParameterJdbcTemplate jdbc, Clock clock, SchedulerLock lock,
                       @Value("${app.analytics.k-anonymity:10}") int k) {
        this.jdbc = jdbc;
        this.clock = clock;
        this.lock = lock;
        this.k = UsagePrivacy.effectiveK(k);
    }

    void setRecomputeDays(int days) {
        this.recomputeDays = days;
    }

    /** Gece bakimi: tamamlanmamis gunler + son N gun (bugun haric). @return toplulastirilan gun sayisi. */
    public int rollUpMissingDays() {
        LocalDate today = LocalDate.now(clock.withZone(DateRange.ISTANBUL));
        LocalDate lastComplete = jdbc.getJdbcTemplate()
                .queryForObject("SELECT max(day) FROM analytics_usage_day WHERE complete", LocalDate.class);
        return daysToRoll(today, lastComplete, recomputeDays).stream().mapToInt(d -> {
            rollUp(d, true, d.equals(today.minusDays(1)));
            return 1;
        }).sum();
    }

    /** Hangi gunler (bugun haric) yeniden hesaplanir; saf mantik, testlenir. */
    static java.util.List<LocalDate> daysToRoll(LocalDate today, LocalDate lastComplete, int recompute) {
        LocalDate from = lastComplete == null ? today.minusDays(MAX_CATCHUP_DAYS) : lastComplete.plusDays(1);
        int re = Math.max(0, Math.min(recompute, 30));
        if (re > 0 && from.isAfter(today.minusDays(re))) {
            from = today.minusDays(re);
        }
        if (from.isBefore(today.minusDays(MAX_CATCHUP_DAYS))) {
            from = today.minusDays(MAX_CATCHUP_DAYS);
        }
        java.util.List<LocalDate> out = new java.util.ArrayList<>();
        for (LocalDate d = from; d.isBefore(today); d = d.plusDays(1)) {
            out.add(d);
        }
        return out;
    }

    /** Bugunun kismi satirlari (15 dk'da bir). Kapali: {@code app.analytics.usage-live-ms=0}. */
    @Scheduled(fixedDelayString = "${app.analytics.usage-live-ms:900000}",
            initialDelayString = "${app.analytics.usage-live-initial-ms:120000}")
    public void refreshToday() {
        if (liveMs <= 0) {
            return;
        }
        lock.tryRunOrLocal("usage-live", Duration.ofMinutes(10), () -> {
            LocalDate today = LocalDate.now(clock.withZone(DateRange.ISTANBUL));
            try {
                rollUp(today, false, false);
            } catch (RuntimeException e) {
                log.warn("Kullanim ozeti (bugun) tazelenemedi: {}", e.toString());
                throw e;
            }
        });
    }

    /** Bugunun kismi ozetini hemen yeniden hesaplar (yonetici "simdi tazele" ve duman betigi). @return hesaplanan gun. */
    public LocalDate refreshTodayNow() {
        LocalDate today = LocalDate.now(clock.withZone(DateRange.ISTANBUL));
        rollUp(today, false, false);
        return today;
    }

    /** Tek Istanbul gununun tum ozetlerini yeniden yazar. */
    void rollUp(LocalDate day, boolean complete, boolean withFeatures) {
        LongSql.run(jdbc, TIMEOUT_MS, j -> {
            MapSqlParameterSource p = new MapSqlParameterSource().addValue("day", day).addValue("k", k)
                    .addValue("complete", complete);
            for (String t : TABLES_BY_DAY.split(",")) {
                j.update("DELETE FROM " + t + " WHERE day = :day", p);
            }
            j.update("DROP TABLE IF EXISTS us_day", p);
            j.update(TEMP_TABLE, p);
            for (String sql : new String[] {USAGE_DAY, SCREEN_DAILY, SCREEN_DUR, ACTION, FLOW, HOUR, SEGMENT}) {
                j.update(sql, p);
            }
            j.update("DROP TABLE IF EXISTS us_day", p);
            return null;
        });
        if (withFeatures) {
            featureSnapshot(day);
        }
        log.debug("Kullanim toplulastirma: {} (complete={})", day, complete);
    }

    private void featureSnapshot(LocalDate day) {
        MapSqlParameterSource p = new MapSqlParameterSource().addValue("day", day)
                .addValue("wstart", DateRange.dayStart(day.minusDays(FEATURE_WINDOW_DAYS - 1L)))
                .addValue("wend", DateRange.dayStart(day.plusDays(1)))
                .addValue("mfrom", day.minusDays(FEATURE_WINDOW_DAYS - 1L));
        Function<NamedParameterJdbcTemplate, Object> work = j -> {
            j.update("DELETE FROM analytics_feature_snapshot WHERE day = :day", p);
            long mau = j.queryForObject("SELECT count(DISTINCT user_id) FROM activity_daily "
                    + "WHERE day BETWEEN :mfrom AND :day", p, Long.class);
            p.addValue("mau", mau);
            j.update("INSERT INTO analytics_feature_snapshot (day, feature, users, mau) "
                    + "SELECT :day, f, count(DISTINCT user_id), :mau FROM ("
                    + "SELECT user_id, " + UsageFeatures.sqlCase("k") + " AS f FROM ("
                    + "SELECT user_id, CASE WHEN name = 'screen_view' THEN screen ELSE name END AS k "
                    + "FROM analytics_event WHERE created_at >= :wstart AND created_at < :wend "
                    + "AND name NOT IN ('app_open','app_background')) x) y WHERE f IS NOT NULL GROUP BY f", p);
            j.update("INSERT INTO analytics_feature_snapshot (day, feature, users, mau) "
                    + "SELECT :day, '" + UsageFeatures.ALL + "', count(DISTINCT user_id), :mau FROM analytics_event "
                    + "WHERE created_at >= :wstart AND created_at < :wend", p);
            return null;
        };
        LongSql.run(jdbc, FEATURE_TIMEOUT_MS, work);
    }

    // --- SQL (sabit metin; degerler baglanir) ---

    /**
     * Gunun ham olaylari tek taramada: gecerli ekran anahtari, onceki ekran (props.from), ekranda gecen sure (ms,
     * 0..30 dk), oturum suresi (props.dur sn, 0..24 sa), Istanbul saati. Sayisal donusum ic ice CASE'te: PostgreSQL
     * AND siralamasini garanti etmez, desen kontrolu CAST'ten once calismali.
     */
    private static final String TEMP_TABLE = "CREATE TEMP TABLE us_day ON COMMIT DROP AS SELECT user_id, name, "
            + "CASE WHEN screen ~ '^[a-z0-9_]{1,40}$' THEN screen END AS screen, "
            + "CASE WHEN name = 'screen_view' AND (props->>'from') ~ '^[a-z0-9_]{1,40}$' THEN props->>'from' END AS prev, "
            + "CASE WHEN name = 'screen_view' AND (props->>'ms') ~ '^[0-9]{1,9}$' THEN "
            + "(CASE WHEN CAST(props->>'ms' AS bigint) <= " + UsageBuckets.MAX_MS + " THEN CAST(props->>'ms' AS bigint) END) END AS ms, "
            + "CASE WHEN name = 'app_background' AND (props->>'dur') ~ '^[0-9]{1,6}$' THEN "
            + "(CASE WHEN CAST(props->>'dur' AS bigint) <= 86400 THEN CAST(props->>'dur' AS bigint) END) END AS dur_s, "
            + "CAST(EXTRACT(HOUR FROM created_at AT TIME ZONE 'Europe/Istanbul') AS smallint) AS hr, "
            + "platform, app_version FROM analytics_event WHERE " + DAY_FILTER;

    private static final String USAGE_DAY = "INSERT INTO analytics_usage_day "
            + "(day, dau, an_users, sessions, screen_views, sess_dur_sum, sess_dur_n, complete) "
            + "SELECT :day, (SELECT count(*) FROM activity_daily WHERE day = :day), "
            + "(SELECT count(DISTINCT user_id) FROM us_day), "
            + "count(*) FILTER (WHERE name = 'app_open'), "
            + "count(*) FILTER (WHERE name = 'screen_view' AND screen IS NOT NULL), "
            + "COALESCE(sum(dur_s), 0), count(dur_s), :complete FROM us_day";

    /** Goruntuleme/kullanici ekrana gore; sure ve cikis BIR SONRAKI screen_view'in `from` degerinden (onceki ekrana yazilir). */
    private static final String SCREEN_DAILY = "WITH v AS (SELECT screen AS s, count(*) AS views, "
            + "count(DISTINCT user_id) AS users FROM us_day WHERE name = 'screen_view' AND screen IS NOT NULL "
            + "GROUP BY screen), o AS (SELECT prev AS s, count(*) AS outgoing, COALESCE(sum(ms), 0) AS ms_sum, "
            + "count(ms) AS ms_n FROM us_day WHERE name = 'screen_view' AND screen IS NOT NULL AND prev IS NOT NULL "
            + "GROUP BY prev) "
            + "INSERT INTO analytics_screen_daily (day, screen, views, users, dur_sum_ms, dur_n, exits) "
            + "SELECT :day, v.s, v.views, v.users, COALESCE(o.ms_sum, 0), COALESCE(o.ms_n, 0), "
            + "GREATEST(v.views - COALESCE(o.outgoing, 0), 0) FROM v LEFT JOIN o ON o.s = v.s";

    private static final String SCREEN_DUR = "INSERT INTO analytics_screen_dur_daily (day, screen, bucket, n) "
            + "SELECT :day, prev, CAST(" + UsageBuckets.sqlCase("ms") + " AS smallint), count(*) FROM us_day "
            + "WHERE name = 'screen_view' AND screen IS NOT NULL AND prev IS NOT NULL AND ms IS NOT NULL "
            + "GROUP BY 2, 3";

    private static final String ACTION = "INSERT INTO analytics_action_daily (day, action, events, users) "
            + "SELECT :day, name, count(*), count(DISTINCT user_id) FROM us_day WHERE name NOT IN (" + LIFECYCLE + ") "
            + "GROUP BY name";

    private static final String FLOW = "INSERT INTO analytics_flow_daily (day, src, dst, n) "
            + "SELECT :day, prev, screen, count(*) FROM us_day WHERE name = 'screen_view' AND screen IS NOT NULL "
            + "AND prev IS NOT NULL AND prev <> screen GROUP BY prev, screen ORDER BY count(*) DESC, prev, screen "
            + "LIMIT " + MAX_EDGES_PER_DAY;

    private static final String HOUR = "INSERT INTO analytics_hour_daily (day, hour, sessions, views) "
            + "SELECT :day, hr, count(*) FILTER (WHERE name = 'app_open'), "
            + "count(*) FILTER (WHERE name = 'screen_view' AND screen IS NOT NULL) FROM us_day GROUP BY hr";

    /**
     * K-anonimlik YAZARKEN: platform disindaki kirilimlarda gunluk kullanicisi :k'dan az olan gruplar 'other' altinda
     * birlesir, 'other' de :k'dan azsa hic yazilmaz. Fakulte/bolum app_user'in GUNCEL degeridir.
     */
    private static final String SEGMENT = "INSERT INTO analytics_segment_daily (day, kind, seg, users, views) "
            + "WITH g AS ("
            + "SELECT 'platform' AS kind, COALESCE(platform, 'unknown') AS seg, count(DISTINCT user_id) AS users, "
            + "count(*) FILTER (WHERE name = 'screen_view' AND screen IS NOT NULL) AS views FROM us_day GROUP BY 2 "
            + "UNION ALL SELECT 'version', COALESCE(NULLIF(split_part(app_version, '+', 1), ''), 'unknown'), "
            + "count(DISTINCT user_id), count(*) FILTER (WHERE name = 'screen_view' AND screen IS NOT NULL) "
            + "FROM us_day GROUP BY 2 "
            + "UNION ALL SELECT 'faculty', COALESCE(NULLIF(left(btrim(u.faculty), 120), ''), 'unknown'), "
            + "count(DISTINCT t.user_id), count(*) FILTER (WHERE t.name = 'screen_view' AND t.screen IS NOT NULL) "
            + "FROM us_day t JOIN app_user u ON u.id = t.user_id GROUP BY 2 "
            + "UNION ALL SELECT 'department', COALESCE(NULLIF(left(btrim(u.department), 120), ''), 'unknown'), "
            + "count(DISTINCT t.user_id), count(*) FILTER (WHERE t.name = 'screen_view' AND t.screen IS NOT NULL) "
            + "FROM us_day t JOIN app_user u ON u.id = t.user_id GROUP BY 2), "
            + "m AS (SELECT kind, CASE WHEN kind = 'platform' OR users >= :k THEN seg ELSE 'other' END AS seg, "
            + "sum(users) AS users, sum(views) AS views FROM g GROUP BY 1, 2) "
            + "SELECT :day, kind, seg, CAST(users AS integer), CAST(views AS integer) FROM m "
            + "WHERE kind = 'platform' OR users >= :k";

    /** Testler ve belge icin: gun basina yazilan tablolar. */
    static Map<String, String> statements() {
        return Map.of("usage_day", USAGE_DAY, "screen_daily", SCREEN_DAILY, "screen_dur", SCREEN_DUR, "action", ACTION,
                "flow", FLOW, "hour", HOUR, "segment", SEGMENT, "temp", TEMP_TABLE);
    }
}
