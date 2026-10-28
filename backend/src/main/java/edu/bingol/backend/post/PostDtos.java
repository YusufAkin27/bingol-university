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

    /** Etiketlenen kullanici (metindeki @[Ad](uid:N) biciminden dogrulanmis). */
    public record MentionView(Long id, String displayName) {}

    public record PostView(Long id, AuthorView author, String text, List<MediaView> media, int likeCount,
                           int commentCount, boolean likedByMe, boolean mine, boolean canEdit, boolean canDelete,
                           Instant createdAt, Instant editedAt, boolean savedByMe, List<MentionView> mentions,
                           List<String> hashtags) {
        /** Eski 12 alanli kurucu (sosyal alanlar bos). */
        public PostView(Long id, AuthorView author, String text, List<MediaView> media, int likeCount,
                        int commentCount, boolean likedByMe, boolean mine, boolean canEdit, boolean canDelete,
                        Instant createdAt, Instant editedAt) {
            this(id, author, text, media, likeCount, commentCount, likedByMe, mine, canEdit, canDelete, createdAt,
                    editedAt, false, List.of(), List.of());
        }
    }

    public record CreatePostRequest(@Size(max = 1000) String text, @Size(max = 10) List<Long> mediaIds) {}

    public record UpdatePostRequest(@Size(max = 1000) String text) {}

    /** Akis sayfasi: nextCursor opak metin (null = son sayfa). */
    public record FeedPage(List<PostView> items, String nextCursor, String hint) {
        public FeedPage(List<PostView> items, String nextCursor) {
            this(items, nextCursor, null);
        }
    }
}
