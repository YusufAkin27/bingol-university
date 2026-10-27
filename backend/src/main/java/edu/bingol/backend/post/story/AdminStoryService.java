package edu.bingol.backend.post.story;

import edu.bingol.backend.common.ApiException;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Yonetici hikaye listesi / gizleme (duz SQL; sayfalama imleci = hikaye id). */
@Service
public class AdminStoryService {

    public record StoryRow(Long id, Long authorId, String authorName, String kind, Long mediaId, String text,
                           String caption, int viewCount, Instant createdAt, Instant expiresAt, boolean expired,
                           boolean hidden, String hiddenReason) {}

    public record StoryPage(List<StoryRow> items, Long nextCursor) {}

    private final JdbcTemplate jdbc;
    private final StoryRepository stories;

    public AdminStoryService(JdbcTemplate jdbc, StoryRepository stories) {
        this.jdbc = jdbc;
        this.stories = stories;
    }

    @Transactional(readOnly = true)
    public StoryPage list(Long cursor, int size, String q, Boolean hidden) {
        int n = size <= 0 ? 20 : Math.min(size, 50);
        StringBuilder sql = new StringBuilder("SELECT s.id, s.author_id, u.display_name, s.kind, s.media_id, s.body_text, "
                + "s.caption, s.view_count, s.created_at, s.expires_at, s.hidden_at, s.hidden_reason FROM story s "
                + "JOIN app_user u ON u.id = s.author_id WHERE s.deleted_at IS NULL");
        List<Object> args = new ArrayList<>();
        if (cursor != null) {
            sql.append(" AND s.id < ?");
            args.add(cursor);
        }
        if (q != null && !q.isBlank()) {
            sql.append(" AND (LOWER(u.display_name) LIKE ? ESCAPE '\\' OR LOWER(u.email) LIKE ? ESCAPE '\\')");
            String like = "%" + q.strip().toLowerCase(java.util.Locale.ROOT).replace("\\", "\\\\").replace("%", "\\%")
                    .replace("_", "\\_") + "%";
            args.add(like);
            args.add(like);
        }
        if (hidden != null) {
            sql.append(hidden ? " AND s.hidden_at IS NOT NULL" : " AND s.hidden_at IS NULL");
        }
        sql.append(" ORDER BY s.id DESC LIMIT ").append(n + 1);
        Instant now = Instant.now();
        List<StoryRow> rows = jdbc.query(sql.toString(), (rs, i) -> new StoryRow(rs.getLong(1), rs.getLong(2),
                rs.getString(3), rs.getString(4), (Long) rs.getObject(5), rs.getString(6), rs.getString(7), rs.getInt(8),
                rs.getTimestamp(9).toInstant(), rs.getTimestamp(10).toInstant(), rs.getTimestamp(10).toInstant().isBefore(now),
                rs.getTimestamp(11) != null, rs.getString(12)), args.toArray());
        boolean more = rows.size() > n;
        List<StoryRow> page = more ? rows.subList(0, n) : rows;
        return new StoryPage(page, more ? page.get(page.size() - 1).id() : null);
    }

    @Transactional
    public StoryRow hide(long id, String reason) {
        Story s = stories.findById(id).filter(x -> x.getDeletedAt() == null).orElseThrow(AdminStoryService::notFound);
        if (s.getHiddenAt() == null) {
            s.setHiddenAt(Instant.now());
        }
        s.setHiddenReason(reason == null || reason.isBlank() ? "Yönetici" : reason.strip());
        stories.saveAndFlush(s);
        return row(id);
    }

    @Transactional
    public StoryRow unhide(long id) {
        Story s = stories.findById(id).filter(x -> x.getDeletedAt() == null).orElseThrow(AdminStoryService::notFound);
        s.setHiddenAt(null);
        s.setHiddenReason(null);
        stories.saveAndFlush(s);
        return row(id);
    }

    private StoryRow row(long id) {
        StoryPage p = list(id + 1, 1, null, null);
        return p.items().stream().filter(r -> r.id() == id).findFirst().orElseThrow(AdminStoryService::notFound);
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "STORY_NOT_FOUND", "Hikaye bulunamadı.");
    }
}
