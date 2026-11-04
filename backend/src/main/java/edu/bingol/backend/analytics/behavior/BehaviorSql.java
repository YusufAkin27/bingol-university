package edu.bingol.backend.analytics.behavior;

import java.time.OffsetDateTime;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;

/**
 * Davranis analizi SQL parcalari (PostgreSQL: pencere fonksiyonlari, percentile_cont, FILTER; H2'de CALISMAZ ->
 * scripts/smoke-behavior.sh). Oturumlastirma {@link BehaviorMath} ile ayni kurali uygular:
 * sid varsa (kullanici, sid), yoksa kullanici basina 30 dk bosluk. Esikler parametre olarak {@link BehaviorMath}'ten gelir.
 * Yalniz parametreli sorgu; tablo/kolon adlari sabittir, dinamik parca beyaz listeden eklenir.
 */
final class BehaviorSql {

    private BehaviorSql() {}

    /** Ortak parametreler: [from, to) UTC araligi + oturum esikleri. */
    static MapSqlParameterSource params(OffsetDateTime from, OffsetDateTime to) {
        return new MapSqlParameterSource()
                .addValue("from", from)
                .addValue("to", to)
                .addValue("gapSecs", BehaviorMath.GAP.toSeconds())
                .addValue("bounceScreens", BehaviorMath.BOUNCE_MAX_SCREENS)
                .addValue("bounceMs", BehaviorMath.BOUNCE_MS)
                .addValue("quickMs", BehaviorMath.QUICK_CLOSE_MS);
    }

    /**
     * WITH zinciri: base (aralikta cekirdek olaylar) -> lagged -> keyed (oturum anahtari `skey`) -> sess -> sessf
     * (oturum basina: started, last_t, screens, dur_ms, bounce, quick, has_end, end_reason). Tum raporlar bunun
     * uzerine ek CTE / SELECT ekler. Sayi alanlari yalniz rakam desenindeyse cevrilir (bozuk satir sorguyu dusurmez).
     */
    static final String SESSIONS = """
            WITH base AS (
              SELECT id, user_id, name, screen, created_at,
                     props ->> 'sid' AS sid,
                     CASE WHEN name = 'screen_exit' AND props ->> 'dwellMs' ~ '^[0-9]{1,9}$'
                          THEN CAST(props ->> 'dwellMs' AS bigint) END AS dwell,
                     CASE WHEN name = 'session_end' AND props ->> 'durationMs' ~ '^[0-9]{1,9}$'
                          THEN CAST(props ->> 'durationMs' AS bigint) END AS dur,
                     CASE WHEN name = 'session_end' AND props ->> 'screens' ~ '^[0-9]{1,9}$'
                          THEN CAST(props ->> 'screens' AS integer) END AS scr,
                     CASE WHEN name = 'session_end' THEN props ->> 'reason' END AS reason
              FROM analytics_event
              WHERE created_at >= :from AND created_at < :to
                AND name IN ('session_start', 'session_end', 'screen_view', 'screen_exit', 'app_open')
            ),
            lagged AS (
              SELECT b.*, lag(created_at) OVER (PARTITION BY user_id, (sid IS NULL) ORDER BY created_at, id) AS prev_t
              FROM base b
            ),
            keyed AS (
              SELECT l.*,
                     CASE WHEN sid IS NOT NULL THEN CAST(user_id AS text) || ':' || sid
                          ELSE CAST(user_id AS text) || ':d' || CAST(sum(CASE WHEN prev_t IS NULL
                                 OR created_at - prev_t > :gapSecs * interval '1 second' THEN 1 ELSE 0 END)
                                 OVER (PARTITION BY user_id, (sid IS NULL) ORDER BY created_at, id) AS text)
                     END AS skey
              FROM lagged l
            ),
            sess AS (
              SELECT skey, user_id, min(created_at) AS started, max(created_at) AS last_t,
                     max(dur) AS end_dur, max(scr) AS end_scr, max(reason) AS end_reason,
                     bool_or(name = 'session_end') AS has_end,
                     count(*) FILTER (WHERE name = 'screen_view') AS views,
                     COALESCE(sum(dwell), 0) AS dwell_sum,
                     bool_or(name IN ('session_start', 'session_end', 'screen_view', 'app_open')) AS core
              FROM keyed GROUP BY skey, user_id
            ),
            fin AS (
              SELECT skey, user_id, started, last_t, has_end, end_reason,
                     COALESCE(end_scr, views) AS screens,
                     CASE WHEN end_dur IS NOT NULL THEN end_dur
                          ELSE greatest(CAST(extract(epoch FROM (last_t - started)) * 1000 AS bigint), dwell_sum) END AS dur_ms
              FROM sess WHERE core
            ),
            sessf AS (
              SELECT f.*, (screens <= :bounceScreens AND dur_ms < :bounceMs) AS bounce, (dur_ms < :quickMs) AS quick
              FROM fin f
            )
            """;

    /** Ekran gorunumleri: oturum icinde sirali (rn_first/rn_last, sonraki ekran nxt). SESSIONS'a eklenir. */
    static final String SCREEN_VIEWS = """
            , sv AS (
              SELECT k.skey, k.user_id, k.screen,
                     row_number() OVER (PARTITION BY k.skey ORDER BY k.created_at, k.id) AS rn_first,
                     row_number() OVER (PARTITION BY k.skey ORDER BY k.created_at DESC, k.id DESC) AS rn_last,
                     lead(k.screen) OVER (PARTITION BY k.skey ORDER BY k.created_at, k.id) AS nxt
              FROM keyed k JOIN sessf s ON s.skey = k.skey
              WHERE k.name = 'screen_view' AND k.screen IS NOT NULL
            )
            """;

    // --- Ozet (tek gecis: UNION ALL uc kesit) ---
    static final String OVERVIEW = SESSIONS + """
            SELECT 'total' AS kind, CAST(NULL AS date) AS day, 0 AS idx, count(*) AS n, count(DISTINCT user_id) AS users,
                   COALESCE(avg(dur_ms), 0) AS avg_ms,
                   COALESCE(percentile_cont(0.5) WITHIN GROUP (ORDER BY dur_ms), 0) AS med_ms,
                   COALESCE(avg(screens), 0) AS avg_scr,
                   count(*) FILTER (WHERE bounce) AS bounces, count(*) FILTER (WHERE quick) AS quicks
            FROM sessf
            UNION ALL
            SELECT 'day', CAST(started AT TIME ZONE 'Europe/Istanbul' AS date), 0, count(*), 0,
                   COALESCE(avg(dur_ms), 0), 0, 0, count(*) FILTER (WHERE bounce), 0
            FROM sessf GROUP BY 2
            UNION ALL
            SELECT 'bucket', CAST(NULL AS date),
                   CASE WHEN dur_ms < :e1 THEN 0 WHEN dur_ms < :e2 THEN 1 WHEN dur_ms < :e3 THEN 2
                        WHEN dur_ms < :e4 THEN 3 ELSE 4 END,
                   count(*), 0, 0, 0, 0, 0, 0
            FROM sessf GROUP BY 3
            """;

    /** Sirala/yon beyaz listeden gelir; ORDER BY cikti takma adlarina baglanir. */
    static String screens(String orderCol, String dir) {
        return SESSIONS + SCREEN_VIEWS + """
                , vw AS (
                  SELECT sv.screen, count(*) AS views, count(DISTINCT sv.user_id) AS uniq,
                         count(*) FILTER (WHERE sv.rn_last = 1) AS exits,
                         count(*) FILTER (WHERE sv.rn_first = 1) AS entries,
                         count(*) FILTER (WHERE sv.rn_first = 1 AND s.bounce) AS bounces
                  FROM sv JOIN sessf s ON s.skey = sv.skey GROUP BY sv.screen
                ),
                dw AS (
                  SELECT screen, avg(dwell) AS avg_d,
                         percentile_cont(0.5) WITHIN GROUP (ORDER BY dwell) AS med_d,
                         percentile_cont(0.9) WITHIN GROUP (ORDER BY dwell) AS p90_d
                  FROM keyed WHERE name = 'screen_exit' AND screen IS NOT NULL AND dwell IS NOT NULL GROUP BY screen
                )
                SELECT v.screen, v.views, v.uniq, COALESCE(d.avg_d, 0) AS avg_dwell, COALESCE(d.med_d, 0) AS med_dwell,
                       COALESCE(d.p90_d, 0) AS p90_dwell,
                       CASE WHEN v.views > 0 THEN CAST(v.exits AS double precision) / v.views ELSE 0 END AS exit_rate,
                       CASE WHEN v.entries > 0 THEN CAST(v.bounces AS double precision) / v.entries ELSE 0 END AS bounce_rate,
                       CAST(v.views AS double precision) / NULLIF(sum(v.views) OVER (), 0) AS share,
                       count(*) OVER () AS total
                FROM vw v LEFT JOIN dw d ON d.screen = v.screen
                ORDER BY """ + " " + orderCol + " " + dir + ", v.screen LIMIT :lim OFFSET :off";
    }

    /** Akislar: gecisler, giris, cikis, terk (her kesit kendi LIMIT'iyle; parantezli UNION ALL). */
    static final String FLOWS = SESSIONS + SCREEN_VIEWS + """
            (SELECT 'T' AS kind, screen AS a, nxt AS b, count(*) AS n, 0 AS m
               FROM sv WHERE nxt IS NOT NULL AND nxt <> screen GROUP BY screen, nxt
               ORDER BY count(*) DESC, screen, nxt LIMIT 20)
            UNION ALL
            (SELECT 'E', screen, NULL, count(*), 0 FROM sv WHERE rn_first = 1 GROUP BY screen
               ORDER BY count(*) DESC, screen LIMIT 10)
            UNION ALL
            (SELECT 'X', screen, NULL, count(*), 0 FROM sv WHERE rn_last = 1 GROUP BY screen
               ORDER BY count(*) DESC, screen LIMIT 10)
            UNION ALL
            (SELECT 'D', screen, NULL, count(*), count(*) FILTER (WHERE rn_last = 1) FROM sv GROUP BY screen
               ORDER BY count(*) FILTER (WHERE rn_last = 1) DESC, screen LIMIT 15)
            """;

    /** Eylem turu ozeti (yalniz ham tablo; kind beyaz liste parametresiyle sinirlanir). */
    static final String ACTION_KINDS = """
            SELECT props ->> 'kind' AS kind, count(*) AS n, count(DISTINCT user_id) AS users
            FROM analytics_event
            WHERE name = 'action' AND created_at >= :from AND created_at < :to AND props ->> 'kind' IN (:kinds)
            GROUP BY 1
            """;

    static final String ACTION_SCREENS = """
            SELECT props ->> 'kind' AS kind, COALESCE(screen, '') AS screen, count(*) AS n
            FROM analytics_event
            WHERE name = 'action' AND created_at >= :from AND created_at < :to AND props ->> 'kind' IN (:kinds)
            GROUP BY 1, 2
            """;

    /** Kullanici listesi: oturum toplamlari + app_user birlestirme. `where` ve ORDER BY beyaz listeden. */
    static String users(String where, String orderCol, String dir) {
        return SESSIONS + """
                , agg AS (
                  SELECT user_id, count(*) AS sessions, sum(dur_ms) AS total_ms, avg(dur_ms) AS avg_ms,
                         CAST(count(*) FILTER (WHERE bounce) AS double precision) / count(*) AS bounce_rate,
                         count(*) FILTER (WHERE quick) AS quick_count, max(last_t) AS last_seen
                  FROM sessf GROUP BY user_id
                )
                SELECT a.user_id, u.display_name, u.email, u.department, u.grade, a.sessions, a.total_ms, a.avg_ms,
                       a.bounce_rate, a.quick_count, a.last_seen, count(*) OVER () AS total
                FROM agg a JOIN app_user u ON u.id = a.user_id
                WHERE """ + " " + where + " ORDER BY " + orderCol + " " + dir + ", a.user_id LIMIT :lim OFFSET :off";
    }

    /** Sayfadaki kullanicilar icin ekran basina toplam sure (ilk 3). */
    static final String USER_TOP_SCREENS = """
            SELECT user_id, screen, ms FROM (
              SELECT user_id, screen, ms, row_number() OVER (PARTITION BY user_id ORDER BY ms DESC, screen) AS rn
              FROM (
                SELECT user_id, screen, sum(CAST(props ->> 'dwellMs' AS bigint)) AS ms
                FROM analytics_event
                WHERE user_id IN (:ids) AND name = 'screen_exit' AND screen IS NOT NULL
                  AND created_at >= :from AND created_at < :to AND props ->> 'dwellMs' ~ '^[0-9]{1,9}$'
                GROUP BY user_id, screen
              ) g
            ) r WHERE rn <= 3
            """;

    /** Tek kullanici olaylari (en yeni ONCE, LIMIT :cap); cekirdek olaylar + eylemler. */
    static final String USER_EVENTS = """
            SELECT id, name, screen, created_at, props ->> 'sid' AS sid, props ->> 'kind' AS kind,
                   CASE WHEN props ->> 'dwellMs' ~ '^[0-9]{1,9}$' THEN CAST(props ->> 'dwellMs' AS bigint) END AS dwell,
                   CASE WHEN props ->> 'durationMs' ~ '^[0-9]{1,9}$' THEN CAST(props ->> 'durationMs' AS bigint) END AS dur,
                   CASE WHEN props ->> 'screens' ~ '^[0-9]{1,9}$' THEN CAST(props ->> 'screens' AS integer) END AS scr,
                   props ->> 'reason' AS reason
            FROM analytics_event
            WHERE user_id = :uid AND created_at >= :from AND created_at < :to
              AND name IN ('session_start', 'session_end', 'screen_view', 'screen_exit', 'app_open', 'action')
            ORDER BY created_at DESC, id DESC LIMIT :cap
            """;

    // --- Gunluk ozet dolumu (dbmaint.AnalyticsRollup): bir Istanbul gunu, oturum baslangic gunune sayilir ---

    static final String ROLLUP_SESSIONS = """
            INSERT INTO analytics_session_daily (day, sessions, users, total_ms, bounces, quick_closes)
            SELECT CAST(:day AS date), count(*), count(DISTINCT user_id), COALESCE(sum(dur_ms), 0),
                   count(*) FILTER (WHERE bounce), count(*) FILTER (WHERE quick)
            FROM sessf
            HAVING count(*) > 0
            ON CONFLICT (day) DO UPDATE SET sessions = EXCLUDED.sessions, users = EXCLUDED.users,
                   total_ms = EXCLUDED.total_ms, bounces = EXCLUDED.bounces, quick_closes = EXCLUDED.quick_closes
            """;

    static final String ROLLUP_SCREENS = SCREEN_VIEWS + """
            , vw AS (
              SELECT sv.screen, count(*) AS views, count(DISTINCT sv.user_id) AS uniq,
                     count(*) FILTER (WHERE sv.rn_last = 1) AS exits,
                     count(*) FILTER (WHERE sv.rn_first = 1) AS entries,
                     count(*) FILTER (WHERE sv.rn_first = 1 AND s.bounce) AS bounces
              FROM sv JOIN sessf s ON s.skey = sv.skey GROUP BY sv.screen
            ),
            dw AS (
              SELECT screen, COALESCE(sum(dwell), 0) AS dsum, count(*) AS dn
              FROM keyed WHERE name = 'screen_exit' AND screen IS NOT NULL AND dwell IS NOT NULL GROUP BY screen
            )
            INSERT INTO analytics_screen_daily (day, screen, views, users, dwell_ms_sum, dwell_n, exits, entries, bounce_sessions)
            SELECT CAST(:day AS date), v.screen, v.views, v.uniq, COALESCE(d.dsum, 0), COALESCE(d.dn, 0), v.exits, v.entries, v.bounces
            FROM vw v LEFT JOIN dw d ON d.screen = v.screen
            ON CONFLICT (day, screen) DO UPDATE SET views = EXCLUDED.views, users = EXCLUDED.users,
                   dwell_ms_sum = EXCLUDED.dwell_ms_sum, dwell_n = EXCLUDED.dwell_n, exits = EXCLUDED.exits,
                   entries = EXCLUDED.entries, bounce_sessions = EXCLUDED.bounce_sessions
            """;
}
