package edu.bingol.backend.post.reel;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.search.SearchHit;
import edu.bingol.backend.search.SearchProvider;
import edu.bingol.backend.search.SearchQuery;
import edu.bingol.backend.search.SearchType;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Genel arama: Reels (type=REELS) = acilis metni (aciklama) araninan, gorunur VIDEO medyali gonderiler. Gorunurluk
 * PostSearchProvider ile ayni (silinmemis, gizli degil, aktif yazar, iki yonlu engel yok, gizli hesap kapisi). Sonuc:
 * title = yazar adi, snippet = aciklama, imageUrl = poster (thumb), likeCount, durationMs; targetId = gonderi kimligi
 * (mobil Reels oynaticiyi/gonderi detayini acar). PostgreSQL'e ozeldir (tsvector Turkce + ILIKE yedegi; parametreli);
 * H2 testlerinde degil `scripts/smoke-kesfet-social.sh` ile dogrulanir.
 */
@Component
public class ReelSearchProvider implements SearchProvider {

    static final int SNIPPET_LEN = 160;

    static final String SQL = "SELECT p.id, p.body, u.display_name, CAST(p.created_at AS varchar) AS created, (p.like_count + p.like_boost) AS like_count, "
            + "p.hide_like_count, p.author_id, vm.id AS media_id, vm.duration_ms, vm.thumb_key "
            + "FROM post p JOIN app_user u ON u.id = p.author_id "
            + "JOIN LATERAL (SELECT m.id, m.duration_ms, m.thumb_key FROM post_media m WHERE m.post_id = p.id "
            + "AND m.kind = 'VIDEO' AND m.hidden_at IS NULL ORDER BY m.position, m.id LIMIT 1) vm ON TRUE "
            + "WHERE p.deleted_at IS NULL AND p.hidden_at IS NULL AND u.deleted_at IS NULL AND u.status = 'ACTIVE' "
            + "AND p.body IS NOT NULL "
            + "AND (to_tsvector('turkish', p.body) @@ websearch_to_tsquery('turkish', ?) OR p.body ILIKE ?) "
            + "AND NOT EXISTS (SELECT 1 FROM user_block b WHERE (b.blocker_id = ? AND b.blocked_id = p.author_id) "
            + "OR (b.blocker_id = p.author_id AND b.blocked_id = ?)) "
            + "AND (p.author_id = ? OR NOT EXISTS (SELECT 1 FROM profile_privacy pp WHERE pp.user_id = p.author_id "
            + "AND pp.private_account = TRUE) OR EXISTS (SELECT 1 FROM user_follow uf WHERE uf.follower_id = ? "
            + "AND uf.followee_id = p.author_id)) "
            + "ORDER BY ts_rank(to_tsvector('turkish', p.body), websearch_to_tsquery('turkish', ?)) DESC, p.id DESC "
            + "LIMIT ? OFFSET ?";

    private final JdbcTemplate jdbc;

    public ReelSearchProvider(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public SearchType type() {
        return SearchType.REELS;
    }

    @Override
    public List<SearchHit> search(String q, int limit) {
        return search(q, limit, 0);
    }

    @Override
    public List<SearchHit> search(String q, int limit, int offset) {
        Long viewer = CurrentUser.id();
        return jdbc.query(SQL, (rs, i) -> {
            Long mediaId = rs.getLong("media_id");
            int dur = rs.getInt("duration_ms");
            boolean durNull = rs.wasNull();
            String poster = rs.getString("thumb_key") == null ? null : "/api/posts/media/" + mediaId + "?thumb=true";
            return new SearchHit(SearchType.REELS, rs.getLong("id"), rs.getString("display_name"),
                    snippet(rs.getString("body")), poster, rs.getString("created"), null, null, null,
                    likes(rs.getInt("like_count"), rs.getBoolean("hide_like_count"), rs.getLong("author_id"), viewer), null, null, durNull ? null : dur);
        }, q, SearchQuery.likePattern(q), viewer, viewer, viewer, viewer, q, Math.max(1, limit), Math.max(0, offset));
    }

    /** Begeni sayisi gizli gonderide (V1670) sayi sahibi disina verilmez. */
    public static Long likes(int count, boolean hidden, long authorId, Long viewer) {
        return hidden && (viewer == null || viewer != authorId) ? null : Long.valueOf(count);
    }

    static String snippet(String body) {
        if (body == null || body.isBlank()) {
            return null;
        }
        String flat = body.replaceAll("\\s+", " ").trim();
        return flat.length() <= SNIPPET_LEN ? flat : flat.substring(0, SNIPPET_LEN).trim() + "…";
    }
}
