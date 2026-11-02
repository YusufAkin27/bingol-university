package edu.bingol.backend.analytics.usage;

import edu.bingol.backend.analytics.DateRange;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * Kullanim raporu sorgulari (salt okunur). YALNIZ gunluk ozet tablolarini (analytics_*_daily, analytics_usage_day,
 * analytics_feature_snapshot) okur; ham analytics_event tablosuna dokunmaz. Tum degerler baglanir, SQL parcalari sabittir.
 */
@Repository
public class UsageReportRepository {

    public record DayRow(LocalDate day, long dau, long reportingUsers, long sessions, long views, long durSum,
                         long durN) {}

    public record ScreenRow(String screen, long views, long userDays, long durSumMs, long durN, long exits) {}

    public record ActionRow(String action, long events, long userDays) {}

    public record KeyDay(String key, LocalDate day, long n) {}

    public record Edge(String src, String dst, long n) {}

    public record HourRow(int dow, int hour, long sessions, long views) {}

    public record SegRow(String kind, String seg, long users, long views) {}

    public record FeatureRow(LocalDate day, String feature, long users, long mau) {}

    private final NamedParameterJdbcTemplate jdbc;

    public UsageReportRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private static MapSqlParameterSource range(DateRange r) {
        return new MapSqlParameterSource().addValue("from", r.from()).addValue("to", r.to());
    }

    public List<DayRow> days(DateRange r) {
        return jdbc.query("SELECT day, dau, an_users, sessions, screen_views, sess_dur_sum, sess_dur_n "
                + "FROM analytics_usage_day WHERE day BETWEEN :from AND :to ORDER BY day", range(r),
                (rs, i) -> new DayRow(rs.getObject("day", LocalDate.class), rs.getLong("dau"), rs.getLong("an_users"),
                        rs.getLong("sessions"), rs.getLong("screen_views"), rs.getLong("sess_dur_sum"),
                        rs.getLong("sess_dur_n")));
    }

    public List<ScreenRow> topScreens(DateRange r, int limit) {
        return jdbc.query("SELECT screen, sum(views) AS views, sum(users) AS user_days, sum(dur_sum_ms) AS dsum, "
                + "sum(dur_n) AS dn, sum(exits) AS exits FROM analytics_screen_daily "
                + "WHERE day BETWEEN :from AND :to GROUP BY screen ORDER BY views DESC, screen LIMIT :lim",
                range(r).addValue("lim", limit),
                (rs, i) -> new ScreenRow(rs.getString("screen"), rs.getLong("views"), rs.getLong("user_days"),
                        rs.getLong("dsum"), rs.getLong("dn"), rs.getLong("exits")));
    }

    public long totalViews(DateRange r) {
        Long n = jdbc.queryForObject("SELECT COALESCE(sum(views), 0) FROM analytics_screen_daily "
                + "WHERE day BETWEEN :from AND :to", range(r), Long.class);
        return n == null ? 0 : n;
    }

    public List<KeyDay> screenTrend(DateRange r, List<String> screens) {
        if (screens.isEmpty()) {
            return List.of();
        }
        return jdbc.query("SELECT screen, day, views FROM analytics_screen_daily "
                + "WHERE day BETWEEN :from AND :to AND screen IN (:s)", range(r).addValue("s", screens),
                (rs, i) -> new KeyDay(rs.getString("screen"), rs.getObject("day", LocalDate.class), rs.getLong("views")));
    }

    /** screen -> kova sayaclari (UsageBuckets.COUNT uzunlugunda). */
    public Map<String, long[]> durationBuckets(DateRange r, List<String> screens) {
        Map<String, long[]> out = new HashMap<>();
        if (screens.isEmpty()) {
            return out;
        }
        jdbc.query("SELECT screen, bucket, sum(n) AS n FROM analytics_screen_dur_daily "
                + "WHERE day BETWEEN :from AND :to AND screen IN (:s) GROUP BY screen, bucket",
                range(r).addValue("s", screens), rs -> {
                    int b = rs.getInt("bucket");
                    if (b >= 0 && b < UsageBuckets.COUNT) {
                        out.computeIfAbsent(rs.getString("screen"), k -> new long[UsageBuckets.COUNT])[b] = rs.getLong("n");
                    }
                });
        return out;
    }

    public List<ActionRow> topActions(DateRange r, int limit) {
        return jdbc.query("SELECT action, sum(events) AS events, sum(users) AS user_days FROM analytics_action_daily "
                + "WHERE day BETWEEN :from AND :to GROUP BY action ORDER BY events DESC, action LIMIT :lim",
                range(r).addValue("lim", limit),
                (rs, i) -> new ActionRow(rs.getString("action"), rs.getLong("events"), rs.getLong("user_days")));
    }

    public long totalActionEvents(DateRange r) {
        Long n = jdbc.queryForObject("SELECT COALESCE(sum(events), 0) FROM analytics_action_daily "
                + "WHERE day BETWEEN :from AND :to", range(r), Long.class);
        return n == null ? 0 : n;
    }

    public List<KeyDay> actionTrend(DateRange r, List<String> actions) {
        if (actions.isEmpty()) {
            return List.of();
        }
        return jdbc.query("SELECT action, day, events FROM analytics_action_daily "
                + "WHERE day BETWEEN :from AND :to AND action IN (:a)", range(r).addValue("a", actions),
                (rs, i) -> new KeyDay(rs.getString("action"), rs.getObject("day", LocalDate.class), rs.getLong("events")));
    }

    public List<Edge> topEdges(DateRange r, int limit) {
        return jdbc.query("SELECT src, dst, sum(n) AS n FROM analytics_flow_daily WHERE day BETWEEN :from AND :to "
                + "GROUP BY src, dst ORDER BY n DESC, src, dst LIMIT :lim", range(r).addValue("lim", limit),
                (rs, i) -> new Edge(rs.getString("src"), rs.getString("dst"), rs.getLong("n")));
    }

    public long totalTransitions(DateRange r) {
        Long n = jdbc.queryForObject("SELECT COALESCE(sum(n), 0) FROM analytics_flow_daily "
                + "WHERE day BETWEEN :from AND :to", range(r), Long.class);
        return n == null ? 0 : n;
    }

    public List<HourRow> hourly(DateRange r) {
        return jdbc.query("SELECT CAST(EXTRACT(ISODOW FROM day) AS integer) AS dow, hour, sum(sessions) AS sessions, "
                + "sum(views) AS views FROM analytics_hour_daily WHERE day BETWEEN :from AND :to GROUP BY 1, 2",
                range(r), (rs, i) -> new HourRow(rs.getInt("dow"), rs.getInt("hour"), rs.getLong("sessions"),
                        rs.getLong("views")));
    }

    public List<SegRow> segments(DateRange r) {
        return jdbc.query("SELECT kind, seg, sum(users) AS users, sum(views) AS views FROM analytics_segment_daily "
                + "WHERE day BETWEEN :from AND :to GROUP BY kind, seg", range(r),
                (rs, i) -> new SegRow(rs.getString("kind"), rs.getString("seg"), rs.getLong("users"),
                        rs.getLong("views")));
    }

    /** `to` tarihinde ya da oncesinde bulunan en yeni tamamlanmis gunun ozellik satirlari. */
    public List<FeatureRow> latestFeatures(LocalDate to) {
        List<FeatureRow> out = new ArrayList<>();
        jdbc.query("SELECT day, feature, users, mau FROM analytics_feature_snapshot WHERE day = "
                + "(SELECT max(day) FROM analytics_feature_snapshot WHERE day <= :to)",
                new MapSqlParameterSource("to", to), rs -> {
                    out.add(new FeatureRow(rs.getObject("day", LocalDate.class), rs.getString("feature"),
                            rs.getLong("users"), rs.getLong("mau")));
                });
        return out;
    }
}
