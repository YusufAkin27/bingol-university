package edu.bingol.backend.forum.comment;

import com.fasterxml.jackson.annotation.JsonInclude;
import edu.bingol.backend.forum.topic.dto.Author;
import java.time.Instant;
import java.util.List;

/** Forum yorum API sozlesmesi (docs/FORUM_API.md 2-B). Alan adlari sozlesmeyle BIREBIR. */
public final class ForumCommentDtos {

    private ForumCommentDtos() {}

    public static final int MAX_CHARS = 4000;
    public static final int DEFAULT_SIZE = 15;
    public static final int MAX_SIZE = 30;

    /**
     * Yorum gorunumu. Yazar A'nin {@code Author}'idir: anonimde userId/avatarUrl/department NULL, ad "Anonim #N". Silinmis/kaldirilmis yer tutucuda author ve body null, deleted=true.
     * replyPreview yalniz liste uclarinda (ilk 2 yanit), path yalniz GET /comments/{id}'de dolar.
     */
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public record CommentView(
            Long id,
            Long topicId,
            @JsonInclude(JsonInclude.Include.ALWAYS) Long parentCommentId,
            int depth,
            @JsonInclude(JsonInclude.Include.ALWAYS) Author author,
            @JsonInclude(JsonInclude.Include.ALWAYS) String body,
            boolean anonymous,
            Instant createdAt,
            @JsonInclude(JsonInclude.Include.ALWAYS) Instant editedAt,
            int likeCount,
            boolean likedByMe,
            boolean savedByMe,
            int replyCount,
            List<CommentView> replyPreview,
            boolean mine,
            boolean deleted,
            boolean canModerate,
            boolean topicAuthor,
            List<Long> path) {

        public CommentView withPreview(List<CommentView> preview) {
            return new CommentView(id, topicId, parentCommentId, depth, author, body, anonymous, createdAt, editedAt,
                    likeCount, likedByMe, savedByMe, replyCount, preview, mine, deleted, canModerate, topicAuthor, path);
        }

        public CommentView withPath(List<Long> p) {
            return new CommentView(id, topicId, parentCommentId, depth, author, body, anonymous, createdAt, editedAt,
                    likeCount, likedByMe, savedByMe, replyCount, replyPreview, mine, deleted, canModerate, topicAuthor, p);
        }
    }

    public record CommentPage(List<CommentView> items, String nextCursor) {}

    public record CreateCommentRequest(String body, Long parentCommentId, Boolean anonymous) {}

    public record EditCommentRequest(String body) {}

    public record LikeState(boolean liked, int likeCount) {}

    public record SaveState(boolean saved) {}
}
