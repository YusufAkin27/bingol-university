package edu.bingol.backend.analytics;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.core.namedparam.SqlParameterSource;
import org.springframework.stereotype.Repository;

/** Kullanim takibi tablolari (activity_daily, analytics_event, app_user.last_seen_at). Yalnizca parametreli SQL. */
@Repository
public class ActivityRepository {

    /** Disa aktarimda kullanicinin kendi olaylari icin ust sinir. */
    private static final int EXPORT_EVENT_LIMIT = 5000;

    private final NamedParameterJdbcTemplate jdbc;

    public ActivityRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public void touchLastSeen(Long userId) {
        jdbc.update("UPDATE app_user SET last_seen_at = now() WHERE id = :id", Map.of("id", userId));
    }

    /** Gunun ilk kaydi: satir varsa dokunmaz (acilis sayaci olaylardan artar). */
    public void markActive(Long userId, LocalDate day) {
        jdbc.update("INSERT INTO activity_daily (user_id, day, opens) VALUES (:uid, :day, 1) "
                + "ON CONFLICT (user_id, day) DO NOTHING", new MapSqlParameterSource("uid", userId).addValue("day", day));
    }

    /** `app_open` olaylari: gunluk acilis sayacini artirir (satir yoksa olusturur). */
    public void addOpens(Long userId, LocalDate day, int n) {
        jdbc.update("INSERT INTO activity_daily (user_id, day, opens) VALUES (:uid, :day, :n) "
                + "ON CONFLICT (user_id, day) DO UPDATE SET opens = activity_daily.opens + :n",
                new MapSqlParameterSource("uid", userId).addValue("day", day).addValue("n", n));
    }

    /** Dogrulanmis olaylari tek toplu yazimla ekler. */
    public void insertEvents(Long userId, List<AnalyticsService.ValidEvent> events) {
        SqlParameterSource[] batch = events.stream().map(e -> new MapSqlParameterSource()
                .addValue("uid", userId).addValue("name", e.name()).addValue("screen", e.screen())
                .addValue("props", e.propsJson()).addValue("at", e.at())).toArray(SqlParameterSource[]::new);
        jdbc.batchUpdate("INSERT INTO analytics_event (user_id, name, screen, props, created_at) "
                + "VALUES (:uid, :name, :screen, CAST(:props AS jsonb), :at)", batch);
    }

    /** Saklama suresi dolan olaylari parca parca siler (uzun kilit olusmasin). Silinen toplam sayiyi doner. */
    public int deleteEventsOlderThan(OffsetDateTime cutoff, int batchSize) {
        int total = 0;
        int n;
        do {
            n = jdbc.update("DELETE FROM analytics_event WHERE id IN "
                    + "(SELECT id FROM analytics_event WHERE created_at < :cutoff ORDER BY id LIMIT :lim)",
                    new MapSqlParameterSource("cutoff", cutoff).addValue("lim", batchSize));
            total += n;
        } while (n >= batchSize);
        return total;
    }

    /** Hesap silinirken kullanim izleri de silinir (KVKK). */
    public void purgeUser(Long userId) {
        Map<String, Object> p = Map.of("uid", userId);
        jdbc.update("DELETE FROM analytics_event WHERE user_id = :uid", p);
        jdbc.update("DELETE FROM activity_daily WHERE user_id = :uid", p);
    }

    // --- disa aktarim / kullanici detayi ---

    public record DayOpens(String day, int opens) {}

    /** En yeni gun once. */
    public List<DayOpens> recentDays(Long userId, int limit) {
        return jdbc.query("SELECT day, opens FROM activity_daily WHERE user_id = :uid ORDER BY day DESC LIMIT :lim",
                Map.of("uid", userId, "lim", limit),
                (rs, i) -> new DayOpens(rs.getObject("day", LocalDate.class).toString(), rs.getInt("opens")));
    }

    public record EventRow(String name, String screen, String props, String at) {}

    public List<EventRow> eventsOf(Long userId) {
        return jdbc.query("SELECT name, screen, CAST(props AS text) AS props, created_at FROM analytics_event "
                + "WHERE user_id = :uid ORDER BY id DESC LIMIT :lim", Map.of("uid", userId, "lim", EXPORT_EVENT_LIMIT),
                (rs, i) -> new EventRow(rs.getString("name"), rs.getString("screen"), rs.getString("props"),
                        rs.getObject("created_at", OffsetDateTime.class).toInstant().toString()));
    }
}
