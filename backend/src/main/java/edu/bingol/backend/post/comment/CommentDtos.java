package edu.bingol.backend.post.comment;

import com.fasterxml.jackson.annotation.JsonInclude;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;

/** Yorum API sozlesmesi (docs/changes/post.md "KS-BE2"). */
public final class CommentDtos {

    private CommentDtos() {}

    /** Yorum metni ust siniri (Unicode kod noktasi). */
    public static final int MAX_CHARS = 300;

    /** @Size yalniz kaba ust sinir; asil kural (300 kod noktasi) serviste. parentId: yanitlanan yorum (yanita yanit yassilanir). */
    public record CreateCommentRequest(@Size(max = 2000) String text, Long parentId) {}

    public record CommentAuthor(Long id, String displayName, String avatarUrl, String department) {}

    /** Yanitin asil muhatabi (yanita verilen yanitta "@ad"); ust duzey yoruma yanitta yok. */
    public record ReplyTo(Long commentId, Long authorId, String displayName) {}

    public record CommentView(Long id, Long postId, Long parentId, CommentAuthor author, String text, int likeCount,
                              boolean likedByMe, int replyCount, Instant createdAt, boolean mine, boolean byPostAuthor,
                              boolean canDelete, @JsonInclude(JsonInclude.Include.NON_NULL) ReplyTo replyTo) {}

    /** total: gonderideki gorunur yorum + yanit sayisi (PostView.commentCount ile ayni). */
    public record CommentPage(List<CommentView> items, String nextCursor, long total) {}

    public record LikeState(boolean liked, int likeCount) {}
}
