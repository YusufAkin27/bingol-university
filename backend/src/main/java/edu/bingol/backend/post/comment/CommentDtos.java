package edu.bingol.backend.post.comment;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;

public final class CommentDtos {

    private CommentDtos() {}

    public record CreateRequest(@NotNull @Size(max = 5000) String text, Long parentId) {}

    public record UpdateRequest(@NotNull @Size(max = 5000) String text) {}

    public record AuthorView(Long id, String displayName, String avatarUrl) {}

    public record ReplyToView(Long id, String displayName) {}

    /** Silinmis (yanitli) yorumda text ve author null, deleted true. */
    public record CommentView(Long id, Long postId, Long parentId, Long rootId, int depth, AuthorView author,
            ReplyToView replyToUser, String text, boolean deleted, int replyCount, boolean mine, boolean canEdit,
            boolean canDelete, Instant createdAt, Instant editedAt, List<CommentView> previewReplies,
            List<edu.bingol.backend.post.PostDtos.MentionView> mentions) {
        /** Eski kurucu (etiket yok). */
        public CommentView(Long id, Long postId, Long parentId, Long rootId, int depth, AuthorView author,
                ReplyToView replyToUser, String text, boolean deleted, int replyCount, boolean mine, boolean canEdit,
                boolean canDelete, Instant createdAt, Instant editedAt, List<CommentView> previewReplies) {
            this(id, postId, parentId, rootId, depth, author, replyToUser, text, deleted, replyCount, mine, canEdit,
                    canDelete, createdAt, editedAt, previewReplies, List.of());
        }
    }

    /** total: gonderideki silinmemis tum yorum+yanit sayisi (comment_count). */
    public record CommentPage(List<CommentView> items, String nextCursor, int total) {}

    public record ReplyPage(List<CommentView> items, String nextCursor) {}
}
