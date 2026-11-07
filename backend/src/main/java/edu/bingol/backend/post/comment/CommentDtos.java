package edu.bingol.backend.post.comment;

import com.fasterxml.jackson.annotation.JsonAlias;
import com.fasterxml.jackson.annotation.JsonInclude;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;

/** Yorum API sozlesmesi (docs/changes/post.md "KS-BE2" + "Yorum sozlesmesi 2026-11-07"). */
public final class CommentDtos {

    private CommentDtos() {}

    /** Yorum metni ust siniri (Unicode kod noktasi). */
    public static final int MAX_CHARS = 500;

    /**
     * @Size yalniz kaba ust sinir; asil kural (500 kod noktasi) serviste. Govde `body` (sozlesme) ya da eski `text`
     * adiyla gelebilir. parentId: ust duzey yorum (yanita yanit YOK: parentId bir yanitsa 400 COMMENT_PARENT_INVALID).
     */
    public record CreateCommentRequest(@JsonAlias("body") @Size(max = 2000) String text, Long parentId) {}

    /** id ile userId ayni kimliktir (userId sozlesme adi, id eski istemciler icin); username atanmamissa null. */
    public record CommentAuthor(Long id, String displayName, String avatarUrl, String department, Long userId,
                                String username) {}

    /** Eski alan: artik hic doldurulmaz (yanita yanit yok); eski istemci uyumu icin kaldi. */
    public record ReplyTo(Long commentId, Long authorId, String displayName) {}

    /**
     * deleted=true (yanitlari suren silinmis ust yorum, tombstone): author/text/body null, likeCount 0, mine/canDelete
     * false. body ile text ayni metindir (body sozlesme adi).
     */
    public record CommentView(Long id, Long postId, Long parentId, CommentAuthor author, String text, int likeCount,
                              boolean likedByMe, int replyCount, Instant createdAt, boolean mine, boolean byPostAuthor,
                              boolean canDelete, @JsonInclude(JsonInclude.Include.NON_NULL) ReplyTo replyTo,
                              String body, boolean deleted) {}

    /** total: gonderideki gorunur yorum + yanit sayisi (PostView.commentCount ile ayni). */
    public record CommentPage(List<CommentView> items, String nextCursor, long total) {}

    public record LikeState(boolean liked, int likeCount) {}
}
