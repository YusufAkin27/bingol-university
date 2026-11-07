package edu.bingol.backend.forum.topic.dto;

import edu.bingol.backend.forum.poll.spi.PollView;
import java.time.Instant;
import java.util.List;

/** Konu detayi (sozlesme A: TopicView = TopicSummary + body, images, poll, canEdit, canDelete, notificationsEnabled). */
public record TopicView(Long id, String title, String bodyPreview, CategoryRef category, Author author,
                        Instant createdAt, Instant editedAt, int likeCount, int commentCount, boolean likedByMe,
                        boolean savedByMe, boolean followedByMe, ImageView thumbnail, int imageCount,
                        boolean hasPoll, boolean pinned, boolean locked, boolean mine, boolean canModerate,
                        String status, String body, List<ImageView> images, PollView poll, boolean canEdit,
                        boolean canDelete, boolean notificationsEnabled) {

    public static TopicView of(TopicSummary s, String body, List<ImageView> images, PollView poll, boolean canEdit,
                               boolean canDelete, boolean notificationsEnabled) {
        return new TopicView(s.id(), s.title(), s.bodyPreview(), s.category(), s.author(), s.createdAt(),
                s.editedAt(), s.likeCount(), s.commentCount(), s.likedByMe(), s.savedByMe(), s.followedByMe(),
                s.thumbnail(), s.imageCount(), s.hasPoll(), s.pinned(), s.locked(), s.mine(), s.canModerate(),
                s.status(), body, images, poll, canEdit, canDelete, notificationsEnabled);
    }
}
