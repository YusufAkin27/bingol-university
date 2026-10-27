package edu.bingol.backend.post.like;

import java.time.Instant;
import java.util.List;

public final class PostLikeDtos {

    private PostLikeDtos() {}

    /** PUT/DELETE /api/posts/{id}/like yaniti. */
    public record LikeState(boolean liked, int likeCount) {}

    public record Liker(Long id, String displayName, String avatarUrl, Instant likedAt) {}

    public record LikersPage(List<Liker> items, String nextCursor, long total) {}
}
