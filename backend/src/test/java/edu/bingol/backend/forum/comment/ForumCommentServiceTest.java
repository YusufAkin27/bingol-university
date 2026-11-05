package edu.bingol.backend.forum.comment;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.fasterxml.jackson.databind.ObjectMapper;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.forum.comment.ForumCommentDtos.CommentPage;
import edu.bingol.backend.forum.comment.ForumCommentDtos.CommentView;
import edu.bingol.backend.forum.comment.ForumCommentDtos.CreateCommentRequest;
import edu.bingol.backend.forum.comment.ForumCommentDtos.LikeState;
import edu.bingol.backend.forum.comment.spi.ForumCommentLookup;
import edu.bingol.backend.forum.comment.spi.ForumCommentStateService;
import edu.bingol.backend.forum.topic.ForumTopic;
import edu.bingol.backend.forum.topic.ForumTopicRepository;
import edu.bingol.backend.moderation.UserBlock;
import edu.bingol.backend.moderation.UserBlockRepository;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

/** Forum yorum sistemi (B alani; H2): yazma, agac, yer tutucu, sayaclar, begeni yarisi, siralama + imlec, anonimlik, engel. */
@SpringBootTest
class ForumCommentServiceTest {

    @Autowired ForumCommentService service;
    @Autowired ForumCommentStateService state;
    @Autowired ForumCommentLookup lookup;
    @Autowired ForumCommentAccountPurger purger;
    @Autowired ForumTopicRepository topicRepo;
    @Autowired UserRepository users;
    @Autowired UserBlockRepository blocks;
    @Autowired JdbcTemplate jdbc;

    private static final ObjectMapper OM = new ObjectMapper().findAndRegisterModules();

    // ---------------------------------------------------------------- yardimcilar

    private User user(String name) {
        User u = new User();
        u.setEmail(name + "-" + UUID.randomUUID() + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName(name);
        u.setEmailVerified(true);
        return users.save(u);
    }

    private ForumTopic topic(User author, boolean anonymous) {
        ForumTopic t = new ForumTopic();
        t.setUserId(author.getId());
        t.setCategoryId(1L);
        t.setTitle("Baslik");
        t.setBody("Aciklama");
        t.setAnonymous(anonymous);
        return topicRepo.saveAndFlush(t);
    }

    private ForumTopic topic(User author) {
        return topic(author, false);
    }

    private CommentView comment(User by, ForumTopic t, String body) {
        return service.create(by.getId(), t.getId(), new CreateCommentRequest(body, null, null), null);
    }

    private CommentView reply(User by, CommentView to, String body) {
        return service.create(by.getId(), to.topicId(), new CreateCommentRequest(body, to.id(), null), null);
    }

    private CommentView anon(User by, ForumTopic t, String body) {
        return service.create(by.getId(), t.getId(), new CreateCommentRequest(body, null, true), null);
    }

    private int topicCount(ForumTopic t) {
        return jdbc.queryForObject("SELECT comment_count FROM forum_topic WHERE id = ?", Integer.class, t.getId());
    }

    private int replyCount(CommentView c) {
        return jdbc.queryForObject("SELECT reply_count FROM forum_comment WHERE id = ?", Integer.class, c.id());
    }

    private int likeCountDb(CommentView c) {
        return jdbc.queryForObject("SELECT like_count FROM forum_comment WHERE id = ?", Integer.class, c.id());
    }

    private static String code(Runnable r) {
        return assertThrows(ApiException.class, r::run).code();
    }

    private static ApiException thrown(Runnable r) {
        return assertThrows(ApiException.class, r::run);
    }

    private void lock(ForumTopic t) {
        jdbc.update("UPDATE forum_topic SET locked_at = CURRENT_TIMESTAMP WHERE id = ?", t.getId());
    }

    /** Sayac butunlugu: konu sayaci = canli yorum sayisi; reply_count = dogrudan listelenen cocuk sayisi; like_count = begeni satiri. */
    private void assertIntegrity(ForumTopic t) {
        Integer live = jdbc.queryForObject("SELECT COUNT(*) FROM forum_comment WHERE topic_id = ? AND deleted_at IS NULL "
                + "AND status = 'ACTIVE'", Integer.class, t.getId());
        assertEquals(live, topicCount(t), "konu comment_count = canli yorum sayisi");
        List<Long> ids = jdbc.queryForList("SELECT id FROM forum_comment WHERE topic_id = ?", Long.class, t.getId());
        for (Long id : ids) {
            Integer listedChildren = jdbc.queryForObject("SELECT COUNT(*) FROM forum_comment c WHERE c.parent_comment_id = ? AND "
                    + ForumCommentStore.LISTED, Integer.class, id);
            Integer rc = jdbc.queryForObject("SELECT reply_count FROM forum_comment WHERE id = ?", Integer.class, id);
            assertEquals(listedChildren, rc, "reply_count yorum " + id);
            Integer likes = jdbc.queryForObject("SELECT COUNT(*) FROM forum_comment_like WHERE comment_id = ?", Integer.class, id);
            Integer lc = jdbc.queryForObject("SELECT like_count FROM forum_comment WHERE id = ?", Integer.class, id);
            assertEquals(likes, lc, "like_count yorum " + id);
        }
    }

    // ---------------------------------------------------------------- olustur / duzenle / sil / sahiplik

    @Test
    void createEditDeleteAndOwnership() {
        User owner = user("sahip");
        User a = user("ali");
        User b = user("veli");
        ForumTopic t = topic(owner);

        CommentView c = comment(a, t, "  merhaba   dunya \n\n\n\n ");
        assertEquals("merhaba   dunya", c.body(), "bas/son bosluk ve fazla satir sonu temizlenir");
        assertNull(c.parentCommentId());
        assertEquals(0, c.depth());
        assertTrue(c.mine());
        assertFalse(c.deleted());
        assertNull(c.editedAt());
        assertEquals(1, topicCount(t));

        // baskasi duzenleyemez / silemez
        assertEquals("FORUM_NOT_OWNER", thrown(() -> service.edit(b.getId(), c.id(), "ele gecirdim")).code());
        assertEquals(403, thrown(() -> service.edit(b.getId(), c.id(), "x")).status().value());
        assertEquals("FORUM_NOT_OWNER", code(() -> service.delete(b.getId(), c.id())));
        assertEquals("merhaba   dunya", service.get(a.getId(), c.id()).body());

        // sahip duzenler: editedAt dolar, ayni metin damga basmaz
        CommentView same = service.edit(a.getId(), c.id(), "merhaba   dunya");
        assertNull(same.editedAt(), "degisiklik yoksa Duzenlendi damgasi yok");
        CommentView edited = service.edit(a.getId(), c.id(), "yeni metin");
        assertEquals("yeni metin", edited.body());
        assertNotNull(edited.editedAt());

        // sahip siler; ikinci silme sessiz; silinmis yorum duzenlenemez
        service.delete(a.getId(), c.id());
        service.delete(a.getId(), c.id());
        assertEquals("FORUM_COMMENT_NOT_FOUND", code(() -> service.edit(a.getId(), c.id(), "geri")));
        assertEquals("FORUM_COMMENT_NOT_FOUND", code(() -> service.get(b.getId(), c.id())), "yanitsiz silinen yorum kalkar");
        assertEquals(0, topicCount(t));
        assertIntegrity(t);
    }

    @Test
    void bodyRules() {
        User owner = user("sahip");
        User a = user("ali");
        ForumTopic t = topic(owner);
        assertEquals("FORUM_COMMENT_EMPTY", code(() -> comment(a, t, "   \n ")));
        assertEquals("FORUM_COMMENT_EMPTY", code(() -> comment(a, t, null)));
        assertEquals("FORUM_COMMENT_EMPTY", code(() -> comment(a, t, "<b></b>  ")), "yalniz etiket = bos");
        assertEquals("FORUM_COMMENT_TOO_LONG", code(() -> comment(a, t, "a".repeat(4001))));
        assertEquals(4000, comment(a, t, "a".repeat(4000)).body().length());
        // XSS / HTML: etiketler atilir, duz metin kalir
        assertEquals("alert(1)merhaba", comment(a, t, "<script>alert(1)</script>merhaba").body());
        assertEquals("a < b ve c > d", comment(a, t, "a < b ve c > d").body(), "duz metin bozulmaz");
        // yon-ters ve kontrol karakterleri
        assertEquals("abc", comment(a, t, "a‮b\u0000c").body());
    }

    @Test
    void invisibleTopicIs404() {
        User owner = user("sahip");
        User a = user("ali");
        assertEquals("FORUM_TOPIC_NOT_FOUND", code(() -> service.create(a.getId(), 999_999L,
                new CreateCommentRequest("x", null, null), null)));
        ForumTopic t = topic(owner);
        jdbc.update("UPDATE forum_topic SET status = 'REMOVED' WHERE id = ?", t.getId());
        assertEquals("FORUM_TOPIC_NOT_FOUND", code(() -> comment(a, t, "x")));
        assertEquals("FORUM_TOPIC_NOT_FOUND", code(() -> service.list(a.getId(), t.getId(), null, null, null)));
    }

    @Test
    void lockedTopicRejectsCreateAndEditButAllowsDelete() {
        User owner = user("sahip");
        User a = user("ali");
        ForumTopic t = topic(owner);
        CommentView c = comment(a, t, "ilk");
        lock(t);
        assertEquals("FORUM_TOPIC_LOCKED", code(() -> comment(a, t, "yeni")));
        assertEquals(409, thrown(() -> comment(a, t, "yeni")).status().value());
        assertEquals("FORUM_TOPIC_LOCKED", code(() -> reply(owner, c, "yanit")));
        assertEquals("FORUM_TOPIC_LOCKED", code(() -> service.edit(a.getId(), c.id(), "degisti")));
        // okuma, begeni ve kendi yorumunu silme calisir
        assertEquals(1, service.list(a.getId(), t.getId(), null, null, null).items().size());
        assertTrue(service.like(owner.getId(), c.id()).liked());
        service.delete(a.getId(), c.id());
        assertEquals(0, topicCount(t));
    }

    // ---------------------------------------------------------------- yanit zinciri + yer tutucu

    @Test
    void deepReplyChainKeepsDepthRootAndPath() {
        User owner = user("sahip");
        User a = user("ali");
        User b = user("veli");
        ForumTopic t = topic(owner);
        CommentView c0 = comment(a, t, "kok");
        CommentView c1 = reply(b, c0, "d1");
        CommentView c2 = reply(a, c1, "d2");
        CommentView c3 = reply(b, c2, "d3");
        CommentView c4 = reply(a, c3, "d4");
        CommentView c5 = reply(b, c4, "d5");

        assertEquals(List.of(0, 1, 2, 3, 4, 5), List.of(c0.depth(), c1.depth(), c2.depth(), c3.depth(), c4.depth(), c5.depth()));
        assertEquals(c4.id(), c5.parentCommentId());
        assertEquals(6, topicCount(t));
        assertEquals(1, replyCount(c0));
        assertEquals(1, replyCount(c4));
        assertEquals(0, replyCount(c5));

        CommentView got = service.get(a.getId(), c5.id());
        assertEquals(List.of(c0.id(), c1.id(), c2.id(), c3.id(), c4.id()), got.path(), "kokten dogrudan ebeveyne");
        assertEquals(List.of(), service.get(a.getId(), c0.id()).path());

        // /replies: dogrudan cocuk + her cocukta onizleme
        CommentPage r = service.replies(a.getId(), c0.id(), null, null);
        assertEquals(1, r.items().size());
        assertEquals(c1.id(), r.items().get(0).id());
        assertEquals(List.of(c2.id()), r.items().get(0).replyPreview().stream().map(CommentView::id).toList());
        assertEquals(1, service.replies(a.getId(), c4.id(), null, null).items().size());
        assertIntegrity(t);
    }

    @Test
    void replyToDeletedOrRemovedOrForeignParentIsRejected() {
        User owner = user("sahip");
        User a = user("ali");
        ForumTopic t = topic(owner);
        ForumTopic other = topic(owner);
        CommentView c = comment(a, t, "ilk");
        CommentView child = reply(owner, c, "cocuk");
        service.delete(a.getId(), c.id()); // yaniti var -> yer tutucu
        assertEquals("FORUM_COMMENT_PARENT_UNAVAILABLE", code(() -> reply(owner, c, "olmaz")));
        assertEquals(409, thrown(() -> reply(owner, c, "olmaz")).status().value());
        // baska konunun yorumuna yanit
        CommentView o = comment(a, other, "baska konu");
        assertEquals("FORUM_COMMENT_NOT_FOUND", code(() -> service.create(owner.getId(), t.getId(),
                new CreateCommentRequest("x", o.id(), null), null)));
        // kaldirilmis ebeveyn
        state.remove(child.id(), "ihlal");
        assertEquals("FORUM_COMMENT_PARENT_UNAVAILABLE", code(() -> reply(a, child, "olmaz")));
        assertEquals("FORUM_COMMENT_NOT_FOUND", code(() -> service.create(a.getId(), t.getId(),
                new CreateCommentRequest("x", 424_242L, null), null)));
        assertIntegrity(t);
        assertIntegrity(other);
    }

    @Test
    void deletedCommentWithRepliesBecomesPlaceholderAndCascadesAway() {
        User owner = user("sahip");
        User a = user("ali");
        User b = user("veli");
        ForumTopic t = topic(owner);
        CommentView top = comment(a, t, "ust");
        CommentView mid = reply(b, top, "orta");
        CommentView leaf = reply(a, mid, "yaprak");
        assertEquals(3, topicCount(t));

        // ortayi sil: yaniti var -> yer tutucu (govde/yazar null, deleted:true), sayac -1
        service.delete(b.getId(), mid.id());
        assertEquals(2, topicCount(t));
        CommentView ph = service.get(a.getId(), mid.id());
        assertTrue(ph.deleted());
        assertNull(ph.body());
        assertNull(ph.author());
        assertFalse(ph.mine());
        assertEquals(1, ph.replyCount());
        assertEquals(1, replyCount(top), "yer tutucu listelenmeye devam eder");
        CommentView listedMid = service.replies(a.getId(), top.id(), null, null).items().get(0);
        assertTrue(listedMid.deleted());
        assertEquals(leaf.id(), listedMid.replyPreview().get(0).id());
        // yer tutucuya yanit verilemez (yukarida); yaprak hala gorunur
        assertEquals("yaprak", service.get(b.getId(), leaf.id()).body());

        // yaprak silinince yer tutucu da listeden cikar (zincir yukari)
        service.delete(a.getId(), leaf.id());
        assertEquals(1, topicCount(t));
        assertEquals(0, replyCount(top));
        assertEquals("FORUM_COMMENT_NOT_FOUND", code(() -> service.get(a.getId(), mid.id())));
        assertEquals(List.of(), service.replies(a.getId(), top.id(), null, null).items());
        // silinen icerik JSON'da gorunmez
        assertFalse(service.list(a.getId(), t.getId(), null, null, null).toString().contains("orta"));
        assertIntegrity(t);
    }

    @Test
    void placeholderBodyAndAuthorNeverLeakInJson() throws Exception {
        User owner = user("sahip");
        User a = user("gizemli-ali");
        ForumTopic t = topic(owner);
        CommentView c = comment(a, t, "cok ozel metin");
        reply(owner, c, "cevap");
        service.delete(a.getId(), c.id());
        String json = OM.writeValueAsString(service.list(owner.getId(), t.getId(), null, null, null));
        assertFalse(json.contains("cok ozel metin"));
        assertFalse(json.contains("gizemli-ali"));
        assertFalse(json.contains("\"userId\":" + a.getId()));
    }

    // ---------------------------------------------------------------- begeni

    @Test
    void likeIsIdempotentAndCountsOnce() {
        User owner = user("sahip");
        User a = user("ali");
        User b = user("veli");
        ForumTopic t = topic(owner);
        CommentView c = comment(a, t, "ilk");
        LikeState l1 = service.like(b.getId(), c.id());
        LikeState l2 = service.like(b.getId(), c.id());
        assertTrue(l1.liked() && l2.liked());
        assertEquals(1, l1.likeCount());
        assertEquals(1, l2.likeCount(), "ikinci PUT sayaci artirmaz");
        assertEquals(2, service.like(a.getId(), c.id()).likeCount());
        assertTrue(service.get(b.getId(), c.id()).likedByMe());
        LikeState u1 = service.unlike(b.getId(), c.id());
        LikeState u2 = service.unlike(b.getId(), c.id());
        assertFalse(u1.liked());
        assertEquals(1, u1.likeCount());
        assertEquals(1, u2.likeCount(), "ikinci DELETE sayaci dusurmez");
        assertFalse(service.get(b.getId(), c.id()).likedByMe());
        assertIntegrity(t);
    }

    @Test
    void concurrentLikesStayConsistent() throws Exception {
        User owner = user("sahip");
        ForumTopic t = topic(owner);
        CommentView c = comment(owner, t, "populer");
        int n = 8;
        List<User> fans = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            fans.add(user("hayran" + i));
        }
        ExecutorService ex = Executors.newFixedThreadPool(n * 2);
        CountDownLatch go = new CountDownLatch(1);
        List<Future<?>> fs = new ArrayList<>();
        for (User f : fans) {
            for (int k = 0; k < 2; k++) { // her kullanici AYNI ANDA iki kez PUT
                fs.add(ex.submit(() -> {
                    go.await();
                    service.like(f.getId(), c.id());
                    return null;
                }));
            }
        }
        go.countDown();
        for (Future<?> f : fs) {
            f.get(30, TimeUnit.SECONDS);
        }
        ex.shutdown();
        assertEquals(n, likeCountDb(c), "tam n begeni: ne eksik ne fazla");
        // ayni anda bir kismi geri alinir
        ExecutorService ex2 = Executors.newFixedThreadPool(n);
        CountDownLatch go2 = new CountDownLatch(1);
        List<Future<?>> fs2 = new ArrayList<>();
        for (int i = 0; i < n / 2; i++) {
            User f = fans.get(i);
            fs2.add(ex2.submit(() -> {
                go2.await();
                service.unlike(f.getId(), c.id());
                service.unlike(f.getId(), c.id());
                return null;
            }));
        }
        go2.countDown();
        for (Future<?> f : fs2) {
            f.get(30, TimeUnit.SECONDS);
        }
        ex2.shutdown();
        assertEquals(n / 2, likeCountDb(c));
        assertIntegrity(t);
    }

    @Test
    void concurrentCommentsKeepTopicCounterExact() throws Exception {
        User owner = user("sahip");
        ForumTopic t = topic(owner);
        CommentView root = comment(owner, t, "kok");
        int n = 10;
        List<User> writers = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            writers.add(user("yazar" + i));
        }
        ExecutorService ex = Executors.newFixedThreadPool(n);
        CountDownLatch go = new CountDownLatch(1);
        List<Future<?>> fs = new ArrayList<>();
        for (User w : writers) {
            fs.add(ex.submit(() -> {
                go.await();
                reply(w, root, "es zamanli yanit");
                comment(w, t, "es zamanli ust");
                return null;
            }));
        }
        go.countDown();
        for (Future<?> f : fs) {
            f.get(60, TimeUnit.SECONDS);
        }
        ex.shutdown();
        assertEquals(1 + 2 * n, topicCount(t));
        assertEquals(n, replyCount(root));
        assertIntegrity(t);
    }

    @Test
    void likeOnInvisibleCommentIs404() {
        User owner = user("sahip");
        User a = user("ali");
        ForumTopic t = topic(owner);
        CommentView c = comment(a, t, "ilk");
        service.delete(a.getId(), c.id());
        assertEquals("FORUM_COMMENT_NOT_FOUND", code(() -> service.like(owner.getId(), c.id())));
        assertEquals("FORUM_COMMENT_NOT_FOUND", code(() -> service.like(owner.getId(), 777_777L)));
    }

    // ---------------------------------------------------------------- siralama + imlec

    @Test
    void sortsAndCursorsAreStableWithoutDuplicatesOrSkips() {
        User owner = user("sahip");
        ForumTopic t = topic(owner);
        List<User> fans = new ArrayList<>();
        for (int i = 0; i < 5; i++) {
            fans.add(user("f" + i));
        }
        List<CommentView> all = new ArrayList<>();
        for (int i = 0; i < 11; i++) {
            all.add(comment(owner, t, "yorum " + i));
        }
        // begeni: yorum 3 -> 5 begeni, yorum 7 -> 3 begeni, yorum 0 -> 1 begeni; yorum 5'e 2 yanit
        for (int i = 0; i < 5; i++) {
            service.like(fans.get(i).getId(), all.get(3).id());
        }
        for (int i = 0; i < 3; i++) {
            service.like(fans.get(i).getId(), all.get(7).id());
        }
        service.like(fans.get(0).getId(), all.get(0).id());
        reply(fans.get(0), all.get(5), "y1");
        reply(fans.get(1), all.get(5), "y2");

        for (ForumCommentService.Sort sort : ForumCommentService.Sort.values()) {
            List<Long> seen = new ArrayList<>();
            String cursor = null;
            int pages = 0;
            do {
                CommentPage p = service.list(owner.getId(), t.getId(), sort, cursor, 4);
                assertTrue(p.items().size() <= 4);
                p.items().forEach(v -> seen.add(v.id()));
                cursor = p.nextCursor();
                pages++;
                assertTrue(pages < 10, "imlec dongusu");
            } while (cursor != null);
            assertEquals(11, seen.size(), sort + ": hepsi geldi");
            assertEquals(11, new HashSet<>(seen).size(), sort + ": tekrar yok");
            switch (sort) {
                case NEWEST -> assertEquals(all.stream().map(CommentView::id).sorted((x, y) -> Long.compare(y, x)).toList(), seen);
                case OLDEST -> assertEquals(all.stream().map(CommentView::id).sorted().toList(), seen);
                default -> {
                    // EN IYI: 5 begenili once, sonra 3 begenili; 2 yanitli (puan 2*0+2+1=3) 1 begenili (3) ile esit puan
                    assertEquals(all.get(3).id(), seen.get(0));
                    assertEquals(all.get(7).id(), seen.get(1));
                    assertTrue(seen.indexOf(all.get(0).id()) < seen.indexOf(all.get(1).id()));
                    assertTrue(seen.indexOf(all.get(5).id()) < seen.indexOf(all.get(1).id()));
                }
            }
        }
        // varsayilan siralama BEST ve onizleme: 5. yorumda 2 yanit
        CommentView five = service.list(owner.getId(), t.getId(), null, null, 30).items().stream()
                .filter(v -> v.id().equals(all.get(5).id())).findFirst().orElseThrow();
        assertEquals(2, five.replyCount());
        assertEquals(2, five.replyPreview().size());
        assertEquals("y1", five.replyPreview().get(0).body(), "onizleme eskiden yeniye");
    }

    @Test
    void bestCursorSurvivesNewCommentsBetweenPages() {
        User owner = user("sahip");
        ForumTopic t = topic(owner);
        List<CommentView> first = new ArrayList<>();
        for (int i = 0; i < 6; i++) {
            first.add(comment(owner, t, "ilk " + i));
        }
        CommentPage p1 = service.list(owner.getId(), t.getId(), ForumCommentService.Sort.BEST, null, 3);
        assertNotNull(p1.nextCursor());
        // arada yeni yorum gelir (en yeni = en yuksek puanli olabilir): ikinci sayfada ilk sayfadakiler TEKRARLANMAZ
        comment(owner, t, "arada gelen");
        CommentPage p2 = service.list(owner.getId(), t.getId(), ForumCommentService.Sort.BEST, p1.nextCursor(), 3);
        Set<Long> ids1 = new HashSet<>();
        p1.items().forEach(v -> ids1.add(v.id()));
        for (CommentView v : p2.items()) {
            assertFalse(ids1.contains(v.id()), "tekrar");
        }
        assertEquals(400, thrown(() -> service.list(owner.getId(), t.getId(), ForumCommentService.Sort.BEST, "!!bozuk!!", 3)).status().value());
        assertEquals("FORUM_CURSOR_INVALID", code(() -> service.list(owner.getId(), t.getId(), ForumCommentService.Sort.NEWEST, "N|abc", 3)));
    }

    @Test
    void pageSizeIsClamped() {
        User owner = user("sahip");
        ForumTopic t = topic(owner);
        for (int i = 0; i < 35; i++) {
            comment(owner, t, "y" + i);
        }
        assertEquals(15, service.list(owner.getId(), t.getId(), null, null, null).items().size(), "varsayilan 15");
        assertEquals(30, service.list(owner.getId(), t.getId(), null, null, 500).items().size(), "en cok 30");
    }

    // ---------------------------------------------------------------- anonimlik

    @Test
    void anonymousCommentNeverLeaksIdentity() throws Exception {
        User owner = user("konu-sahibi");
        User secret = user("gizli-ogrenci");
        User viewer = user("izleyen");
        ForumTopic t = topic(owner, false);
        CommentView c = anon(secret, t, "kim oldugumu bilmeyin");
        CommentView r = reply(viewer, c, "kimsin");
        // yazarin anonim yorumuna baskasi bakar
        for (Long viewerId : List.of(viewer.getId(), owner.getId())) {
            String json = OM.writeValueAsString(service.list(viewerId, t.getId(), null, null, null))
                    + OM.writeValueAsString(service.get(viewerId, c.id()))
                    + OM.writeValueAsString(service.replies(viewerId, c.id(), null, null))
                    + OM.writeValueAsString(service.replies(viewerId, c.id(), null, null));
            assertTrue(json.contains("\"anonymous\":true"));
            assertTrue(json.contains("Anonim #"));
            assertFalse(json.contains("gizli-ogrenci"), "ad sizmaz");
            assertFalse(json.contains(secret.getEmail()), "e-posta sizmaz");
            assertFalse(json.contains("\"userId\":" + secret.getId()), "kimlik sizmaz");
        }
        CommentView seen = service.get(viewer.getId(), c.id());
        assertNull(seen.author().userId());
        assertNull(seen.author().avatarUrl());
        assertNull(seen.author().department());
        assertTrue(seen.author().anonymous());
        assertTrue(seen.anonymous());
        assertFalse(seen.mine());
        // yazarin kendisi mine:true gorur, yine de kimlik alani yok
        CommentView mine = service.get(secret.getId(), c.id());
        assertTrue(mine.mine());
        assertNull(mine.author().userId());
        assertEquals(c.id(), r.parentCommentId());
    }

    @Test
    void anonymousAliasIsStablePerTopicAndDistinctPerUser() {
        User owner = user("sahip");
        User a = user("ali");
        User b = user("veli");
        ForumTopic t1 = topic(owner);
        ForumTopic t2 = topic(owner);
        String a1 = anon(a, t1, "bir").author().displayName();
        String a2 = anon(a, t1, "iki").author().displayName();
        String b1 = anon(b, t1, "uc").author().displayName();
        assertEquals(a1, a2, "ayni kisi ayni konuda ayni takma ad");
        assertNotEquals(a1, b1, "farkli kisi farkli takma ad");
        assertTrue(a1.startsWith("Anonim #"));
        // acik ve anonim yorum ayni kisiden: anonimlik AYRI secim
        CommentView open = comment(a, t1, "acik");
        assertFalse(open.anonymous());
        assertEquals(a.getId(), open.author().userId());
        assertEquals("ali", open.author().displayName());
        // baska konuda numara o konuya ozgudur
        assertTrue(anon(b, t2, "x").author().displayName().startsWith("Anonim #"));
    }

    @Test
    void anonymousTopicDoesNotMakeCommentsAnonymousAndTopicAuthorBadgeDoesNotLeak() {
        User owner = user("anonim-konu-sahibi");
        User a = user("ali");
        ForumTopic t = topic(owner, true);
        // acik yorum: otomatik anonim olmaz; konu sahibiyse bile "Yazar" etiketi anonim konuyu ele vermez
        CommentView open = comment(owner, t, "acik yorum");
        assertFalse(open.anonymous());
        assertFalse(open.topicAuthor(), "anonim konuda kimlikli yorum Yazar etiketi tasimaz");
        // ayni kisinin anonim yorumu: Yazar etiketi (ayni takma ad zaten bilinir)
        CommentView ownAnon = anon(owner, t, "anonim yorum");
        assertTrue(ownAnon.topicAuthor());
        assertTrue(ownAnon.author().anonymous());
        assertFalse(comment(a, t, "baska").topicAuthor());
        // acik konuda konu sahibinin yorumu etiketlenir
        ForumTopic open2 = topic(owner, false);
        assertTrue(comment(owner, open2, "ben yazdim").topicAuthor());
        assertFalse(comment(a, open2, "ben degil").topicAuthor());
    }

    // ---------------------------------------------------------------- engel

    @Test
    void blockedAuthorIsHiddenFromViewerEvenWhenAnonymous() {
        User owner = user("sahip");
        User viewer = user("izleyen");
        User noisy = user("gurultucu");
        User friend = user("dost");
        ForumTopic t = topic(owner);
        CommentView n1 = comment(noisy, t, "gurultu");
        CommentView n2 = anon(noisy, t, "anonim gurultu");
        CommentView f1 = comment(friend, t, "dost yorumu");
        CommentView reply = reply(friend, n1, "gurultuye yanit");
        assertEquals(3, service.list(viewer.getId(), t.getId(), ForumCommentService.Sort.NEWEST, null, null).items().size());

        blocks.save(new UserBlock(viewer.getId(), noisy.getId()));
        List<Long> ids = service.list(viewer.getId(), t.getId(), ForumCommentService.Sort.NEWEST, null, null).items()
                .stream().map(CommentView::id).toList();
        assertEquals(List.of(f1.id()), ids, "engellinin acik VE anonim yorumlari gizli");
        assertEquals("FORUM_COMMENT_NOT_FOUND", code(() -> service.get(viewer.getId(), n2.id())));
        assertEquals("FORUM_COMMENT_NOT_FOUND", code(() -> service.like(viewer.getId(), n1.id())));
        assertEquals("FORUM_COMMENT_NOT_FOUND", code(() -> service.create(viewer.getId(), t.getId(),
                new CreateCommentRequest("yanit", n1.id(), null), null)));
        // engellenen de engelleyenin yorumunu goremez (iki yonlu)
        CommentView v1 = comment(viewer, t, "benim yorumum");
        assertFalse(service.list(noisy.getId(), t.getId(), ForumCommentService.Sort.NEWEST, null, null).items()
                .stream().anyMatch(v -> v.id().equals(v1.id())));
        // diger okuyucular etkilenmez: gurultucu + dost + engelleyenin yorumu
        assertEquals(4, service.list(friend.getId(), t.getId(), ForumCommentService.Sort.NEWEST, null, null).items().size());
        assertNotNull(reply);
    }

    // ---------------------------------------------------------------- moderator durumu

    @Test
    void moderatorRemoveAndRestoreAreIdempotentAndKeepCounters() {
        User owner = user("sahip");
        User a = user("ali");
        ForumTopic t = topic(owner);
        CommentView c = comment(a, t, "ihlal");
        CommentView child = reply(owner, c, "cevap");
        assertEquals(2, topicCount(t));

        state.remove(c.id(), "spam");
        state.remove(c.id(), "spam"); // idempotent
        assertEquals(1, topicCount(t));
        CommentView ph = service.get(owner.getId(), c.id());
        assertTrue(ph.deleted(), "yaniti var -> yer tutucu");
        assertNull(ph.body());
        assertEquals("FORUM_COMMENT_NOT_FOUND", code(() -> service.like(owner.getId(), c.id())));
        assertEquals("FORUM_COMMENT_NOT_FOUND", code(() -> service.edit(a.getId(), c.id(), "geri")), "kaldirilan yorum duzenlenemez");
        assertEquals("FORUM_COMMENT_NOT_FOUND", code(() -> service.delete(a.getId(), c.id())));
        ForumCommentLookup.CommentRef ref = lookup.find(c.id()).orElseThrow();
        assertTrue(ref.removed());
        assertEquals(a.getId(), ref.authorId());

        state.restore(c.id());
        state.restore(c.id()); // idempotent
        assertEquals(2, topicCount(t));
        assertEquals("ihlal", service.get(owner.getId(), c.id()).body());
        assertIntegrity(t);

        // yanitsiz yorumu kaldir: listeden cikar, geri alinca doner
        state.remove(child.id(), "x");
        assertEquals("FORUM_COMMENT_NOT_FOUND", code(() -> service.get(owner.getId(), child.id())));
        assertEquals(0, replyCount(c));
        state.restore(child.id());
        assertEquals(1, replyCount(c));
        assertEquals(2, topicCount(t));
        assertIntegrity(t);

        // sahibi silmis yorum geri getirilemez
        service.delete(a.getId(), child.id());
        assertEquals("FORUM_COMMENT_DELETED", code(() -> state.restore(child.id())));
        assertEquals("FORUM_COMMENT_NOT_FOUND", code(() -> state.remove(31_337L, "yok")));
    }

    @Test
    void restoringRemovedLeafRelistsPlaceholderChain() {
        User owner = user("sahip");
        User a = user("ali");
        ForumTopic t = topic(owner);
        CommentView top = comment(a, t, "ust");
        CommentView mid = reply(a, top, "orta");
        CommentView leaf = reply(a, mid, "yaprak");
        service.delete(a.getId(), mid.id()); // yer tutucu
        state.remove(leaf.id(), "ihlal"); // yaprak gitti -> yer tutucu da listeden cikti
        assertEquals(0, replyCount(top));
        assertEquals("FORUM_COMMENT_NOT_FOUND", code(() -> service.get(a.getId(), mid.id())));
        state.restore(leaf.id()); // yaprak geri: yer tutucu da yeniden listelenir
        assertEquals(1, replyCount(top));
        assertTrue(service.get(a.getId(), mid.id()).deleted());
        assertEquals("yaprak", service.get(a.getId(), leaf.id()).body());
        assertIntegrity(t);
    }

    // ---------------------------------------------------------------- idempotency

    @Test
    void idempotencyKeyReturnsTheSameCommentOnce() {
        User owner = user("sahip");
        User a = user("ali");
        ForumTopic t = topic(owner);
        ForumTopic other = topic(owner);
        String key = "key-" + UUID.randomUUID();
        CreateCommentRequest req = new CreateCommentRequest("tek gonderim", null, null);
        CommentView c1 = service.create(a.getId(), t.getId(), req, key);
        CommentView c2 = service.create(a.getId(), t.getId(), req, key);
        assertEquals(c1.id(), c2.id());
        assertEquals(1, topicCount(t));
        assertEquals("IDEMPOTENCY_KEY_REUSED", code(() -> service.create(a.getId(), other.getId(), req, key)));
        // bicimsiz anahtar yok sayilir (korumasiz): iki yorum olusur
        service.create(a.getId(), t.getId(), req, "x");
        service.create(a.getId(), t.getId(), req, "x");
        assertEquals(3, topicCount(t));
    }

    @Test
    void concurrentSameIdempotencyKeyCreatesOneComment() throws Exception {
        User owner = user("sahip");
        User a = user("ali");
        ForumTopic t = topic(owner);
        String key = "race-" + UUID.randomUUID();
        int n = 6;
        ExecutorService ex = Executors.newFixedThreadPool(n);
        CountDownLatch go = new CountDownLatch(1);
        List<Future<CommentView>> fs = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            fs.add(ex.submit(() -> {
                go.await();
                return service.create(a.getId(), t.getId(), new CreateCommentRequest("cift dokunma", null, null), key);
            }));
        }
        go.countDown();
        Set<Long> ids = new HashSet<>();
        for (Future<CommentView> f : fs) {
            ids.add(f.get(60, TimeUnit.SECONDS).id());
        }
        ex.shutdown();
        assertEquals(1, ids.size(), "tek yorum");
        assertEquals(1, topicCount(t));
    }

    // ---------------------------------------------------------------- kaydet

    @Test
    void bookmarkIsIdempotentAndShownInViews() {
        User owner = user("sahip");
        User a = user("ali");
        ForumTopic t = topic(owner);
        CommentView c = comment(owner, t, "kaydet");
        assertTrue(service.save(a.getId(), c.id()).saved());
        assertTrue(service.save(a.getId(), c.id()).saved());
        assertEquals(1, jdbc.queryForObject("SELECT COUNT(*) FROM forum_bookmark WHERE user_id = ? AND target_type = 'COMMENT' "
                + "AND target_id = ?", Integer.class, a.getId(), c.id()));
        assertTrue(service.get(a.getId(), c.id()).savedByMe());
        assertFalse(service.get(owner.getId(), c.id()).savedByMe());
        assertFalse(service.unsave(a.getId(), c.id()).saved());
        assertFalse(service.unsave(a.getId(), c.id()).saved());
        assertFalse(service.get(a.getId(), c.id()).savedByMe());
    }

    // ---------------------------------------------------------------- hesap silme

    @Test
    void accountPurgeWipesCommentsAndLikesAndFixesCounters() {
        User owner = user("sahip");
        User leaving = user("giden");
        User other = user("kalan");
        ForumTopic t = topic(owner);
        CommentView mine = comment(leaving, t, "kisisel metin");
        CommentView withReply = comment(leaving, t, "yanitli");
        CommentView alone = comment(leaving, t, "yalniz");
        reply(other, withReply, "baskasinin yaniti");
        CommentView others = comment(other, t, "baskasinin");
        service.like(leaving.getId(), others.id());
        service.like(other.getId(), mine.id());
        assertEquals(5, topicCount(t));

        purger.purge(leaving.getId());

        assertEquals(2, topicCount(t), "silinenler canli sayilmaz: baskasinin iki yorumu kalir");
        assertEquals(0, likeCountDb(others), "begenisi geri alindi");
        assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM forum_comment_like WHERE user_id = ?", Integer.class, leaving.getId()));
        assertEquals("[silindi]", jdbc.queryForObject("SELECT body FROM forum_comment WHERE id = ?", String.class, mine.id()));
        assertEquals("FORUM_COMMENT_NOT_FOUND", code(() -> service.get(owner.getId(), alone.id())), "yanitsiz: kalkar");
        CommentView ph = service.get(owner.getId(), withReply.id());
        assertTrue(ph.deleted(), "yanitli: yer tutucu");
        assertNull(ph.author());
        assertIntegrity(t);
    }

    // ---------------------------------------------------------------- SPI

    @Test
    void lookupExposesRealAuthorForServerSideOnly() {
        User owner = user("sahip");
        User a = user("ali");
        ForumTopic t = topic(owner);
        CommentView c = anon(a, t, "x");
        CommentView r = reply(owner, c, "y");
        ForumCommentLookup.CommentRef ref = lookup.find(r.id()).orElseThrow();
        assertEquals(c.id(), ref.parentCommentId());
        assertEquals(a.getId(), ref.parentAuthorId());
        assertEquals(owner.getId(), ref.authorId());
        assertTrue(ref.live());
        assertTrue(lookup.find(c.id()).orElseThrow().anonymous());
        assertTrue(lookup.find(987_654L).isEmpty());
    }
}
