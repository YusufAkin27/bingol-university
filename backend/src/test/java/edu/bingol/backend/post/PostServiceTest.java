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
import edu.bingol.backend.post.media.PostMedia;
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

    @Autowired edu.bingol.backend.post.media.PostMediaRepository mediaRepo;

    /** Akis/moderasyon testleri icin dogrudan fotografli gonderi (kurallar create* testlerinde). */
    private PostView post(User u, String text) {
        return service.get(u.getId(), PostFixtures.withPhoto(posts, mediaRepo, u.getId(), text).getId());
    }

    private Long uploaded(User u, String kind) {
        return PostFixtures.media(mediaRepo, u.getId(), null, kind).getId();
    }

    private static ApiException fails(Runnable r) {
        return assertThrows(ApiException.class, r::run);
    }

    @Test
    void createRequiresExactlyOnePhoto() {
        User a = newUser();
        assertEquals("POST_PHOTO_REQUIRED", fails(() -> service.create(a.getId(), new CreatePostRequest("merhaba", null))).code());
        assertEquals("POST_PHOTO_REQUIRED", fails(() -> service.create(a.getId(), new CreatePostRequest(null, List.of()))).code());
        Long i1 = uploaded(a, "IMAGE");
        Long i2 = uploaded(a, "IMAGE");
        assertEquals("POST_SINGLE_PHOTO_ONLY", fails(() -> service.create(a.getId(), new CreatePostRequest("x", List.of(i1, i2)))).code());
        assertEquals("POST_SINGLE_PHOTO_ONLY", fails(() -> service.create(a.getId(), new CreatePostRequest("x", List.of(i1, i1)))).code());
        Long vid = uploaded(a, "VIDEO");
        assertEquals("POST_VIDEO_NOT_ALLOWED", fails(() -> service.create(a.getId(), new CreatePostRequest("x", List.of(vid)))).code());
        User b = newUser();
        Long foreign = uploaded(b, "IMAGE");
        assertEquals("POST_MEDIA_INVALID", fails(() -> service.create(a.getId(), new CreatePostRequest(null, List.of(foreign)))).code());
        assertEquals("POST_MEDIA_INVALID", fails(() -> service.create(a.getId(), new CreatePostRequest(null, List.of(987654321L)))).code());
    }

    @Test
    void createWithSinglePhotoAndOptionalShortText() {
        User a = newUser();
        PostView noText = service.create(a.getId(), new CreatePostRequest("   ", List.of(uploaded(a, "IMAGE"))));
        assertNull(noText.text());
        assertEquals(1, noText.media().size());
        assertEquals("IMAGE", noText.media().get(0).kind());
        PostView v = service.create(a.getId(), new CreatePostRequest("  güzel bir gün  ", List.of(uploaded(a, "IMAGE"))));
        assertEquals("güzel bir gün", v.text());
        assertTrue(v.mine() && v.canEdit() && v.canDelete());
        Long used = v.media().get(0).id();
        assertEquals("POST_MEDIA_INVALID", fails(() -> service.create(a.getId(), new CreatePostRequest(null, List.of(used)))).code());
    }

    @Test
    void textRuleSevenWordsSixtyCharsSingleLine() {
        PostService.checkText(null);
        PostService.checkText("bir iki üç dört beş altı yedi");
        PostService.checkText("a".repeat(60));
        assertEquals("POST_TEXT_TOO_LONG", fails(() -> PostService.checkText("bir iki üç dört beş altı yedi sekiz")).code());
        assertEquals("POST_TEXT_TOO_LONG", fails(() -> PostService.checkText("a".repeat(61))).code());
        assertEquals("POST_TEXT_TOO_LONG", fails(() -> PostService.checkText("1\u00A02\u20093 4 5 6 7 8")).code());
        assertEquals("POST_TEXT_INVALID", fails(() -> PostService.checkText("iki\nsatir")).code());
        assertEquals("POST_TEXT_INVALID", fails(() -> PostService.checkText("iki\u2028satir")).code());
        User a = newUser();
        Long img = uploaded(a, "IMAGE");
        assertEquals("POST_TEXT_TOO_LONG", fails(() -> service.create(a.getId(),
                new CreatePostRequest("bir iki üç dört beş altı yedi sekiz", List.of(img)))).code());
        PostView ok = post(a, "tamam");
        assertEquals("POST_TEXT_TOO_LONG", fails(() -> service.update(a.getId(), ok.id(), "bir iki üç dört beş altı yedi sekiz")).code());
        assertEquals("POST_TEXT_INVALID", fails(() -> service.update(a.getId(), ok.id(), "a\nb")).code());
        assertNull(service.update(a.getId(), ok.id(), " ").text(), "fotografli gonderide metin silinebilir");
    }

    @Test
    void feedHidesPostsWithoutImageAndShowsOnlyFirstImage() {
        User a = newUser();
        User v = newUser();
        PostView photo = post(a, "foto");
        Post videoOnly = new Post();
        videoOnly.setAuthorId(a.getId());
        videoOnly.setMediaCount((short) 1);
        videoOnly = posts.saveAndFlush(videoOnly);
        PostMedia onlyVid = PostFixtures.media(mediaRepo, a.getId(), videoOnly.getId(), "VIDEO");
        Post textOnly = new Post();
        textOnly.setAuthorId(a.getId());
        textOnly.setBody("eski metin");
        textOnly = posts.saveAndFlush(textOnly);
        Post multi = new Post();
        multi.setAuthorId(a.getId());
        multi.setMediaCount((short) 3);
        multi = posts.saveAndFlush(multi);
        PostFixtures.media(mediaRepo, a.getId(), multi.getId(), "VIDEO");
        PostMedia im1 = PostFixtures.media(mediaRepo, a.getId(), multi.getId(), "IMAGE");
        im1.setPosition((short) 1);
        mediaRepo.saveAndFlush(im1);
        PostMedia im2 = PostFixtures.media(mediaRepo, a.getId(), multi.getId(), "IMAGE");
        im2.setPosition((short) 2);
        mediaRepo.saveAndFlush(im2);

        List<PostView> items = service.byAuthor(v.getId(), a.getId(), null, 20).items();
        List<Long> ids = items.stream().map(PostView::id).toList();
        assertTrue(ids.contains(photo.id()) && ids.contains(multi.getId()));
        assertFalse(ids.contains(videoOnly.getId()), "video-only akistan gizli");
        assertFalse(ids.contains(textOnly.getId()), "fotografsiz eski gonderi akistan gizli");
        Long hiddenId = videoOnly.getId();
        assertTrue(service.feed(v.getId(), "latest", null, 20).items().stream().noneMatch(i -> i.id().equals(hiddenId)));
        assertTrue(service.feed(v.getId(), "popular", null, 20).items().stream().noneMatch(i -> i.id().equals(hiddenId)));
        Long multiId = multi.getId();
        PostView m = items.stream().filter(i -> i.id().equals(multiId)).findFirst().orElseThrow();
        assertEquals(List.of(im1.getId()), m.media().stream().map(x -> x.id()).toList());
        assertTrue(posts.findById(hiddenId).isPresent() && mediaRepo.findById(onlyVid.getId()).isPresent(), "veri silinmedi");
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
        counters.incrementLikes(pv.id(), -5);
        PostView v = service.get(a.getId(), pv.id());
        assertEquals(0, v.likeCount());
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
