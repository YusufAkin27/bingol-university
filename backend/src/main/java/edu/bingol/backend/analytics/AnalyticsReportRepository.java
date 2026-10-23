package edu.bingol.backend.analytics;

import edu.bingol.backend.analytics.ReportDtos.ActiveUsers;
import edu.bingol.backend.analytics.ReportDtos.CommunityCounts;
import edu.bingol.backend.analytics.ReportDtos.DeviceCounts;
import edu.bingol.backend.analytics.ReportDtos.EventCounts;
import edu.bingol.backend.analytics.ReportDtos.FunnelStep;
import edu.bingol.backend.analytics.ReportDtos.KeyCount;
import edu.bingol.backend.analytics.ReportDtos.MessageCounts;
import edu.bingol.backend.analytics.ReportDtos.NewUsers;
import edu.bingol.backend.analytics.ReportDtos.Overview;
import edu.bingol.backend.analytics.ReportDtos.ScreenViews;
import edu.bingol.backend.analytics.ReportDtos.TopEvent;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * Raporlama sorgulari (salt okunur, yalnizca PostgreSQL). Tum degerler baglanir; SQL parcalari sabittir.
 * Gun sinirlari Europe/Istanbul'dur: araliklar `created_at >= :start AND created_at < :end` (UTC an'lari) ile
 * indeksten taranir, gunluk gruplama `created_at AT TIME ZONE 'Europe/Istanbul'` ile yapilir; bos gunler
 * generate_series ile 0 doldurulur. COUNT(DISTINCT) yalnizca sinirli araliklarda (7/30 gun, olay penceresi) kullanilir.
 */
@Repository
public class AnalyticsReportRepository {

    /** Gun + sayi. */
    public record DayCount(LocalDate day, long n) {}

    private static final String IST = "'Europe/Istanbul'";

    private final NamedParameterJdbcTemplate jdbc;

    public AnalyticsReportRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private static MapSqlParameterSource params(DateRange r) {
        return new MapSqlParameterSource()
                .addValue("from", r.from()).addValue("to", r.to())
                .addValue("start", r.startUtc()).addValue("end", r.endUtc())
                .addValue("span", r.days() - 1);
    }

    /**
     * Aralikta her gun icin (gun, sayi); `inner` sorgusu `day` (date) ve `n` (bigint) donmeli ve
     * :from/:to/:start/:end kullanabilir. Verisiz gunler 0.
     */
    private List<DayCount> series(DateRange r, String inner, MapSqlParameterSource extra) {
        MapSqlParameterSource p = params(r);
        p.addValues(extra.getValues());
        return jdbc.query("SELECT g.day AS day, COALESCE(c.n, 0) AS n FROM "
                + "(SELECT CAST(:from AS date) + gs AS day FROM generate_series(0, :span) gs) g "
                + "LEFT JOIN (" + inner + ") c ON c.day = g.day ORDER BY g.day", p,
                (rs, i) -> new DayCount(rs.getObject("day", LocalDate.class), rs.getLong("n")));
    }

    private List<DayCount> series(DateRange r, String inner) {
        return series(r, inner, new MapSqlParameterSource());
    }

    // --- genel bakis ---

    public Overview overview(LocalDate today) {
        MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("today", today)
                .addValue("wauFrom", today.minusDays(6))
                .addValue("mauFrom", today.minusDays(29))
                .addValue("start0", DateRange.dayStart(today))
                .addValue("start7", DateRange.dayStart(today.minusDays(6)))
                .addValue("start30", DateRange.dayStart(today.minusDays(29)));
        return jdbc.queryForObject("SELECT "
                + "(SELECT count(*) FROM app_user WHERE status <> 'DELETED') AS total_users, "
                + "(SELECT count(*) FROM app_user WHERE status <> 'DELETED' AND email_verified) AS verified_users, "
                + "(SELECT count(*) FROM app_user WHERE status = 'SUSPENDED') AS suspended_users, "
                + "(SELECT count(*) FROM app_user WHERE created_at >= :start0) AS new_today, "
                + "(SELECT count(*) FROM app_user WHERE created_at >= :start7) AS new_7, "
                + "(SELECT count(*) FROM app_user WHERE created_at >= :start30) AS new_30, "
                + "(SELECT count(*) FROM activity_daily WHERE day = CAST(:today AS date)) AS dau, "
                + "(SELECT count(DISTINCT user_id) FROM activity_daily WHERE day BETWEEN CAST(:wauFrom AS date) AND CAST(:today AS date)) AS wau, "
                + "(SELECT count(DISTINCT user_id) FROM activity_daily WHERE day BETWEEN CAST(:mauFrom AS date) AND CAST(:today AS date)) AS mau, "
                + "(SELECT count(*) FROM message) AS msg_total, "
                + "(SELECT count(*) FROM message WHERE created_at >= now() - interval '24 hours') AS msg_24h, "
                + "(SELECT count(*) FROM community WHERE status = 'ACTIVE') AS comm_active, "
                + "(SELECT count(*) FROM community WHERE status = 'PENDING_REVIEW') AS comm_pending, "
                + "(SELECT count(*) FROM user_event WHERE status = 'ACTIVE' AND starts_at > now()) AS ev_upcoming, "
                + "(SELECT count(*) FROM user_event WHERE status = 'PENDING_REVIEW') AS ev_pending, "
                + "(SELECT count(*) FROM report WHERE status = 'OPEN') AS open_reports, "
                + "(SELECT count(*) FROM support_ticket WHERE status = 'OPEN') AS open_tickets, "
                + "(SELECT count(*) FROM feedback WHERE status = 'NEW') AS new_feedback, "
                + "(SELECT count(*) FROM push_campaign WHERE status = 'SENT' AND finished_at >= now() - interval '30 days') AS push_30, "
                + "(SELECT count(*) FROM bookmark) AS bookmarks, "
                + "(SELECT count(*) FROM device WHERE platform = 'ANDROID') AS dev_android, "
                + "(SELECT count(*) FROM device WHERE platform = 'IOS') AS dev_ios, "
                + "(SELECT count(*) FROM device WHERE platform = 'WEB') AS dev_web", p, (rs, i) -> {
                    long dau = rs.getLong("dau");
                    long mau = rs.getLong("mau");
                    double stickiness = mau == 0 ? 0 : Math.round(dau * 10000.0 / mau) / 10000.0;
                    return new Overview(rs.getLong("total_users"), rs.getLong("verified_users"),
                            rs.getLong("suspended_users"),
                            new NewUsers(rs.getLong("new_today"), rs.getLong("new_7"), rs.getLong("new_30")),
                            new ActiveUsers(dau, rs.getLong("wau"), mau), stickiness,
                            new MessageCounts(rs.getLong("msg_total"), rs.getLong("msg_24h")),
                            new CommunityCounts(rs.getLong("comm_active"), rs.getLong("comm_pending")),
                            new EventCounts(rs.getLong("ev_upcoming"), rs.getLong("ev_pending")),
                            rs.getLong("open_reports"), rs.getLong("open_tickets"), rs.getLong("new_feedback"),
                            rs.getLong("push_30"), rs.getLong("bookmarks"),
                            new DeviceCounts(rs.getLong("dev_android"), rs.getLong("dev_ios"), rs.getLong("dev_web")));
                });
    }

    // --- zaman serileri ---

    public List<DayCount> registrationsPerDay(DateRange r) {
        return series(r, "SELECT CAST(created_at AT TIME ZONE " + IST + " AS date) AS day, count(*) AS n "
                + "FROM app_user WHERE created_at >= :start AND created_at < :end GROUP BY 1");
    }

    /** Aralik oncesindeki toplam kayit (kumulatif seri tabani). */
    public long registeredBefore(DateRange r) {
        Long n = jdbc.queryForObject("SELECT count(*) FROM app_user WHERE created_at < :start", params(r), Long.class);
        return n == null ? 0 : n;
    }

    public List<DayCount> dauPerDay(DateRange r) {
        return series(r, "SELECT day, count(*) AS n FROM activity_daily "
                + "WHERE day BETWEEN CAST(:from AS date) AND CAST(:to AS date) GROUP BY day");
    }

    /** [from, to] gun araliginda en az bir gun aktif olan benzersiz kullanici sayisi. */
    public long distinctActive(LocalDate from, LocalDate to) {
        Long n = jdbc.queryForObject("SELECT count(DISTINCT user_id) FROM activity_daily "
                        + "WHERE day BETWEEN CAST(:f AS date) AND CAST(:t AS date)",
                new MapSqlParameterSource("f", from).addValue("t", to), Long.class);
        return n == null ? 0 : n;
    }

    // --- dagilim ---

    /** Her boyut icin sabit SQL; kullanici girdisi SQL'e eklenmez. Anahtar bos (null) olabilir. */
    public enum Dimension {
        FACULTY("faculty", "SELECT faculty AS k, count(*) AS n FROM app_user WHERE status <> 'DELETED' GROUP BY faculty"),
        DEPARTMENT("department", "SELECT department AS k, count(*) AS n FROM app_user WHERE status <> 'DELETED' GROUP BY department"),
        CLASS_YEAR("classYear", "SELECT CAST(class_year AS varchar) AS k, count(*) AS n FROM app_user WHERE status <> 'DELETED' GROUP BY class_year"),
        LANGUAGE("language", "SELECT language AS k, count(*) AS n FROM app_user WHERE status <> 'DELETED' GROUP BY language"),
        ROLE("role", "SELECT role AS k, count(*) AS n FROM app_user WHERE status <> 'DELETED' GROUP BY role"),
        STATUS("status", "SELECT status AS k, count(*) AS n FROM app_user GROUP BY status"),
        PLATFORM("platform", "SELECT platform AS k, count(*) AS n FROM device GROUP BY platform");

        public final String param;
        final String sql;

        Dimension(String param, String sql) {
            this.param = param;
            this.sql = sql;
        }

        public static Dimension parse(String s) {
            for (Dimension d : values()) {
                if (d.param.equalsIgnoreCase(s == null ? "" : s.trim())) {
                    return d;
                }
            }
            return null;
        }
    }

    public List<KeyCount> breakdown(Dimension d) {
        return jdbc.query(d.sql + " ORDER BY n DESC, k", Map.of(),
                (rs, i) -> new KeyCount(rs.getString("k"), rs.getLong("n")));
    }

    // --- etkilesim ---

    public List<TopEvent> topEvents(DateRange r, int limit) {
        return jdbc.query("SELECT name, count(*) AS cnt, count(DISTINCT user_id) AS uniq FROM analytics_event "
                + "WHERE created_at >= :start AND created_at < :end GROUP BY name ORDER BY cnt DESC, name LIMIT :lim",
                params(r).addValue("lim", limit),
                (rs, i) -> new TopEvent(rs.getString("name"), rs.getLong("cnt"), rs.getLong("uniq")));
    }

    /** Ekran goruntulemeleri: `screen_view` olaylari, ekrana gore. */
    public List<ScreenViews> screenViews(DateRange r, int limit) {
        return jdbc.query("SELECT screen, count(*) AS views FROM analytics_event WHERE name = 'screen_view' "
                + "AND screen IS NOT NULL AND created_at >= :start AND created_at < :end "
                + "GROUP BY screen ORDER BY views DESC, screen LIMIT :lim", params(r).addValue("lim", limit),
                (rs, i) -> new ScreenViews(rs.getString("screen"), rs.getLong("views")));
    }

    public List<DayCount> messagesPerDay(DateRange r) {
        return series(r, "SELECT CAST(created_at AT TIME ZONE " + IST + " AS date) AS day, count(*) AS n FROM message "
                + "WHERE created_at >= :start AND created_at < :end AND hidden_at IS NULL GROUP BY 1");
    }

    public List<DayCount> postsPerDay(DateRange r) {
        return series(r, "SELECT CAST(created_at AT TIME ZONE " + IST + " AS date) AS day, count(*) AS n FROM community_post "
                + "WHERE created_at >= :start AND created_at < :end AND NOT deleted GROUP BY 1");
    }

    public List<DayCount> rsvpsPerDay(DateRange r) {
        return series(r, "SELECT CAST(created_at AT TIME ZONE " + IST + " AS date) AS day, count(*) AS n FROM event_rsvp "
                + "WHERE created_at >= :start AND created_at < :end GROUP BY 1");
    }

    public List<DayCount> searchesPerDay(DateRange r) {
        return series(r, "SELECT CAST(created_at AT TIME ZONE " + IST + " AS date) AS day, count(*) AS n FROM analytics_event "
                + "WHERE name = 'search' AND created_at >= :start AND created_at < :end GROUP BY 1");
    }

    /** Aralikta kayit olan kullanicilar icin adim sayilari (adimlar birbirinden bagimsiz sayilir). */
    public List<FunnelStep> funnel(DateRange r) {
        return jdbc.queryForObject("SELECT count(*) AS registered, "
                + "count(*) FILTER (WHERE u.email_verified) AS verified, "
                + "count(*) FILTER (WHERE u.department IS NOT NULL AND u.class_year IS NOT NULL) AS profile_completed, "
                + "count(*) FILTER (WHERE EXISTS (SELECT 1 FROM community_member m WHERE m.user_id = u.id AND m.status = 'ACTIVE')) AS joined, "
                + "count(*) FILTER (WHERE EXISTS (SELECT 1 FROM message ms WHERE ms.sender_id = u.id)) AS sent "
                + "FROM app_user u WHERE u.created_at >= :start AND u.created_at < :end AND u.status <> 'DELETED'",
                params(r), (rs, i) -> List.of(new FunnelStep("registered", rs.getLong("registered")),
                        new FunnelStep("verified", rs.getLong("verified")),
                        new FunnelStep("profileCompleted", rs.getLong("profile_completed")),
                        new FunnelStep("joinedCommunity", rs.getLong("joined")),
                        new FunnelStep("sentMessage", rs.getLong("sent"))));
    }

    // --- tutundurma ---

    /** Son 12 haftanin (Pazartesi baslangicli, Istanbul) kayit kohortlari ve D1/D7/D30 sayilari. */
    public record CohortRow(LocalDate weekStart, long size, long e1, long a1, long e7, long a7, long e30, long a30) {}

    public static LocalDate firstCohortWeek(LocalDate today) {
        return today.with(DayOfWeek.MONDAY).minusWeeks(11);
    }

    public List<CohortRow> cohorts(LocalDate today) {
        LocalDate first = firstCohortWeek(today);
        MapSqlParameterSource p = new MapSqlParameterSource().addValue("first", first)
                .addValue("start", DateRange.dayStart(first)).addValue("today", today);
        return jdbc.query("WITH weeks AS (SELECT CAST(:first AS date) + (7 * w) AS week_start FROM generate_series(0, 11) w), "
                + "c AS (SELECT u.id, CAST(u.created_at AT TIME ZONE " + IST + " AS date) AS reg_day FROM app_user u "
                + "WHERE u.created_at >= :start AND u.email_verified AND u.status <> 'DELETED'), "
                + "cw AS (SELECT id, reg_day, reg_day - (CAST(EXTRACT(ISODOW FROM reg_day) AS int) - 1) AS week_start FROM c) "
                + "SELECT w.week_start AS week_start, count(cw.id) AS size, "
                + "count(cw.id) FILTER (WHERE cw.reg_day + 1 <= CAST(:today AS date)) AS e1, "
                + "count(cw.id) FILTER (WHERE EXISTS (SELECT 1 FROM activity_daily a WHERE a.user_id = cw.id AND a.day = cw.reg_day + 1)) AS a1, "
                + "count(cw.id) FILTER (WHERE cw.reg_day + 7 <= CAST(:today AS date)) AS e7, "
                + "count(cw.id) FILTER (WHERE EXISTS (SELECT 1 FROM activity_daily a WHERE a.user_id = cw.id AND a.day = cw.reg_day + 7)) AS a7, "
                + "count(cw.id) FILTER (WHERE cw.reg_day + 30 <= CAST(:today AS date)) AS e30, "
                + "count(cw.id) FILTER (WHERE EXISTS (SELECT 1 FROM activity_daily a WHERE a.user_id = cw.id AND a.day = cw.reg_day + 30)) AS a30 "
                + "FROM weeks w LEFT JOIN cw ON cw.week_start = w.week_start GROUP BY w.week_start ORDER BY w.week_start", p,
                (rs, i) -> new CohortRow(rs.getObject("week_start", LocalDate.class), rs.getLong("size"),
                        rs.getLong("e1"), rs.getLong("a1"), rs.getLong("e7"), rs.getLong("a7"),
                        rs.getLong("e30"), rs.getLong("a30")));
    }

    // --- destek ---

    public Map<String, Long> ticketCounts() {
        Map<String, Long> out = new java.util.HashMap<>();
        jdbc.query("SELECT status, count(*) AS n FROM support_ticket GROUP BY status", Map.of(),
                rs -> {
                    out.put(rs.getString("status"), rs.getLong("n"));
                });
        return out;
    }

    /** Son 90 gunde acilan taleplerde ilk yetkili yanitina kadar gecen ortalama dakika (veri yoksa 0). */
    public double avgFirstResponseMinutes() {
        Double v = jdbc.queryForObject("SELECT avg(EXTRACT(EPOCH FROM (m.first_at - t.created_at)) / 60.0) "
                + "FROM support_ticket t JOIN (SELECT ticket_id, min(created_at) AS first_at FROM support_message "
                + "WHERE from_staff GROUP BY ticket_id) m ON m.ticket_id = t.id "
                + "WHERE t.created_at >= now() - interval '90 days'", Map.of(), Double.class);
        return v == null ? 0 : Math.round(v * 10) / 10.0;
    }

    public List<KeyCount> feedbackBy(String column) {
        // column yalnizca iki sabit degerden biridir (asagida beyaz liste)
        String col = switch (column) {
            case "category" -> "category";
            case "status" -> "status";
            default -> throw new IllegalArgumentException(column);
        };
        return jdbc.query("SELECT " + col + " AS k, count(*) AS n FROM feedback GROUP BY " + col + " ORDER BY n DESC, k",
                Map.of(), (rs, i) -> new KeyCount(rs.getString("k"), rs.getLong("n")));
    }

    // --- push ---

    /** Gonderilmis (SENT) kampanya sayisi ve toplam alici. */
    public long[] pushTotals() {
        return jdbc.queryForObject("SELECT count(*) AS c, COALESCE(sum(recipient_count), 0) AS r FROM push_campaign "
                + "WHERE status = 'SENT'", Map.of(), (rs, i) -> new long[] {rs.getLong("c"), rs.getLong("r")});
    }

    // --- icerik ---

    /** news_item.published_date (tarih) bazli gunluk sayi; tur: HABER | DUYURU | ETKINLIK. */
    public List<DayCount> contentPerDay(DateRange r, String type) {
        return series(r, "SELECT published_date AS day, count(*) AS n FROM news_item WHERE type = :type "
                + "AND published_date BETWEEN CAST(:from AS date) AND CAST(:to AS date) GROUP BY published_date",
                new MapSqlParameterSource("type", type));
    }
}
