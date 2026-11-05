package edu.bingol.backend.forum.moderation;

import edu.bingol.backend.forum.moderation.ForumContentLookup.CommentRow;
import edu.bingol.backend.forum.moderation.ForumContentLookup.TopicRow;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.moderation.MediaPreview;
import edu.bingol.backend.moderation.ReportTargetHandler;
import edu.bingol.backend.moderation.ReportTargetType;
import java.util.Optional;
import org.springframework.stereotype.Component;

/**
 * Kampus Forum icin moderasyon SPI adaptorleri (FORUM_TOPIC, FORUM_COMMENT). ANONIM icerik de raporlanabilir: yazar
 * kimligi yalniz {@link #ownerId} ile SUNUCU ICI kararlarda (uyari/strike/askiya alma) kullanilir; yonetici kuyrugu
 * kimligi gostermez ({@code AdminReportContextService} anonim icerigin sahibini cozmez).
 *
 * <p>"Gizle" = konu/yorumu {@code REMOVED} yapmak (yumusak, geri alinabilir); bu yuzden {@link #reversible()} true:
 * esik asilinca otomatik gizlenir, rapor reddedilince/itirazda geri acilir. Durumu A/B servisleri tutar
 * ({@link ForumModerationService} -> {@link ForumStatePort}).
 */
public final class ForumReportHandlers {

    private ForumReportHandlers() {}

    static String snippet(String s, int max) {
        if (s == null) {
            return "";
        }
        return s.length() <= max ? s : s.substring(0, max) + "…";
    }

    @Component
    public static class TopicHandler implements ReportTargetHandler {

        private final ForumContentLookup content;
        private final BlockService blocks;
        private final ForumModerationService moderation;

        public TopicHandler(ForumContentLookup content, BlockService blocks, ForumModerationService moderation) {
            this.content = content;
            this.blocks = blocks;
            this.moderation = moderation;
        }

        @Override
        public ReportTargetType type() {
            return ReportTargetType.FORUM_TOPIC;
        }

        /** Yonetici karar akisi: sahibi silmedigi surece (kaldirilmis dahil) vardir; kaldirilmis icerik geri acilabilsin. */
        @Override
        public boolean exists(Long targetId) {
            return content.topic(targetId).filter(t -> !t.deleted()).isPresent();
        }

        /** Raporlayan icin GORUNUR: aktif konu, yazar aktif hesap, yazar raporlayani engellememis. */
        @Override
        public boolean exists(Long viewerId, Long targetId) {
            Optional<TopicRow> t = content.topic(targetId).filter(TopicRow::active);
            if (t.isEmpty() || !content.userActive(t.get().userId())) {
                return false;
            }
            Long author = t.get().userId();
            return viewerId == null || viewerId.equals(author) || !blocks.hasBlocked(author, viewerId);
        }

        @Override
        public Optional<Long> ownerId(Long targetId) {
            return content.topic(targetId).map(TopicRow::userId);
        }

        @Override
        public void hide(Long targetId) {
            moderation.hideFromReport(ReportTargetType.FORUM_TOPIC, targetId);
        }

        @Override
        public Optional<MediaPreview> preview(Long targetId) {
            return content.topic(targetId).filter(t -> !t.deleted())
                    .map(t -> MediaPreview.text(snippet(t.title(), 150) + "\n" + snippet(t.body(), 350)));
        }

        @Override
        public boolean reversible() {
            return true;
        }

        @Override
        public void unhide(Long targetId) {
            moderation.restoreFromReport(ReportTargetType.FORUM_TOPIC, targetId);
        }
    }

    @Component
    public static class CommentHandler implements ReportTargetHandler {

        private final ForumContentLookup content;
        private final BlockService blocks;
        private final ForumModerationService moderation;

        public CommentHandler(ForumContentLookup content, BlockService blocks, ForumModerationService moderation) {
            this.content = content;
            this.blocks = blocks;
            this.moderation = moderation;
        }

        @Override
        public ReportTargetType type() {
            return ReportTargetType.FORUM_COMMENT;
        }

        @Override
        public boolean exists(Long targetId) {
            return content.comment(targetId).filter(c -> !c.deleted()).isPresent();
        }

        /** Yorum ve ait oldugu konu aktif; iki yazar da aktif hesap; yorum/konu yazari raporlayani engellememis. */
        @Override
        public boolean exists(Long viewerId, Long targetId) {
            Optional<CommentRow> c = content.comment(targetId).filter(CommentRow::active);
            if (c.isEmpty()) {
                return false;
            }
            Optional<TopicRow> t = content.topic(c.get().topicId()).filter(TopicRow::active);
            if (t.isEmpty() || !content.userActive(c.get().userId()) || !content.userActive(t.get().userId())) {
                return false;
            }
            if (viewerId == null) {
                return true;
            }
            Long commentAuthor = c.get().userId();
            Long topicAuthor = t.get().userId();
            boolean blockedByCommentAuthor = !viewerId.equals(commentAuthor) && blocks.hasBlocked(commentAuthor, viewerId);
            boolean blockedByTopicAuthor = !viewerId.equals(topicAuthor) && blocks.hasBlocked(topicAuthor, viewerId);
            return !blockedByCommentAuthor && !blockedByTopicAuthor;
        }

        @Override
        public Optional<Long> ownerId(Long targetId) {
            return content.comment(targetId).map(CommentRow::userId);
        }

        @Override
        public void hide(Long targetId) {
            moderation.hideFromReport(ReportTargetType.FORUM_COMMENT, targetId);
        }

        @Override
        public Optional<MediaPreview> preview(Long targetId) {
            return content.comment(targetId).filter(c -> !c.deleted())
                    .map(c -> MediaPreview.text(snippet(c.body(), 500)));
        }

        @Override
        public boolean reversible() {
            return true;
        }

        @Override
        public void unhide(Long targetId) {
            moderation.restoreFromReport(ReportTargetType.FORUM_COMMENT, targetId);
        }
    }
}
