package edu.bingol.backend.post.like;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.moderation.UserBlock;
import edu.bingol.backend.moderation.UserBlockRepository;
import edu.bingol.backend.post.Post;
import edu.bingol.backend.post.PostDtos.FeedPage;
import edu.bingol.backend.post.PostDtos.PostView;
import edu.bingol.backend.post.PostFixtures;
import edu.bingol.backend.post.PostRepository;
import edu.bingol.backend.post.media.PostMediaRepository;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

/** "Begendiklerim": begeni anina gore sira, imlec, tur suzgeci (ALL/PHOTO/VIDEO) ve gorunurluk (H2). */
@SpringBootTest
class LikedPostsServiceTest {

    @MockitoBean edu.bingol.backend.common.RateLimiter limiter;

    @Autowired LikedPostsService liked;
    @Autowired PostLikeRepository likes;
    @Autowired PostRepository posts;
    @Autowired PostMediaRepository mediaRepo;
    @Autowired UserRepository users;
    @Autowired UserBlockRepository blocks;
    @Autowired JdbcTemplate jdbc;

    private User user(String name) {
        User u = new User();
        u.setEmail(name + "-" + UUID.randomUUID() + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName(name);
        u.setEmailVerified(true);
        return users.save(u);
    }

    private void like(User who, Post p, long secondsAgo) {
        likes.saveAndFlush(new PostLike(p.getId(), who.getId()));
        jdbc.update("UPDATE post_like SET created_at = ? WHERE post_id = ? AND user_id = ?",
                java.sql.Timestamp.from(Instant.now().minusSeconds(secondsAgo)), p.getId(), who.getId());
    }

    private static List<Long> ids(FeedPage page) {
        return page.items().stream().map(PostView::id).toList();
    }

    @Test
    void listsNewestLikeFirstWithCursorAndKindFilter() {
        User author = user("yazar");
        User me = user("ben");
        Post photoOld = PostFixtures.withPhoto(posts, mediaRepo, author.getId(), "eski");
        Post video = PostFixtures.withVideo(posts, mediaRepo, author.getId(), "reel");
        Post photoNew = PostFixtures.withPhoto(posts, mediaRepo, author.getId(), "yeni");
        Post notLiked = PostFixtures.withPhoto(posts, mediaRepo, author.getId(), "begenilmedi");
        like(me, photoOld, 300);
        like(me, video, 200);
        like(me, photoNew, 100);

        FeedPage p1 = liked.liked(me.getId(), "ALL", null, 2);
        assertEquals(List.of(photoNew.getId(), video.getId()), ids(p1));
        assertNotNull(p1.nextCursor());
        FeedPage p2 = liked.liked(me.getId(), "ALL", p1.nextCursor(), 2);
        assertEquals(List.of(photoOld.getId()), ids(p2));
        assertNull(p2.nextCursor());

        assertEquals(List.of(video.getId()), ids(liked.liked(me.getId(), "video", null, 10)));
        assertEquals(List.of(photoNew.getId(), photoOld.getId()), ids(liked.liked(me.getId(), "PHOTO", null, 10)));
        assertEquals(3, liked.liked(me.getId(), "bilinmeyen", null, 10).items().size(), "bilinmeyen tur = ALL");
        assertTrue(!ids(liked.liked(me.getId(), "ALL", null, 10)).contains(notLiked.getId()));
    }

    @Test
    void hiddenAndBlockedAuthorPostsAreNotListed() {
        User author = user("yazar");
        User other = user("diger");
        User me = user("ben");
        Post visible = PostFixtures.withPhoto(posts, mediaRepo, author.getId(), "gorunur");
        Post hidden = PostFixtures.withPhoto(posts, mediaRepo, author.getId(), "gizli");
        Post fromBlocked = PostFixtures.withPhoto(posts, mediaRepo, other.getId(), "engelli");
        like(me, visible, 30);
        like(me, hidden, 20);
        like(me, fromBlocked, 10);
        hidden.setHiddenAt(Instant.now());
        posts.save(hidden);
        blocks.save(new UserBlock(me.getId(), other.getId()));

        assertEquals(List.of(visible.getId()), ids(liked.liked(me.getId(), "ALL", null, 10)));
    }

    @Test
    void onlyOwnLikesAreListed() {
        User author = user("yazar");
        User me = user("ben");
        User someone = user("baska");
        Post p = PostFixtures.withPhoto(posts, mediaRepo, author.getId(), "x");
        like(someone, p, 10);
        assertTrue(liked.liked(me.getId(), "ALL", null, 10).items().isEmpty());
    }
}
