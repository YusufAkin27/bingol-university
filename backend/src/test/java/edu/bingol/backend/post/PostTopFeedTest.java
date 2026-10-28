package edu.bingol.backend.post;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.moderation.UserBlock;
import edu.bingol.backend.moderation.UserBlockRepository;
import edu.bingol.backend.post.PostDtos.FeedPage;
import edu.bingol.backend.post.PostDtos.PostView;
import edu.bingol.backend.post.media.PostMediaRepository;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

/** Keşfet scope=top: puana göre sıralama, keyset sayfalama (kopya/atlama yok), süzgeçler. */
@SpringBootTest
class PostTopFeedTest {

    @Autowired PostService service;
    @Autowired PostRepository posts;
    @Autowired PostMediaRepository mediaRepo;
    @Autowired UserRepository users;
    @Autowired UserBlockRepository blocks;
    @Autowired PostRankService rank;

    private User newUser() {
        User u = new User();
        u.setEmail("t" + UUID.randomUUID().toString().substring(0, 8) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName("Test Kullanici");
        u.setEmailVerified(true);
        return users.saveAndFlush(u);
    }

    private Post photoPost(User author, int likes) {
        Post p = PostFixtures.withPhoto(posts, mediaRepo, author.getId(), "t");
        p.setLikeCount(likes);
        return posts.saveAndFlush(p);
    }

    /** Tum sayfalari gezer; her sayfanin boyutunu ve imlec zincirini doğrular. */
    private List<Long> walk(Long viewer, int size, int maxPages) {
        List<Long> ids = new ArrayList<>();
        String cursor = null;
        for (int i = 0; i < maxPages; i++) {
            FeedPage page = service.feed(viewer, "top", cursor, size);
            assertTrue(page.items().size() <= size);
            page.items().forEach(v -> ids.add(v.id()));
            cursor = page.nextCursor();
            if (cursor == null) {
                return ids;
            }
            assertEquals(size, page.items().size(), "dolu sayfa -> imlec");
        }
        throw new AssertionError("sayfalama bitmedi");
    }

    @Test
    void ordersByLikesAndPagesWithoutDuplicatesOrGaps() {
        User viewer = newUser();
        List<Post> mine = new ArrayList<>();
        for (int i = 0; i < 7; i++) {
            mine.add(photoPost(newUser(), i * 3)); // 0,3,...,18 begeni; her biri ayri yazar
        }
        rank.recompute();

        List<Long> all = walk(viewer.getId(), 3, 200);
        assertEquals(new HashSet<>(all).size(), all.size(), "kopya yok");
        for (Post p : mine) {
            assertTrue(all.contains(p.getId()), "atlama yok: " + p.getId());
        }
        // ayni yasta (yaklasik) gonderilerde cok begenilen once gelir
        for (int i = 1; i < mine.size(); i++) {
            assertTrue(all.indexOf(mine.get(i).getId()) < all.indexOf(mine.get(i - 1).getId()),
                    "daha cok begeni daha ustte");
        }
    }

    @Test
    void firstThreePagesAreStableAndLastPageHasNoCursor() {
        User viewer = newUser();
        for (int i = 0; i < 8; i++) {
            photoPost(newUser(), i);
        }
        rank.recompute();
        FeedPage p1 = service.feed(viewer.getId(), "top", null, 2);
        FeedPage p2 = service.feed(viewer.getId(), "top", p1.nextCursor(), 2);
        FeedPage p3 = service.feed(viewer.getId(), "top", p2.nextCursor(), 2);
        Set<Long> seen = new HashSet<>();
        for (FeedPage p : List.of(p1, p2, p3)) {
            assertEquals(2, p.items().size());
            for (PostView v : p.items()) {
                assertTrue(seen.add(v.id()), "kopya: " + v.id());
            }
        }
        assertNull(p1.hint());
        assertNotNull(p3.nextCursor());
        // sonsuz zincir degil: sonunda imlec biter
        assertFalse(walk(viewer.getId(), 30, 500).isEmpty());
    }

    @Test
    void sizeDefaultsTo12AndIsCappedAt30() {
        User viewer = newUser();
        for (int i = 0; i < 32; i++) {
            photoPost(newUser(), 0);
        }
        rank.recompute();
        assertEquals(12, service.feed(viewer.getId(), "top", null, 0).items().size());
        assertEquals(30, service.feed(viewer.getId(), "top", null, 100).items().size());
    }

    @Test
    void blockedAuthorAndVideoOnlyAreFilteredOut() {
        User viewer = newUser();
        User blocked = newUser();
        User ok = newUser();
        Post b = photoPost(blocked, 50);
        Post g = photoPost(ok, 1);
        Post videoOnly = new Post();
        videoOnly.setAuthorId(ok.getId());
        videoOnly.setBody("v");
        videoOnly.setMediaCount((short) 1);
        videoOnly = posts.saveAndFlush(videoOnly);
        PostFixtures.media(mediaRepo, ok.getId(), videoOnly.getId(), "VIDEO");
        blocks.saveAndFlush(new UserBlock(viewer.getId(), blocked.getId()));
        rank.recompute();

        List<Long> all = walk(viewer.getId(), 30, 200);
        assertFalse(all.contains(b.getId()), "engelli yazar");
        assertFalse(all.contains(videoOnly.getId()), "video-only gizli");
        assertTrue(all.contains(g.getId()));
    }

    @Test
    void newPostWithoutLikesIsVisibleViaColdStart() {
        User viewer = newUser();
        Post fresh = photoPost(newUser(), 0);
        fresh.setRankScore(rank.initialScore(fresh));
        posts.saveAndFlush(fresh);
        assertTrue(fresh.getRankScore() > 0);
        List<Long> first = new ArrayList<>();
        service.feed(viewer.getId(), "top", null, 30).items().forEach(v -> first.add(v.id()));
        assertTrue(first.contains(fresh.getId()) || walk(viewer.getId(), 30, 200).contains(fresh.getId()));
    }

    @Test
    void invalidCursorIsRejectedAndScoreIsNotExposed() {
        User viewer = newUser();
        assertEquals("POST_CURSOR_INVALID",
                assertThrows(ApiException.class, () -> service.feed(viewer.getId(), "top", "bozuk", 5)).code());
        String latest = PostCursor.latest(java.time.Instant.now(), 5);
        assertEquals("POST_CURSOR_INVALID",
                assertThrows(ApiException.class, () -> service.feed(viewer.getId(), "top", latest, 5)).code());
        assertTrue(java.util.Arrays.stream(PostView.class.getRecordComponents())
                .noneMatch(c -> c.getName().toLowerCase().contains("rank")));
    }

    @Test
    void existingScopesStillWork() {
        User viewer = newUser();
        photoPost(newUser(), 3);
        rank.recompute();
        assertFalse(service.feed(viewer.getId(), "latest", null, 5).items().isEmpty());
        service.feed(viewer.getId(), "popular", null, 5);
    }
}
