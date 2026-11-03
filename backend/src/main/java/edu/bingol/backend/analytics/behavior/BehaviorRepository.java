package edu.bingol.backend.analytics.behavior;

import edu.bingol.backend.analytics.behavior.BehaviorDtos.ScreenStat;
import edu.bingol.backend.analytics.behavior.BehaviorDtos.TopScreen;
import edu.bingol.backend.analytics.behavior.BehaviorDtos.UserInfo;
import edu.bingol.backend.analytics.behavior.BehaviorMath.Ev;
import java.time.Instant;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * Davranis analizi okuma sorgulari (ham `analytics_event`, 45 gun). Yalniz parametreli SQL; sorgu metinleri
 * {@link BehaviorSql}'de, oturum tanimi {@link BehaviorMath} ile aynidir. Sinirsiz sorgu yok: her liste LIMIT'lidir.
 */
@Repository
public class BehaviorRepository {

    /** Tek kullanici detayinda okunan en fazla olay (en yeniler). */
    static final int USER_EVENT_CAP = 20_000;

    /** Ozet sorgusunun ham satiri (kind: total | day | bucket). */
    record OverviewRow(String kind, LocalDate day, int idx, long n, long users, double avgMs, double medMs,
                       double avgScreens, long bounces, long quicks) {}

    record ScreenPageRow(List<ScreenStat> items, long total) {}

    record FlowRow(String kind, String a, String b, long n, long m) {}

    record KindRow(String kind, long n, long users) {}

    record KindScreenRow(String kind, String screen, long n) {}

    record UserPageRow(long userId, String displayName, String email, String department, String grade, int sessions,
                       long totalMs, long avgMs, double bounceRate, int quickCount, Instant lastSeen) {}

    record UsersPageResult(List<UserPageRow> rows, long total) {}

    private final NamedParameterJdbcTemplate jdbc;

    public BehaviorRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    List<OverviewRow> overview(OffsetDateTime from, OffsetDateTime to) {
        MapSqlParameterSource p = BehaviorSql.params(from, to);
        long[] e = BehaviorMath.BUCKET_EDGES_MS;
        p.addValue("e1", e[0]).addValue("e2", e[1]).addValue("e3", e[2]).addValue("e4", e[3]);
        return jdbc.query(BehaviorSql.OVERVIEW, p, (rs, i) -> new OverviewRow(rs.getString("kind"),
                rs.getObject("day", LocalDate.class), rs.getInt("idx"), rs.getLong("n"), rs.getLong("users"),
                rs.getDouble("avg_ms"), rs.getDouble("med_ms"), rs.getDouble("avg_scr"), rs.getLong("bounces"),
                rs.getLong("quicks")));
    }

    /** orderCol/dir beyaz listeden (BehaviorService) gelir. */
    ScreenPageRow screens(OffsetDateTime from, OffsetDateTime to, String orderCol, String dir, int page, int size) {
        MapSqlParameterSource p = BehaviorSql.params(from, to).addValue("lim", size).addValue("off", (long) page * size);
        long[] total = {0};
        List<ScreenStat> items = jdbc.query(BehaviorSql.screens(orderCol, dir), p, (rs, i) -> {
            total[0] = rs.getLong("total");
            return new ScreenStat(rs.getString("screen"), rs.getInt("views"), rs.getInt("uniq"),
                    Math.round(rs.getDouble("avg_dwell")), Math.round(rs.getDouble("med_dwell")),
                    Math.round(rs.getDouble("p90_dwell")), rs.getDouble("exit_rate"), rs.getDouble("bounce_rate"),
                    rs.getDouble("share"));
        });
        return new ScreenPageRow(items, total[0]);
    }

    List<FlowRow> flows(OffsetDateTime from, OffsetDateTime to) {
        return jdbc.query(BehaviorSql.FLOWS, BehaviorSql.params(from, to), (rs, i) -> new FlowRow(rs.getString("kind"),
                rs.getString("a"), rs.getString("b"), rs.getLong("n"), rs.getLong("m")));
    }

    List<KindRow> actionKinds(OffsetDateTime from, OffsetDateTime to, Collection<String> kinds) {
        MapSqlParameterSource p = new MapSqlParameterSource("from", from).addValue("to", to).addValue("kinds", kinds);
        return jdbc.query(BehaviorSql.ACTION_KINDS, p,
                (rs, i) -> new KindRow(rs.getString("kind"), rs.getLong("n"), rs.getLong("users")));
    }

    List<KindScreenRow> actionScreens(OffsetDateTime from, OffsetDateTime to, Collection<String> kinds) {
        MapSqlParameterSource p = new MapSqlParameterSource("from", from).addValue("to", to).addValue("kinds", kinds);
        return jdbc.query(BehaviorSql.ACTION_SCREENS, p,
                (rs, i) -> new KindScreenRow(rs.getString("kind"), rs.getString("screen"), rs.getLong("n")));
    }

    /** where / orderCol / dir beyaz listeden; q (varsa) LIKE-kacirilmis desen. */
    UsersPageResult users(OffsetDateTime from, OffsetDateTime to, String where, String orderCol, String dir,
                          String likeQ, int page, int size) {
        MapSqlParameterSource p = BehaviorSql.params(from, to).addValue("lim", size).addValue("off", (long) page * size);
        if (likeQ != null) {
            p.addValue("q", likeQ);
        }
        long[] total = {0};
        List<UserPageRow> rows = jdbc.query(BehaviorSql.users(where, orderCol, dir), p, (rs, i) -> {
            total[0] = rs.getLong("total");
            OffsetDateTime last = rs.getObject("last_seen", OffsetDateTime.class);
            return new UserPageRow(rs.getLong("user_id"), rs.getString("display_name"), rs.getString("email"),
                    rs.getString("department"), rs.getString("grade"), rs.getInt("sessions"), rs.getLong("total_ms"),
                    Math.round(rs.getDouble("avg_ms")), rs.getDouble("bounce_rate"), rs.getInt("quick_count"),
                    last == null ? null : last.toInstant());
        });
        return new UsersPageResult(rows, total[0]);
    }

    /** userId -> ekran basina en cok sure gecirilen 3 ekran. */
    Map<Long, List<TopScreen>> topScreens(OffsetDateTime from, OffsetDateTime to, Collection<Long> userIds) {
        if (userIds.isEmpty()) {
            return Collections.emptyMap();
        }
        MapSqlParameterSource p = new MapSqlParameterSource("from", from).addValue("to", to).addValue("ids", userIds);
        Map<Long, List<TopScreen>> out = new HashMap<>();
        jdbc.query(BehaviorSql.USER_TOP_SCREENS, p, rs -> {
            out.computeIfAbsent(rs.getLong("user_id"), k -> new ArrayList<>())
                    .add(new TopScreen(rs.getString("screen"), rs.getLong("ms")));
        });
        return out;
    }

    Optional<UserInfo> userInfo(long id) {
        return jdbc.query("SELECT id, display_name, email, department, grade FROM app_user WHERE id = :id",
                new MapSqlParameterSource("id", id), (rs, i) -> new UserInfo(rs.getLong("id"),
                        rs.getString("display_name"), rs.getString("email"), rs.getString("department"),
                        rs.getString("grade"))).stream().findFirst();
    }

    /** Kullanicinin olaylari KRONOLOJIK (artan) sirada; en yeni USER_EVENT_CAP olayla sinirli. */
    List<Ev> userEvents(long userId, OffsetDateTime from, OffsetDateTime to) {
        MapSqlParameterSource p = new MapSqlParameterSource("uid", userId).addValue("from", from).addValue("to", to)
                .addValue("cap", USER_EVENT_CAP);
        List<Ev> rows = jdbc.query(BehaviorSql.USER_EVENTS, p, (rs, i) -> new Ev(rs.getLong("id"), rs.getString("name"),
                rs.getString("screen"), rs.getString("sid"), rs.getString("kind"), (Long) rs.getObject("dwell"),
                (Long) rs.getObject("dur"), (Integer) rs.getObject("scr"), rs.getString("reason"),
                rs.getObject("created_at", OffsetDateTime.class).toInstant()));
        List<Ev> asc = new ArrayList<>(rows);
        Collections.reverse(asc);
        return asc;
    }
}
