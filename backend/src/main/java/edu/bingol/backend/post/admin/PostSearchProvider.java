package edu.bingol.backend.post.admin;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.search.SearchHit;
import edu.bingol.backend.search.SearchProvider;
import edu.bingol.backend.search.SearchQuery;
import edu.bingol.backend.search.SearchType;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Genel arama: Kesfet gonderi metni (type=POSTS). Yalniz gorunur (silinmemis, gizlenmemis) ve fotografli gonderiler, silinmis
 * hesaplar haric, istegi yapanla iki yonlu engel iliskisi olanlar haric. PostgreSQL'e ozeldir (tsvector Turkce +
 * ILIKE yedegi; parametreli); H2 testlerinde degil `scripts/smoke-posts.sh` ile dogrulanir.
 */
@Component
public class PostSearchProvider implements SearchProvider {

    static final int SNIPPET_LEN = 160;

    /**
     * Akis ({@code PostRepository.FEED_VISIBLE}) ile ayni gorunurluk: aktif yazar + en az bir gorunur FOTOGRAF
     * (video-only/metin-only eski gonderiler aramada da cikmaz). Standart SQL; H2 testinde calisir.
     */
    static final String VISIBLE_SQL = "p.deleted_at IS NULL AND p.hidden_at IS NULL AND u.deleted_at IS NULL "
            + "AND u.status = 'ACTIVE' "
            + "AND EXISTS (SELECT 1 FROM post_media pm WHERE pm.post_id = p.id AND pm.kind = 'IMAGE' AND pm.hidden_at IS NULL) ";

    static final String SQL = "SELECT p.id, p.body, u.display_name, CAST(p.created_at AS varchar) AS created, p.like_count, "
            + "(SELECT m.id FROM post_media m WHERE m.post_id = p.id AND m.kind = 'IMAGE' AND m.hidden_at IS NULL ORDER BY m.position, m.id LIMIT 1) AS media_id "
            + "FROM post p JOIN app_user u ON u.id = p.author_id "
            + "WHERE " + VISIBLE_SQL + "AND p.body IS NOT NULL "
            + "AND (to_tsvector('turkish', p.body) @@ websearch_to_tsquery('turkish', ?) OR p.body ILIKE ?) "
            + "AND NOT EXISTS (SELECT 1 FROM user_block b WHERE (b.blocker_id = ? AND b.blocked_id = p.author_id) "
            + "OR (b.blocker_id = p.author_id AND b.blocked_id = ?)) "
            + "ORDER BY ts_rank(to_tsvector('turkish', p.body), websearch_to_tsquery('turkish', ?)) DESC, p.id DESC "
            + "LIMIT ? OFFSET ?";

    private final JdbcTemplate jdbc;

    public PostSearchProvider(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public SearchType type() {
        return SearchType.POSTS;
    }

    @Override
    public List<SearchHit> search(String q, int limit) {
        return search(q, limit, 0);
    }

    @Override
    public List<SearchHit> search(String q, int limit, int offset) {
        Long viewer = CurrentUser.id();
        return jdbc.query(SQL, (rs, i) -> {
            Long mediaId = (Long) rs.getObject("media_id");
            return new SearchHit(SearchType.POSTS, rs.getLong("id"), rs.getString("display_name"),
                    snippet(rs.getString("body")), mediaId == null ? null : "/api/posts/media/" + mediaId + "?thumb=true",
                    rs.getString("created"), null, null, null, (long) rs.getInt("like_count"));
        }, q, SearchQuery.likePattern(q), viewer, viewer, q, Math.max(1, limit), Math.max(0, offset));
    }

    static String snippet(String body) {
        if (body == null || body.isBlank()) {
            return null;
        }
        String flat = body.replaceAll("\\s+", " ").trim();
        return flat.length() <= SNIPPET_LEN ? flat : flat.substring(0, SNIPPET_LEN).trim() + "…";
    }
}
