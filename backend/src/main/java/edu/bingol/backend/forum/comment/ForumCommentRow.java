package edu.bingol.backend.forum.comment;

import java.time.Instant;

/** forum_comment satirinin salt okunur gorunumu (JDBC; entity onbellegi ile atomik UPDATE'ler karismasin). */
record ForumCommentRow(long id, long topicId, long userId, Long parentId, Long rootId, int depth, String body,
                       boolean anonymous, int likeCount, int replyCount, String status, String removedReason,
                       Instant createdAt, Instant editedAt, Instant deletedAt) {

    /** Normal yanitlarda icerigiyle gorunur: silinmemis ve kaldirilmamis. */
    boolean live() {
        return deletedAt == null && ForumComment.ACTIVE.equals(status);
    }

    boolean removed() {
        return ForumComment.REMOVED.equals(status);
    }

    boolean deleted() {
        return deletedAt != null;
    }

    /** Listelerde yer alir: canli, ya da altinda listelenen yaniti olan yer tutucu. */
    boolean listed() {
        return live() || replyCount > 0;
    }
}
