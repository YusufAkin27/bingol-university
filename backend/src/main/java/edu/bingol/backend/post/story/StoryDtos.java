package edu.bingol.backend.post.story;

import edu.bingol.backend.post.PostDtos.MediaView;
import java.time.Instant;
import java.util.List;

/** Hikaye API sozlesmesi (docs/API_CONTRACTS_V2.md). */
public final class StoryDtos {

    private StoryDtos() {}

    public static final int MAX_TEXT = 200;

    /** mediaId varsa IMAGE/VIDEO, yoksa text zorunlu (TEXT). background: #RRGGBB (yalniz TEXT). */
    public record CreateRequest(Long mediaId, String text, String caption, String background) {}

    public record AuthorView(Long id, String displayName, String avatarUrl) {}

    /** viewCount yalniz sahibe doner (baskasi icin null). */
    public record StoryView(Long id, AuthorView author, String kind, MediaView media, String text, String caption,
                            String background, Instant createdAt, Instant expiresAt, boolean viewedByMe,
                            Integer viewCount, boolean mine) {}

    public record TrayItem(AuthorView user, boolean hasUnseen, Instant latestAt, int count, boolean mine) {}

    public record Viewer(Long id, String displayName, String avatarUrl, Instant viewedAt) {}

    public record ViewerPage(List<Viewer> items, String nextCursor, int total) {}
}
