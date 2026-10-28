package edu.bingol.backend.post;

import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;

/** Gonderi API sozlesmesi (docs/POSTS_DESIGN.md). */
public final class PostDtos {

    private PostDtos() {}

    /** Eski ust sinir (yalniz geri uyum); yeni gonderi kurali MAX_WORDS/MAX_CHARS. */
    public static final int MAX_TEXT = 2000;
    /** Sade gonderi metni: en cok 7 kelime ve 60 karakter, tek satir. */
    public static final int MAX_WORDS = 7;
    public static final int MAX_CHARS = 60;

    /** Medya gorunumu (B uretir). url: /api/posts/media/{id}, thumbUrl: ...?thumb=true. */
    public record MediaView(Long id, String kind, String url, String thumbUrl, Integer width, Integer height,
                            Integer durationMs) {}

    public record AuthorView(Long id, String displayName, String avatarUrl, String department) {}

    /** Sade gonderi gorunumu: 1 fotograf + kisa metin + begeni (yorum/kaydet/etiket/bahsetme kaldirildi). */
    public record PostView(Long id, AuthorView author, String text, List<MediaView> media, int likeCount,
                           boolean likedByMe, boolean mine, boolean canEdit, boolean canDelete,
                           Instant createdAt, Instant editedAt) {}

    public record CreatePostRequest(@Size(max = 1000) String text, @Size(max = 10) List<Long> mediaIds) {}

    public record UpdatePostRequest(@Size(max = 1000) String text) {}

    /** Akis sayfasi: nextCursor opak metin (null = son sayfa). */
    public record FeedPage(List<PostView> items, String nextCursor, String hint) {
        public FeedPage(List<PostView> items, String nextCursor) {
            this(items, nextCursor, null);
        }
    }
}
