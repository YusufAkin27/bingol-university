package edu.bingol.backend.forum.search;

import java.sql.Timestamp;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * {@link ForumSearchRepository} PostgreSQL uygulamasi: sakli {@code search_vec} (V1442) + baslikta trigram ILIKE.
 * Dinamik parca YALNIZ ORDER BY'dir ve onu beyaz listeden gelen {@link ForumSearchSort} secer; kullanici girdisi her
 * yerde baglanan parametredir (ILIKE deseni kacislidir). H2'de calismaz: {@code scripts/smoke-forum-search.sh}.
 */
@Repository
public class PgForumSearchRepository implements ForumSearchRepository {

    /** ts_headline secenekleri: isaretleyiciler sonradan silinir (duz metin snippet). */
    private static final String HEADLINE = "MaxWords=24, MinWords=8, MaxFragments=1, StartSel=~~~, StopSel=~~~";
    private static final int SNIPPET_MAX = 160;

    private static final String SEARCH_SQL = """
            WITH qq AS (SELECT plainto_tsquery('turkish', :q) AS tsq),
            cand AS (
              SELECT t.id AS topic_id,
                     CASE WHEN t.title ILIKE :pat OR to_tsvector('turkish', t.title) @@ qq.tsq THEN 'TITLE'
                          WHEN t.search_vec @@ qq.tsq THEN 'BODY'
                          ELSE 'CATEGORY' END AS matched_in,
                     ts_rank(t.search_vec, qq.tsq) AS rank
                FROM forum_topic t
                JOIN app_user u ON u.id = t.user_id AND u.status = 'ACTIVE'
                CROSS JOIN qq
               WHERE t.deleted_at IS NULL AND t.status = 'ACTIVE'
                 AND (CAST(:cat AS BIGINT) IS NULL OR t.category_id = :cat)
                 AND t.user_id NOT IN (:excluded)
                 AND (t.search_vec @@ qq.tsq OR t.title ILIKE :pat
                      OR EXISTS (SELECT 1 FROM forum_category fc WHERE fc.id = t.category_id
                                  AND (fc.name_tr ILIKE :pat OR fc.name_en ILIKE :pat OR fc.name_ar ILIKE :pat)))
              UNION ALL
              SELECT t.id, 'COMMENT', ts_rank(c.search_vec, qq.tsq) * 0.5
                FROM forum_comment c
                JOIN forum_topic t ON t.id = c.topic_id AND t.deleted_at IS NULL AND t.status = 'ACTIVE'
                JOIN app_user u ON u.id = t.user_id AND u.status = 'ACTIVE'
                JOIN app_user cu ON cu.id = c.user_id AND cu.status = 'ACTIVE'
                CROSS JOIN qq
               WHERE c.anonymous = FALSE AND c.status = 'ACTIVE' AND c.deleted_at IS NULL
                 AND c.search_vec @@ qq.tsq
                 AND (CAST(:cat AS BIGINT) IS NULL OR t.category_id = :cat)
                 AND t.user_id NOT IN (:excluded) AND c.user_id NOT IN (:excluded)
            ),
            b AS (
              SELECT DISTINCT ON (topic_id) topic_id, matched_in, rank FROM cand
               ORDER BY topic_id,
                        CASE matched_in WHEN 'TITLE' THEN 1 WHEN 'BODY' THEN 2 WHEN 'COMMENT' THEN 3 ELSE 4 END,
                        rank DESC
            )
            SELECT b.topic_id, b.matched_in
              FROM b JOIN forum_topic t ON t.id = b.topic_id
             ORDER BY %s
             LIMIT :lim OFFSET :off""";

    private static final String BODY_SNIPPET_SQL = "SELECT t.id, ts_headline('turkish', t.body, "
            + "plainto_tsquery('turkish', :q), '" + HEADLINE + "') AS s FROM forum_topic t WHERE t.id IN (:ids)";

    private static final String COMMENT_SNIPPET_SQL = """
            SELECT DISTINCT ON (c.topic_id) c.topic_id,
                   ts_headline('turkish', c.body, plainto_tsquery('turkish', :q), '%s') AS s
              FROM forum_comment c
              JOIN app_user cu ON cu.id = c.user_id AND cu.status = 'ACTIVE'
             WHERE c.topic_id IN (:ids) AND c.anonymous = FALSE AND c.status = 'ACTIVE' AND c.deleted_at IS NULL
               AND c.search_vec @@ plainto_tsquery('turkish', :q) AND c.user_id NOT IN (:excluded)
             ORDER BY c.topic_id, ts_rank(c.search_vec, plainto_tsquery('turkish', :q)) DESC""";

    private final NamedParameterJdbcTemplate jdbc;

    public PgForumSearchRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** Dis sorgunun ORDER BY'i (yalniz sabit metinler). */
    static String orderBy(ForumSearchSort sort) {
        return switch (sort) {
            case NEWEST -> "t.created_at DESC, t.id DESC";
            case POPULAR -> "(t.like_count + 2 * t.comment_count) DESC, t.created_at DESC, t.id DESC";
            case RELEVANCE -> "b.rank DESC, t.created_at DESC, t.id DESC";
        };
    }

    @Override
    public List<Hit> search(String q, Long categoryId, ForumSearchSort sort, Set<Long> excludedAuthors, int offset,
                            int limit) {
        MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("q", q)
                .addValue("pat", ForumSearchService.likePattern(q))
                .addValue("cat", categoryId, java.sql.Types.BIGINT)
                .addValue("excluded", excludedOrSentinel(excludedAuthors))
                .addValue("off", offset)
                .addValue("lim", limit);
        Map<Long, String> matched = new LinkedHashMap<>();
        jdbc.query(SEARCH_SQL.formatted(orderBy(sort)), p,
                rs -> {
                    matched.put(rs.getLong("topic_id"), rs.getString("matched_in"));
                });
        Map<Long, String> snippets = snippets(q, matched, excludedAuthors);
        List<Hit> out = new ArrayList<>(matched.size());
        matched.forEach((id, m) -> out.add(new Hit(id, m, snippets.get(id))));
        return out;
    }

    /** BODY ve COMMENT eslesmeleri icin duz metin parca (yalniz sayfadaki satirlar; ts_headline pahalidir). */
    private Map<Long, String> snippets(String q, Map<Long, String> matched, Set<Long> excludedAuthors) {
        Map<Long, String> out = new HashMap<>();
        List<Long> bodyIds = new ArrayList<>();
        List<Long> commentIds = new ArrayList<>();
        matched.forEach((id, m) -> {
            if ("BODY".equals(m)) {
                bodyIds.add(id);
            } else if ("COMMENT".equals(m)) {
                commentIds.add(id);
            }
        });
        if (!bodyIds.isEmpty()) {
            jdbc.query(BODY_SNIPPET_SQL, new MapSqlParameterSource("q", q).addValue("ids", bodyIds),
                    rs -> {
                        out.put(rs.getLong("id"), clean(rs.getString("s")));
                    });
        }
        if (!commentIds.isEmpty()) {
            jdbc.query(COMMENT_SNIPPET_SQL.formatted(HEADLINE),
                    new MapSqlParameterSource("q", q).addValue("ids", commentIds)
                            .addValue("excluded", excludedOrSentinel(excludedAuthors)),
                    rs -> {
                        out.put(rs.getLong("topic_id"), clean(rs.getString("s")));
                    });
        }
        return out;
    }

    @Override
    public List<Long> popular(Set<Long> excludedAuthors, int limit) {
        MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("since", Timestamp.from(Instant.now().minus(7, ChronoUnit.DAYS)))
                .addValue("excluded", excludedOrSentinel(excludedAuthors))
                .addValue("lim", limit);
        return jdbc.queryForList("""
                SELECT t.id FROM forum_topic t
                  JOIN app_user u ON u.id = t.user_id AND u.status = 'ACTIVE'
                 WHERE t.deleted_at IS NULL AND t.status = 'ACTIVE' AND t.last_activity_at >= :since
                   AND t.user_id NOT IN (:excluded)
                 ORDER BY (t.like_count + 2 * t.comment_count) DESC, t.last_activity_at DESC, t.id DESC
                 LIMIT :lim""", p, Long.class);
    }

    /** NOT IN () bos listede gecersizdir: hicbir kullanicinin sahip olmadigi -1 koyulur. */
    static List<Long> excludedOrSentinel(Set<Long> excluded) {
        return excluded == null || excluded.isEmpty() ? List.of(-1L) : List.copyOf(excluded);
    }

    /** Isaretleyicileri siler, bosluklari sadelestirir, 160 karaktere keser. */
    static String clean(String s) {
        if (s == null) {
            return null;
        }
        String t = s.replace("~~~", "").replaceAll("\\s+", " ").strip();
        if (t.isEmpty()) {
            return null;
        }
        return t.length() <= SNIPPET_MAX ? t : t.substring(0, SNIPPET_MAX - 1).stripTrailing() + "…";
    }
}
