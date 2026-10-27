package edu.bingol.backend.post.admin;

import edu.bingol.backend.moderation.MediaPreview;
import edu.bingol.backend.moderation.ReportTargetHandler;
import edu.bingol.backend.moderation.ReportTargetType;
import edu.bingol.backend.post.media.PostMediaService;
import java.util.List;
import java.util.Optional;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Moderasyon SPI: Kesfet akisi gonderisi (FEED_POST) ve yorumu (FEED_COMMENT). "Gizle" = yumusak gizleme
 * (hidden_at); akistan ve detaydan kalkar, geri alinabilir (otomatik gizleme esigi + itiraz + rapor reddinde unhide).
 * Silinmis icerik "yok" sayilir. Duz SQL (post paketi depolarina bagimlilik yok).
 */
public final class PostReportHandlers {

    private PostReportHandlers() {}

    @Component
    public static class FeedPostHandler implements ReportTargetHandler {

        private final JdbcTemplate jdbc;
        private final PostMediaService media;

        public FeedPostHandler(JdbcTemplate jdbc, PostMediaService media) {
            this.jdbc = jdbc;
            this.media = media;
        }

        @Override
        public ReportTargetType type() {
            return ReportTargetType.FEED_POST;
        }

        @Override
        public boolean exists(Long targetId) {
            return count("SELECT COUNT(*) FROM post WHERE id = ? AND deleted_at IS NULL", targetId) > 0;
        }

        @Override
        public Optional<Long> ownerId(Long targetId) {
            List<Long> r = jdbc.queryForList("SELECT author_id FROM post WHERE id = ?", Long.class, targetId);
            return r.isEmpty() ? Optional.empty() : Optional.of(r.get(0));
        }

        @Override
        @Transactional
        public void hide(Long targetId) {
            jdbc.update("UPDATE post SET hidden_at = CURRENT_TIMESTAMP, hidden_reason = COALESCE(hidden_reason, 'Şikayet') "
                    + "WHERE id = ? AND hidden_at IS NULL AND deleted_at IS NULL", targetId);
            media.hide(targetId);
        }

        /** Ilk medya (varsa) gorsel/video onizlemesi; medyasiz gonderide metin. */
        @Override
        public Optional<MediaPreview> preview(Long targetId) {
            List<Object[]> m = jdbc.query("SELECT m.id, m.kind, m.content_type FROM post_media m "
                    + "JOIN post p ON p.id = m.post_id WHERE m.post_id = ? AND p.deleted_at IS NULL "
                    + "ORDER BY m.position, m.id LIMIT 1",
                    (rs, i) -> new Object[] {rs.getLong(1), rs.getString(2), rs.getString(3)}, targetId);
            if (!m.isEmpty()) {
                long id = (Long) m.get(0)[0];
                String url = AdminPostService.MEDIA_URL + id;
                String thumb = url + "?thumb=true";
                return Optional.of("VIDEO".equals(m.get(0)[1])
                        ? MediaPreview.video(url, thumb, (String) m.get(0)[2])
                        : MediaPreview.image(url, thumb, (String) m.get(0)[2]));
            }
            List<String> t = jdbc.queryForList("SELECT body FROM post WHERE id = ? AND deleted_at IS NULL", String.class, targetId);
            return t.isEmpty() || t.get(0) == null ? Optional.empty() : Optional.of(MediaPreview.text(t.get(0)));
        }

        @Override
        public boolean reversible() {
            return true;
        }

        @Override
        @Transactional
        public void unhide(Long targetId) {
            jdbc.update("UPDATE post SET hidden_at = NULL, hidden_reason = NULL WHERE id = ?", targetId);
            media.unhide(targetId);
        }

        private long count(String sql, Object arg) {
            Long n = jdbc.queryForObject(sql, Long.class, arg);
            return n == null ? 0 : n;
        }
    }

    @Component
    public static class FeedCommentHandler implements ReportTargetHandler {

        private final JdbcTemplate jdbc;

        public FeedCommentHandler(JdbcTemplate jdbc) {
            this.jdbc = jdbc;
        }

        @Override
        public ReportTargetType type() {
            return ReportTargetType.FEED_COMMENT;
        }

        @Override
        public boolean exists(Long targetId) {
            Long n = jdbc.queryForObject("SELECT COUNT(*) FROM post_comment WHERE id = ? AND deleted_at IS NULL",
                    Long.class, targetId);
            return n != null && n > 0;
        }

        @Override
        public Optional<Long> ownerId(Long targetId) {
            List<Long> r = jdbc.queryForList("SELECT author_id FROM post_comment WHERE id = ?", Long.class, targetId);
            return r.isEmpty() ? Optional.empty() : Optional.of(r.get(0));
        }

        @Override
        @Transactional
        public void hide(Long targetId) {
            jdbc.update("UPDATE post_comment SET hidden_at = CURRENT_TIMESTAMP "
                    + "WHERE id = ? AND hidden_at IS NULL AND deleted_at IS NULL", targetId);
        }

        @Override
        public Optional<MediaPreview> preview(Long targetId) {
            List<String> t = jdbc.queryForList("SELECT body FROM post_comment WHERE id = ? AND deleted_at IS NULL",
                    String.class, targetId);
            return t.isEmpty() || t.get(0) == null ? Optional.empty() : Optional.of(MediaPreview.text(t.get(0)));
        }

        @Override
        public boolean reversible() {
            return true;
        }

        @Override
        @Transactional
        public void unhide(Long targetId) {
            jdbc.update("UPDATE post_comment SET hidden_at = NULL WHERE id = ?", targetId);
        }
    }
}
