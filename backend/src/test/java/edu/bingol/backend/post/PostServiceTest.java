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
    void createRequiresAtLeastOneMediaAndValidatesOwnership() {
        User a = newUser();
        assertEquals("POST_PHOTO_REQUIRED", fails(() -> service.create(a.getId(), new CreatePostRequest("merhaba", null))).code());
        assertEquals("POST_PHOTO_REQUIRED", fails(() -> service.create(a.getId(), new CreatePostRequest(null, List.of()))).code());
        Long i1 = uploaded(a, "IMAGE");
        assertEquals("POST_MEDIA_INVALID", fails(() -> service.create(a.getId(), new CreatePostRequest("x", List.of(i1, i1)))).code(),
                "ayni medya iki kez");
        Long vid = uploaded(a, "VIDEO");
        Long vid2 = uploaded(a, "VIDEO");
        assertEquals("POST_MEDIA_MIX", fails(() -> service.create(a.getId(), new CreatePostRequest("x", List.of(vid, vid2)))).code(),
                "video tek basina");
        assertEquals("POST_MEDIA_MIX", fails(() -> service.create(a.getId(), new CreatePostRequest("x", List.of(i1, vid)))).code(),
                "fotograf + video birlikte olmaz");
        User b = newUser();
        Long foreign = uploaded(b, "IMAGE");
        assertEquals("POST_MEDIA_INVALID", fails(() -> service.create(a.getId(), new CreatePostRequest(null, List.of(foreign)))).code());
        assertEquals("POST_MEDIA_INVALID", fails(() -> service.create(a.getId(), new CreatePostRequest(null, List.of(i1, foreign)))).code(),
                "baskasinin medyasi kismen de olsa reddedilir; hicbiri baglanmaz");
        assertEquals("POST_MEDIA_INVALID", fails(() -> service.create(a.getId(), new CreatePostRequest(null, List.of(987654321L)))).code());
    }

    @Test
    void createWithSeveralPhotosKeepsOrderAndMediaCount() {
        User a = newUser();
        Long m1 = uploaded(a, "IMAGE");
        Long m2 = uploaded(a, "IMAGE");
        Long m3 = uploaded(a, "IMAGE");
        PostView v = service.create(a.getId(), new CreatePostRequest("üç kare", List.of(m3, m1, m2)));
        assertEquals("PHOTO", v.type());
        assertEquals(List.of(m3, m1, m2), v.media().stream().map(PostDtos.MediaView::id).toList());
        assertEquals(List.of(0, 1, 2), v.media().stream().map(PostDtos.MediaView::position).toList());
        assertEquals(3, posts.findById(v.id()).orElseThrow().getMediaCount());
        // liste/akis yolu da ayni sirayi verir
        PostView got = service.get(a.getId(), v.id());
        assertEquals(3, got.media().size());
        assertEquals(m3, got.media().get(0).id());
    }

    @Test
    void createRejectsMoreThanTenPhotos() {
        User a = newUser();
        List<Long> ids = new java.util.ArrayList<>();
        for (int i = 0; i < 11; i++) {
            ids.add(uploaded(a, "IMAGE"));
        }
        assertEquals("POST_MEDIA_LIMIT", fails(() -> service.create(a.getId(), new CreatePostRequest("x", ids))).code());
        PostView ok = service.create(a.getId(), new CreatePostRequest("x", ids.subList(0, 10)));
        assertEquals(10, ok.media().size());
    }

    @Test
    void createVideoPostIsTypedVideoAndCarriesVideoView() {
        User a = newUser();
        Long vid = uploaded(a, "VIDEO");
        PostView v = service.create(a.getId(), new CreatePostRequest("kısa klip", List.of(vid)));
        assertEquals("VIDEO", v.type());
        assertEquals("VIDEO", v.media().get(0).kind());
        org.junit.jupiter.api.Assertions.assertNotNull(v.video());
        assertEquals("/api/posts/media/" + vid, v.video().url());
        assertEquals(0, v.viewCount());
        assertEquals("VIDEO", posts.findById(v.id()).orElseThrow().getKind());
        PostView photo = service.create(a.getId(), new CreatePostRequest(null, List.of(uploaded(a, "IMAGE"))));
        assertEquals("PHOTO", photo.type());
        assertNull(photo.video());
        assertNull(photo.viewCount());
        // video de ayni (gizli) metin kuralina tabidir
        Long vid2 = uploaded(a, "VIDEO");
        assertEquals("POST_TEXT_TOO_LONG", fails(() -> service.create(a.getId(),
                new CreatePostRequest("a".repeat(2201), List.of(vid2)))).code());
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
    void textRuleHiddenLimitMultilineAllowedNoWordLimit() {
        PostService.checkText(null);
        // 7 kelime / 60 karakter kurali kalkti
        PostService.checkText("bir iki üç dört beş altı yedi sekiz dokuz on");
        PostService.checkText("a".repeat(61));
        PostService.checkText("iki\nsatir");
        PostService.checkText("a".repeat(2200));
        PostService.checkText("x\n".repeat(39) + "x"); // tam 40 satir
        assertEquals("POST_TEXT_TOO_LONG", fails(() -> PostService.checkText("a".repeat(2201))).code());
        assertEquals("POST_TEXT_TOO_LONG", fails(() -> PostService.checkText("x\n".repeat(40) + "x")).code());
        // kod noktasi sayilir (emoji 1 karakter)
        PostService.checkText("😀".repeat(2200));
        assertEquals("POST_TEXT_TOO_LONG", fails(() -> PostService.checkText("😀".repeat(2201))).code());
        User a = newUser();
        Long img = uploaded(a, "IMAGE");
        assertEquals("POST_TEXT_TOO_LONG", fails(() -> service.create(a.getId(),
                new CreatePostRequest("a".repeat(2201), List.of(img)))).code());
        PostView ok = post(a, "tamam");
        assertEquals("POST_TEXT_TOO_LONG", fails(() -> service.update(a.getId(), ok.id(), "a".repeat(2201))).code());
        assertEquals("a\nb", service.update(a.getId(), ok.id(), "a\nb").text(), "cok satir serbest");
        assertNull(service.update(a.getId(), ok.id(), " ").text(), "fotografli gonderide metin silinebilir");
    }

    @Test
    void longMultilineTextIsCleanedAndStoredAsIs() {
        User a = newUser();
        String raw = "  ​Merhaba herkese, bu gonderi artik yedi kelimeden uzun olabilir!\r\nIkinci satir\rUcuncu\tsatir\u0007  ";
        PostView v = service.create(a.getId(), new CreatePostRequest(raw, List.of(uploaded(a, "IMAGE"))));
        assertEquals("Merhaba herkese, bu gonderi artik yedi kelimeden uzun olabilir!\nIkinci satir\nUcuncu satir", v.text());
        assertTrue(v.mentions().isEmpty());
    }

    @Test
    void feedHidesPostsWithoutMediaAndShowsOnlyFirstMedia() {
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
        assertTrue(ids.contains(videoOnly.getId()), "video gonderisi akista gorunur (video geri geldi)");
        assertFalse(ids.contains(textOnly.getId()), "medyasiz eski gonderi akistan gizli");
        Long hiddenId = textOnly.getId();
        assertTrue(service.feed(v.getId(), "latest", null, 20).items().stream().noneMatch(i -> i.id().equals(hiddenId)));
        assertTrue(service.feed(v.getId(), "popular", null, 20).items().stream().noneMatch(i -> i.id().equals(hiddenId)));
        Long multiId = multi.getId();
        PostView m = items.stream().filter(i -> i.id().equals(multiId)).findFirst().orElseThrow();
        assertEquals(1, m.media().size(), "yalniz ilk medya gosterilir");
        assertEquals("VIDEO", m.media().get(0).kind(), "ilk medya (position 0) videodur");
        assertTrue(posts.findById(hiddenId).isPresent() && mediaRepo.findById(onlyVid.getId()).isPresent(), "veri silinmedi");
        assertNotNull(im1.getId());
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
        // eski (7 günlük) puan sorgusu hâlâ iş tarafından beslenir; HTTP "popular" kapsamı artık rank_score akışıdır
        Instant since = Instant.now().minus(PostService.POPULAR_WINDOW);
        List<Long> ids = posts.popularFirst(v.getId(), since, org.springframework.data.domain.PageRequest.of(0, 50))
                .stream().map(Post::getId).toList();
        assertTrue(ids.indexOf(high.id()) >= 0 && ids.indexOf(high.id()) < ids.indexOf(low.id()));
        // 7 günden eski gönderi eski popüler sorguda yok ve puanı sıfırlanır
        Post old = posts.findById(low.id()).orElseThrow();
        old.setCreatedAt(Instant.now().minus(10, ChronoUnit.DAYS));
        old.setScore(5);
        posts.saveAndFlush(old);
        scoreJob.recompute();
        assertEquals(0.0, posts.findById(low.id()).orElseThrow().getScore());
        assertTrue(posts.popularFirst(v.getId(), since, org.springframework.data.domain.PageRequest.of(0, 50))
                .stream().noneMatch(i -> i.getId().equals(low.id())));
    }

    @Test
    void scoreFormula() {
        assertEquals(0.0, PostScore.compute(0, 0, 3));
        assertTrue(PostScore.compute(5, 0, 1) > PostScore.compute(5, 0, 10));
        assertTrue(PostScore.compute(0, 3, 2) > PostScore.compute(3, 0, 2));
    }
}
