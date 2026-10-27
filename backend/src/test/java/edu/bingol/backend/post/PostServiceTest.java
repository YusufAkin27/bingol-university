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
import edu.bingol.backend.post.PostDtos.CreatePostRequest;
import edu.bingol.backend.post.PostDtos.FeedPage;
import edu.bingol.backend.post.PostDtos.PostView;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

/** Gönderi akışı: oluşturma/doğrulama, imleç sayfalama, engel süzgeci, sayaç, puan işi, silme. */
@SpringBootTest
class PostServiceTest {

    @Autowired PostService service;
    @Autowired PostRepository posts;
    @Autowired UserRepository users;
    @Autowired UserBlockRepository blocks;
    @Autowired PostCounters counters;
    @Autowired PostScoreJob scoreJob;

    private User newUser() {
        User u = new User();
        u.setEmail("p" + UUID.randomUUID().toString().substring(0, 8) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName("Test Kullanici");
        u.setEmailVerified(true);
        return users.saveAndFlush(u);
    }

    private PostView post(User u, String text) {
        return service.create(u.getId(), new CreatePostRequest(text, null));
    }

    private static ApiException fails(Runnable r) {
        return assertThrows(ApiException.class, r::run);
    }

    @Test
    void createValidatesEmptyAndTooLong() {
        User a = newUser();
        assertEquals("POST_EMPTY", fails(() -> post(a, "   ")).code());
        assertEquals("POST_TOO_LONG", fails(() -> post(a, "x".repeat(2001))).code());
        assertEquals("POST_MEDIA_INVALID", fails(() -> service.create(a.getId(), new CreatePostRequest(null, List.of(1L)))).code());
        PostView v = post(a, "  merhaba  ");
        assertEquals("merhaba", v.text());
        assertTrue(v.mine() && v.canEdit() && v.canDelete());
        assertEquals(0, v.likeCount());
        assertTrue(v.media().isEmpty());
    }

    @Test
    void latestFeedPagesWithCursorWithoutDuplicates() {
        User a = newUser();
        User v = newUser();
        for (int i = 0; i < 5; i++) {
            post(a, "g" + i);
        }
        FeedPage p1 = service.byAuthor(v.getId(), a.getId(), null, 2);
        assertEquals(2, p1.items().size());
        assertNotNull(p1.nextCursor());
        FeedPage p2 = service.byAuthor(v.getId(), a.getId(), p1.nextCursor(), 2);
        FeedPage p3 = service.byAuthor(v.getId(), a.getId(), p2.nextCursor(), 2);
        assertEquals(1, p3.items().size());
        assertNull(p3.nextCursor());
        List<Long> ids = new java.util.ArrayList<>();
        for (FeedPage p : List.of(p1, p2, p3)) {
            p.items().forEach(i -> ids.add(i.id()));
        }
        assertEquals(5, ids.stream().distinct().count());
        assertTrue(ids.get(0) > ids.get(4), "yeniden eskiye");
        assertEquals("POST_CURSOR_INVALID", fails(() -> service.feed(v.getId(), "latest", "bozuk!", 5)).code());
    }

    @Test
    void blockHidesPostsBothWays() {
        User a = newUser();
        User b = newUser();
        PostView pv = post(a, "gizlenecek");
        assertEquals(1, service.byAuthor(b.getId(), a.getId(), null, 10).items().size());
        blocks.saveAndFlush(new UserBlock(b.getId(), a.getId()));
        assertTrue(service.byAuthor(b.getId(), a.getId(), null, 10).items().isEmpty());
        assertTrue(service.byAuthor(a.getId(), a.getId(), null, 10).items().size() >= 1);
        assertEquals("POST_NOT_FOUND", fails(() -> service.get(b.getId(), pv.id())).code());
        // ters yön: a, b'yi engelleyen taraf olsa da b'nin gönderisi a'dan gizlenir
        PostView pb = post(b, "b yazdi");
        assertEquals("POST_NOT_FOUND", fails(() -> service.get(a.getId(), pb.id())).code());
        assertTrue(service.feed(a.getId(), "latest", null, 20).items().stream().noneMatch(i -> i.id().equals(pb.id())));
    }

    @Test
    void hiddenDeletedAndInactiveAuthorsAreNotListed() {
        User a = newUser();
        User v = newUser();
        PostView hidden = post(a, "h");
        PostView gone = post(a, "d");
        PostView ok = post(a, "ok");
        Post h = posts.findById(hidden.id()).orElseThrow();
        h.setHiddenAt(Instant.now());
        posts.saveAndFlush(h);
        service.delete(a.getId(), gone.id(), false);
        List<Long> ids = service.byAuthor(v.getId(), a.getId(), null, 20).items().stream().map(PostView::id).toList();
        assertEquals(List.of(ok.id()), ids);
        a.setStatus(UserStatus.SUSPENDED);
        users.saveAndFlush(a);
        assertTrue(service.byAuthor(v.getId(), a.getId(), null, 20).items().isEmpty());
        assertEquals("POST_NOT_FOUND", fails(() -> service.get(v.getId(), ok.id())).code());
    }

    @Test
    void updateAndDeletePermissions() {
        User a = newUser();
        User b = newUser();
        PostView pv = post(a, "ilk");
        assertEquals("POST_FORBIDDEN", fails(() -> service.update(b.getId(), pv.id(), "x")).code());
        assertEquals("POST_FORBIDDEN", fails(() -> service.delete(b.getId(), pv.id(), false)).code());
        PostView up = service.update(a.getId(), pv.id(), "ikinci");
        assertEquals("ikinci", up.text());
        assertNotNull(up.editedAt());
        assertEquals("POST_EMPTY", fails(() -> service.update(a.getId(), pv.id(), " ")).code());
        PostView other = service.get(b.getId(), pv.id());
        assertFalse(other.mine() || other.canEdit() || other.canDelete());
        service.delete(b.getId(), pv.id(), true);
        assertEquals("POST_NOT_FOUND", fails(() -> service.get(a.getId(), pv.id())).code());
        assertEquals("POST_NOT_FOUND", fails(() -> service.delete(a.getId(), pv.id(), false)).code());
    }

    @Test
    void countersAreAtomicAndNeverNegative() {
        User a = newUser();
        PostView pv = post(a, "sayac");
        counters.incrementLikes(pv.id(), 1);
        counters.incrementLikes(pv.id(), 1);
        counters.incrementComments(pv.id(), 3);
        counters.incrementLikes(pv.id(), -5);
        PostView v = service.get(a.getId(), pv.id());
        assertEquals(0, v.likeCount());
        assertEquals(3, v.commentCount());
        counters.incrementLikes(pv.id(), 2);
        assertEquals(2, counters.likeCount(pv.id()));
    }

    @Test
    void popularOrdersByScoreAndScoreJobUpdates() {
        User a = newUser();
        User v = newUser();
        PostView low = post(a, "dusuk");
        PostView high = post(a, "yuksek");
        counters.incrementLikes(high.id(), 10);
        counters.incrementComments(high.id(), 5);
        scoreJob.recompute();
        List<Long> ids = service.feed(v.getId(), "popular", null, 20).items().stream().map(PostView::id).toList();
        assertTrue(ids.indexOf(high.id()) >= 0 && ids.indexOf(high.id()) < ids.indexOf(low.id()));
        // popüler imleç ikinci sayfaya geçer
        FeedPage p1 = service.feed(v.getId(), "popular", null, 1);
        assertNotNull(p1.nextCursor());
        FeedPage p2 = service.feed(v.getId(), "popular", p1.nextCursor(), 1);
        assertFalse(p2.items().isEmpty());
        assertFalse(p2.items().get(0).id().equals(p1.items().get(0).id()));
        // 7 günden eski gönderi popülerde yok ve puanı sıfırlanır
        Post old = posts.findById(low.id()).orElseThrow();
        old.setCreatedAt(Instant.now().minus(10, ChronoUnit.DAYS));
        old.setScore(5);
        posts.saveAndFlush(old);
        scoreJob.recompute();
        assertEquals(0.0, posts.findById(low.id()).orElseThrow().getScore());
        assertTrue(service.feed(v.getId(), "popular", null, 20).items().stream().noneMatch(i -> i.id().equals(low.id())));
    }

    @Test
    void scoreFormula() {
        assertEquals(0.0, PostScore.compute(0, 0, 3));
        assertTrue(PostScore.compute(5, 0, 1) > PostScore.compute(5, 0, 10));
        assertTrue(PostScore.compute(0, 3, 2) > PostScore.compute(3, 0, 2));
    }
}
