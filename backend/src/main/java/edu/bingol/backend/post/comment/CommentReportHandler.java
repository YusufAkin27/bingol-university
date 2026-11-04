package edu.bingol.backend.post.comment;

import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.moderation.MediaPreview;
import edu.bingol.backend.moderation.ReportTargetHandler;
import edu.bingol.backend.moderation.ReportTargetType;
import java.util.List;
import java.util.Optional;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Moderasyon SPI: gonderi/reel yorumu (COMMENT). "Gizle" = yumusak gizleme (hidden_at); listeden kalkar, sayaclar yeniden
 * hesaplanir, geri alinabilir (otomatik gizleme esigi + itiraz + rapor reddinde unhide). Silinmis yorum "yok" sayilir.
 * Duz SQL (post paketi depolarina bagimlilik yok).
 */
@Component
public class CommentReportHandler implements ReportTargetHandler {

    private final JdbcTemplate jdbc;
    private final BlockService blocks;
    private final CommentCounters counters;

    public CommentReportHandler(JdbcTemplate jdbc, BlockService blocks, CommentCounters counters) {
        this.jdbc = jdbc;
        this.blocks = blocks;
        this.counters = counters;
    }

    @Override
    public ReportTargetType type() {
        return ReportTargetType.COMMENT;
    }

    @Override
    public boolean exists(Long targetId) {
        Long n = jdbc.queryForObject("SELECT COUNT(*) FROM post_comment WHERE id = ? AND deleted_at IS NULL", Long.class, targetId);
        return n != null && n > 0;
    }

    /**
     * Raporlayan yorumu GOREBILIYORSA (PostCommentService.visibleComment ile ayni kural): yorum + gonderi gorunur, yazarlar
     * aktif, engel yok, gizli hesap kapisi. Gorunmeyen yorum olmayanla ayni 404 (varlik sizdirilmaz).
     */
    @Override
    public boolean exists(Long viewerId, Long targetId) {
        List<Long[]> r = jdbc.query("SELECT c.author_id, p.author_id FROM post_comment c JOIN post p ON p.id = c.post_id "
                + "JOIN app_user cu ON cu.id = c.author_id JOIN app_user pu ON pu.id = p.author_id "
                + "WHERE c.id = ? AND c.deleted_at IS NULL AND c.hidden_at IS NULL AND p.deleted_at IS NULL "
                + "AND p.hidden_at IS NULL AND cu.status = 'ACTIVE' AND pu.status = 'ACTIVE'",
                (rs, i) -> new Long[] {rs.getLong(1), rs.getLong(2)}, targetId);
        if (r.isEmpty()) {
            return false;
        }
        Long commentAuthor = r.get(0)[0];
        Long postAuthor = r.get(0)[1];
        if (viewerId == null || commentAuthor.equals(viewerId)) {
            return true;
        }
        if (blocks.isBlocked(viewerId, commentAuthor) || (!postAuthor.equals(viewerId) && blocks.isBlocked(viewerId, postAuthor))) {
            return false;
        }
        // Gizli hesap: gormedigi gonderinin yorumu raporlanamaz
        Integer hidden = jdbc.queryForObject("SELECT COUNT(*) FROM profile_privacy pp WHERE pp.user_id = ? "
                + "AND pp.private_account = TRUE AND NOT EXISTS (SELECT 1 FROM user_follow uf "
                + "WHERE uf.follower_id = ? AND uf.followee_id = pp.user_id)", Integer.class, postAuthor, viewerId);
        return postAuthor.equals(viewerId) || hidden == null || hidden == 0;
    }

    @Override
    public Optional<Long> ownerId(Long targetId) {
        List<Long> r = jdbc.queryForList("SELECT author_id FROM post_comment WHERE id = ?", Long.class, targetId);
        return r.isEmpty() ? Optional.empty() : Optional.of(r.get(0));
    }

    @Override
    @Transactional
    public void hide(Long targetId) {
        jdbc.update("UPDATE post_comment SET hidden_at = CURRENT_TIMESTAMP, hidden_reason = COALESCE(hidden_reason, 'Şikayet') "
                + "WHERE id = ? AND hidden_at IS NULL AND deleted_at IS NULL", targetId);
        recount(targetId);
    }

    @Override
    public Optional<MediaPreview> preview(Long targetId) {
        List<String> t = jdbc.queryForList("SELECT body FROM post_comment WHERE id = ? AND deleted_at IS NULL", String.class, targetId);
        return t.isEmpty() || t.get(0) == null ? Optional.empty() : Optional.of(MediaPreview.text(t.get(0)));
    }

    @Override
    public boolean reversible() {
        return true;
    }

    @Override
    @Transactional
    public void unhide(Long targetId) {
        jdbc.update("UPDATE post_comment SET hidden_at = NULL, hidden_reason = NULL WHERE id = ? AND deleted_at IS NULL", targetId);
        recount(targetId);
    }

    private void recount(Long commentId) {
        List<Long> post = jdbc.queryForList("SELECT post_id FROM post_comment WHERE id = ?", Long.class, commentId);
        if (!post.isEmpty()) {
            counters.recountPosts(post);
        }
    }
}
