package edu.bingol.backend.post.story;

import edu.bingol.backend.moderation.MediaPreview;
import edu.bingol.backend.moderation.ReportTargetHandler;
import edu.bingol.backend.moderation.ReportTargetType;
import java.util.List;
import java.util.Optional;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Moderasyon SPI: hikaye (STORY). "Gizle" = yumusak gizleme (hidden_at); geri alinabilir. Silinmis hikaye "yok".
 * Medya onizlemesi yonetici medya ucundan gelir (/api/admin/posts/media/{id}).
 */
@Component
public class StoryReportHandler implements ReportTargetHandler {

    private final JdbcTemplate jdbc;

    public StoryReportHandler(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public ReportTargetType type() {
        return ReportTargetType.STORY;
    }

    @Override
    public boolean exists(Long targetId) {
        Long n = jdbc.queryForObject("SELECT COUNT(*) FROM story WHERE id = ? AND deleted_at IS NULL", Long.class, targetId);
        return n != null && n > 0;
    }

    @Override
    public Optional<Long> ownerId(Long targetId) {
        List<Long> r = jdbc.queryForList("SELECT author_id FROM story WHERE id = ?", Long.class, targetId);
        return r.isEmpty() ? Optional.empty() : Optional.of(r.get(0));
    }

    @Override
    @Transactional
    public void hide(Long targetId) {
        jdbc.update("UPDATE story SET hidden_at = CURRENT_TIMESTAMP, hidden_reason = COALESCE(hidden_reason, 'Şikayet') "
                + "WHERE id = ? AND hidden_at IS NULL AND deleted_at IS NULL", targetId);
    }

    @Override
    public Optional<MediaPreview> preview(Long targetId) {
        List<Object[]> r = jdbc.query("SELECT s.kind, s.media_id, s.body_text, s.caption, m.content_type FROM story s "
                + "LEFT JOIN post_media m ON m.id = s.media_id WHERE s.id = ? AND s.deleted_at IS NULL",
                (rs, i) -> new Object[] {rs.getString(1), rs.getObject(2), rs.getString(3), rs.getString(4),
                        rs.getString(5)}, targetId);
        if (r.isEmpty()) {
            return Optional.empty();
        }
        Object[] row = r.get(0);
        if (row[1] != null) {
            String url = "/api/admin/posts/media/" + ((Number) row[1]).longValue();
            String mime = (String) row[4];
            return Optional.of("VIDEO".equals(row[0]) ? MediaPreview.video(url, url + "?thumb=true", mime)
                    : MediaPreview.image(url, url + "?thumb=true", mime));
        }
        String text = (String) row[2];
        return text == null ? Optional.empty() : Optional.of(MediaPreview.text(text));
    }

    @Override
    public boolean reversible() {
        return true;
    }

    @Override
    @Transactional
    public void unhide(Long targetId) {
        jdbc.update("UPDATE story SET hidden_at = NULL, hidden_reason = NULL WHERE id = ?", targetId);
    }
}
