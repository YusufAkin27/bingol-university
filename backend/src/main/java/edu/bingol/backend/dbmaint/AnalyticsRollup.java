package edu.bingol.backend.dbmaint;

import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * analytics_event -> analytics_event_daily gunluk toplulastirma (Istanbul gunu). Her gece son toplulastirilan
 * gunden dunun sonuna kadar, gun gun ve idempotent (ON CONFLICT DO UPDATE) calisir. Ham olay silinmeden once calismali.
 */
@Component
public class AnalyticsRollup {

    private static final Logger log = LoggerFactory.getLogger(AnalyticsRollup.class);
    private static final ZoneId IST = ZoneId.of("Europe/Istanbul");
    /** Cok eski bosluk varsa en fazla bu kadar gun geriye gidilir (ham olay zaten ~45 gun tutulur). */
    private static final int MAX_CATCHUP_DAYS = 120;

    private final NamedParameterJdbcTemplate jdbc;
    private final Clock clock;

    public AnalyticsRollup(NamedParameterJdbcTemplate jdbc, Clock clock) {
        this.jdbc = jdbc;
        this.clock = clock;
    }

    /** @return toplulastirilan gun sayisi. */
    public int rollUpMissingDays() {
        LocalDate today = LocalDate.now(clock.withZone(IST));
        LocalDate last = jdbc.getJdbcTemplate().queryForObject("SELECT max(day) FROM analytics_event_daily", LocalDate.class);
        LocalDate from = last == null ? today.minusDays(MAX_CATCHUP_DAYS) : last.plusDays(1);
        if (from.isBefore(today.minusDays(MAX_CATCHUP_DAYS))) {
            from = today.minusDays(MAX_CATCHUP_DAYS);
        }
        int days = 0;
        for (LocalDate d = from; d.isBefore(today); d = d.plusDays(1)) {
            rollUp(d);
            days++;
        }
        if (days > 0) {
            log.info("Analitik toplulastirma: {} gun ({} .. {})", days, from, today.minusDays(1));
        }
        return days;
    }

    /** Tek Istanbul gununu yeniden hesaplar (tek ifade; gun basina en fazla birkac yuz satir yazar). */
    void rollUp(LocalDate day) {
        jdbc.update("INSERT INTO analytics_event_daily (day, name, screen, events, users) "
                + "SELECT :day, name, COALESCE(screen, ''), count(*), count(DISTINCT user_id) FROM analytics_event "
                + "WHERE created_at >= (CAST(:day AS timestamp) AT TIME ZONE 'Europe/Istanbul') "
                + "AND created_at < (CAST(:day AS timestamp) + interval '1 day') AT TIME ZONE 'Europe/Istanbul' "
                + "GROUP BY name, COALESCE(screen, '') "
                + "ON CONFLICT (day, name, screen) DO UPDATE SET events = EXCLUDED.events, users = EXCLUDED.users",
                Map.of("day", day));
    }
}
