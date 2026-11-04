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

    /**
     * Yazar: takipci sayisi ve populerlik puani (0..100) gercek sayilardan turetilir; gizli hesapta bile gonderi
     * gorunuyorsa (kabul edilmis takipci/sahibi) yazar da gorunurdur, sayilar kisitlanmaz.
     */
    public record AuthorView(Long id, String displayName, String avatarUrl, String department, Integer followerCount,
                             Integer popularityScore) {
        public AuthorView(Long id, String displayName, String avatarUrl, String department) {
            this(id, displayName, avatarUrl, department, null, null);
        }
    }

    /** Video gonderisinin oynatma bilgisi: url oturumlu (Range destekli), posterUrl ilk kare (yoksa null). */
    public record VideoView(Long id, String url, String posterUrl, Integer durationMs, Integer width, Integer height) {}

    /**
     * Gonderi gorunumu: 1 fotograf VEYA 1 video + kisa metin + begeni. type = PHOTO | VIDEO; video yalniz VIDEO'da
     * dolar (media listesinde de ayni medya vardir). popularityScore 0..100 (yastan bagimsiz etkilesim puani),
     * viewCount yalniz videoda.
     */
    public record PostView(Long id, AuthorView author, String text, List<MediaView> media, int likeCount,
                           boolean likedByMe, boolean mine, boolean canEdit, boolean canDelete,
                           Instant createdAt, Instant editedAt, String type,
                           @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL) VideoView video,
                           @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL) Integer viewCount,
                           Integer popularityScore) {}

    public record CreatePostRequest(@Size(max = 1000) String text, @Size(max = 10) List<Long> mediaIds) {}

    public record UpdatePostRequest(@Size(max = 1000) String text) {}

    /**
     * Akis sayfasi: nextCursor opak metin (null = son sayfa). exhausted yalniz Kesfet/Reels akisinda: true = tum
     * havuz bu kullanici icin gorulmustu, sayfa en eski gorulmuslerden tekrar edilerek dolduruldu.
     */
    public record FeedPage(List<PostView> items, String nextCursor, String hint,
                           @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL) Boolean locked,
                           @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL) Boolean exhausted) {
        public FeedPage(List<PostView> items, String nextCursor, String hint,
                        Boolean locked) {
            this(items, nextCursor, hint, locked, null);
        }

        public FeedPage(List<PostView> items, String nextCursor, String hint) {
            this(items, nextCursor, hint, null, null);
        }

        public FeedPage(List<PostView> items, String nextCursor) {
            this(items, nextCursor, null, null, null);
        }

        /** Gizli hesabin gonderi listesi bakana kapali: bos + locked=true (403 degil). */
        public static FeedPage lockedPage() {
            return new FeedPage(List.of(), null, null, true, null);
        }

        public FeedPage withExhausted(boolean ex) {
            return new FeedPage(items, nextCursor, hint, locked, ex);
        }
    }

    /** POST /api/feed/seen govdesi: gorunen gonderi/reel kimlikleri (en cok 100). */
    public record SeenRequest(@jakarta.validation.constraints.NotNull @Size(max = 100) List<Long> ids) {}

    /** POST /api/posts/{id}/view govdesi: izlenen sure ve video suresi (ms). */
    public record ViewRequest(@jakarta.validation.constraints.Min(0) @jakarta.validation.constraints.Max(86_400_000) long watchedMs,
                              @jakarta.validation.constraints.Min(0) @jakarta.validation.constraints.Max(86_400_000) long durationMs) {}
}
