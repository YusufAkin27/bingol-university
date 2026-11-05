package edu.bingol.backend.post.like;

import edu.bingol.backend.post.Post;
import edu.bingol.backend.post.PostCursor;
import edu.bingol.backend.post.PostDtos.FeedPage;
import edu.bingol.backend.post.PostViewAssembler;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Ayarlar > "Begendiklerim": kullanicinin begendigi gonderiler ve Reels (begeni anina gore, imlecli). */
@Service
public class LikedPostsService {

    static final int DEFAULT_SIZE = 12;
    static final int MAX_SIZE = 24;

    private final PostLikeRepository likes;
    private final PostViewAssembler assembler;

    public LikedPostsService(PostLikeRepository likes, PostViewAssembler assembler) {
        this.likes = likes;
        this.assembler = assembler;
    }

    /** kind: ALL | PHOTO | VIDEO (bos/bilinmeyen = ALL). Bozuk imlec 400 POST_CURSOR_INVALID. */
    @Transactional(readOnly = true)
    public FeedPage liked(Long viewer, String kind, String cursor, int size) {
        int n = size <= 0 ? DEFAULT_SIZE : Math.min(size, MAX_SIZE);
        String k = normalizeKind(kind);
        PostCursor c = PostCursor.decode(cursor, 'L');
        List<Object[]> rows = c == null
                ? likes.likedFirst(viewer, k, PageRequest.of(0, n + 1))
                : likes.likedAfter(viewer, k, c.at(), c.id(), PageRequest.of(0, n + 1));
        boolean more = rows.size() > n;
        List<Object[]> page = more ? rows.subList(0, n) : rows;
        List<Post> posts = new ArrayList<>(page.size());
        for (Object[] r : page) {
            posts.add((Post) r[0]);
        }
        String next = null;
        if (more && !page.isEmpty()) {
            Object[] last = page.get(page.size() - 1);
            next = PostCursor.latest((Instant) last[1], ((Post) last[0]).getId());
        }
        return new FeedPage(assembler.assemble(viewer, posts), next);
    }

    static String normalizeKind(String kind) {
        if (kind == null) {
            return "ALL";
        }
        String u = kind.trim().toUpperCase(java.util.Locale.ROOT);
        return "PHOTO".equals(u) || "VIDEO".equals(u) ? u : "ALL";
    }
}
