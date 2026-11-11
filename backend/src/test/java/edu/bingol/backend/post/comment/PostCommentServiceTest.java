package edu.bingol.backend.post.comment;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.FieldApiException;
import edu.bingol.backend.moderation.UserBlock;
import edu.bingol.backend.moderation.UserBlockRepository;
import edu.bingol.backend.moderation.profanity.ProfanityFilter;
import edu.bingol.backend.post.Post;
import edu.bingol.backend.post.PostDtos.PostView;
import edu.bingol.backend.post.PostFixtures;
import edu.bingol.backend.post.PostRepository;
import edu.bingol.backend.post.PostService;
import edu.bingol.backend.post.comment.CommentDtos.CommentPage;
import edu.bingol.backend.post.comment.CommentDtos.CommentView;
import edu.bingol.backend.post.comment.CommentDtos.CreateCommentRequest;
import edu.bingol.backend.post.comment.CommentDtos.LikeState;
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
import org.springframework.jdbc.core.JdbcTemplate;

/** Gonderi/reel yorumlari (KS-BE2): yazma, yanit yassilama, sayaclar, gorunurluk, begeni, silme, gizleme (H2). */
@SpringBootTest(properties = "spring.messages.basename=i18n/messages,i18n/comment")
class PostCommentServiceTest {

    @Autowired PostCommentService service;
    @Autowired AdminPostCommentService admin;
    @Autowired CommentReportHandler reportHandler;
    @Autowired CommentAccountPurger purger;
    @Autowired CommentCounters counters;
    @Autowired PostService postService;
    @Autowired PostRepository posts;
    @Autowired PostMediaRepository mediaRepo;
    @Autowired PostCommentRepository commentRepo;
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

    private Post post(User author) {
        return PostFixtures.withPhoto(posts, mediaRepo, author.getId(), "merhaba");
    }

    private CommentView comment(User by, Post p, String text) {
        return service.create(by.getId(), p.getId(), new CreateCommentRequest(text, null));
    }

    private CommentView reply(User by, Post p, CommentView to, String text) {
        return service.create(by.getId(), p.getId(), new CreateCommentRequest(text, to.id()));
    }

    private int postCount(Post p) {
        return posts.findById(p.getId()).orElseThrow().getCommentCount();
    }

    private int replyCount(CommentView c) {
        return commentRepo.findById(c.id()).orElseThrow().getReplyCount();
    }

    private static String code(Runnable r) {
        return assertThrows(ApiException.class, r::run).code();
    }

    // ---------------------------------------------------------------- yazma + sayaclar

    @Test
    void commentAndReplyUpdateCounters() {
        User author = user("yazar");
        User a = user("ali");
        User b = user("veli");
        Post p = post(author);

        CommentView c1 = comment(a, p, "  harika   foto \n\n\n\n ");
        assertEquals("harika   foto", c1.text(), "bas/son bosluk ve fazla satir sonu temizlenir");
        assertNull(c1.parentId());
        assertTrue(c1.mine());
        assertTrue(c1.canDelete());
        assertFalse(c1.byPostAuthor());
        CommentView r1 = reply(b, p, c1, "katiliyorum");
        assertEquals(c1.id(), r1.parentId());
        assertNull(r1.replyTo(), "ust yoruma yanitta replyTo yok (asil yorum parentId ile belli)");

        assertEquals(2, postCount(p));
        assertEquals(1, replyCount(c1));

        // gonderi sahibi de yorum yapar: byPostAuthor
        CommentView own = comment(author, p, "tesekkurler");
        assertTrue(own.byPostAuthor());
        assertEquals(3, postCount(p));
    }

    @Test
    void replyToReplyIsRejected() {
        User author = user("yazar");
        User a = user("ali");
        User b = user("veli");
        Post p = post(author);
        CommentView c1 = comment(a, p, "ilk");
        CommentView r1 = reply(b, p, c1, "yanit");
        assertEquals("COMMENT_PARENT_INVALID", code(() -> reply(a, p, r1, "yanita yanit")), "yanita yanit yok");
        assertEquals(2, postCount(p));
        assertEquals(1, replyCount(c1));
    }

    @Test
    void textRules() {
        User author = user("yazar");
        User a = user("ali");
        Post p = post(author);
        assertEquals("COMMENT_EMPTY", code(() -> comment(a, p, "   \n ")));
        assertEquals("COMMENT_EMPTY", code(() -> comment(a, p, null)));
        assertEquals("COMMENT_TOO_LONG", code(() -> comment(a, p, "x".repeat(501))));
        assertEquals(500, comment(a, p, "ç".repeat(500)).text().length());
        assertEquals(1, postCount(p));
    }

    @Test
    void profanityIsRejected() {
        User author = user("yazar");
        User a = user("ali");
        Post p = post(author);
        String bad = null;
        for (String l : ProfanityFilter.builtInLines("tr")) {
            if (l.matches("=[a-z]{6,10}")) {
                bad = l.substring(1);
                break;
            }
        }
        assertNotNull(bad);
        final String word = bad;
        FieldApiException e = assertThrows(FieldApiException.class, () -> comment(a, p, "sen " + word));
        assertEquals("CONTENT_PROFANITY", e.code());
        assertEquals(0, postCount(p));
    }

    @Test
    void invisibleOrWrongPostIsNotFound() {
        User author = user("yazar");
        User a = user("ali");
        Post p = post(author);
        Post other = post(author);
        CommentView c = comment(a, p, "ilk");

        // baska gonderiye ait yoruma yanit
        assertEquals("COMMENT_PARENT_INVALID", code(() -> service.create(a.getId(), other.getId(), new CreateCommentRequest("x", c.id()))));
        // yok yorum
        assertEquals("COMMENT_PARENT_INVALID", code(() -> service.create(a.getId(), p.getId(), new CreateCommentRequest("x", 999_999L))));
        // gizlenen gonderi
        p.setHiddenAt(java.time.Instant.now());
        posts.save(p);
        assertEquals("COMMENT_NOT_FOUND", code(() -> comment(a, p, "gizli")));
        assertEquals("COMMENT_NOT_FOUND", code(() -> service.list(a.getId(), p.getId(), null, null, 10)));
        // gizlenen gonderinin yorumu yorum kimligiyle de begenilemez
        assertEquals("COMMENT_NOT_FOUND", code(() -> service.like(author.getId(), c.id())));
    }

    // ---------------------------------------------------------------- liste + sayfalama

    @Test
    void listTopAndNewWithCursorAndReplies() {
        User author = user("yazar");
        User a = user("ali");
        User b = user("veli");
        Post p = post(author);
        List<CommentView> made = new ArrayList<>();
        for (int i = 0; i < 5; i++) {
            made.add(comment(a, p, "yorum " + i));
        }
        service.like(b.getId(), made.get(1).id());
        service.like(author.getId(), made.get(1).id());
        service.like(b.getId(), made.get(3).id());
        for (int i = 0; i < 3; i++) {
            reply(b, p, made.get(0), "y" + i);
        }

        // top: begeni cok olan once (1: 2 begeni, 3: 1 begeni), sonra yeni
        CommentPage top = service.list(b.getId(), p.getId(), null, null, 10);
        assertEquals(8, top.total());
        assertEquals(List.of(made.get(1).id(), made.get(3).id(), made.get(4).id(), made.get(2).id(), made.get(0).id()),
                top.items().stream().map(CommentView::id).toList());
        assertTrue(top.items().get(0).likedByMe());
        assertEquals(2, top.items().get(0).likeCount());
        assertEquals(3, top.items().get(4).replyCount());
        assertNull(top.nextCursor());

        // top imleci: 2 + 2 + 1
        CommentPage t1 = service.list(b.getId(), p.getId(), "top", null, 2);
        assertNotNull(t1.nextCursor());
        CommentPage t2 = service.list(b.getId(), p.getId(), "top", t1.nextCursor(), 2);
        CommentPage t3 = service.list(b.getId(), p.getId(), "top", t2.nextCursor(), 2);
        assertNull(t3.nextCursor());
        Set<Long> seen = new HashSet<>();
        for (CommentPage pg : List.of(t1, t2, t3)) {
            pg.items().forEach(i -> assertTrue(seen.add(i.id()), "sayfalar arasi tekrar yok"));
        }
        assertEquals(5, seen.size());

        // new: id azalan
        CommentPage n1 = service.list(b.getId(), p.getId(), "new", null, 3);
        assertEquals(List.of(made.get(4).id(), made.get(3).id(), made.get(2).id()),
                n1.items().stream().map(CommentView::id).toList());
        CommentPage n2 = service.list(b.getId(), p.getId(), "new", n1.nextCursor(), 3);
        assertEquals(List.of(made.get(1).id(), made.get(0).id()), n2.items().stream().map(CommentView::id).toList());
        assertNull(n2.nextCursor());

        // yanitlar eskiden yeniye, imleçli
        CommentPage r1 = service.replies(b.getId(), made.get(0).id(), null, 2);
        assertEquals(2, r1.items().size());
        assertEquals(3, r1.total());
        CommentPage r2 = service.replies(b.getId(), made.get(0).id(), r1.nextCursor(), 2);
        assertEquals(1, r2.items().size());
        assertNull(r2.nextCursor());
        assertTrue(r1.items().get(0).id() < r1.items().get(1).id());

        // gecersiz sort / imlec
        assertEquals("VALIDATION_ERROR", code(() -> service.list(b.getId(), p.getId(), "bogus", null, 10)));
        assertEquals("POST_CURSOR_INVALID", code(() -> service.list(b.getId(), p.getId(), "new", "zzz", 10)));
        assertEquals("POST_CURSOR_INVALID", code(() -> service.list(b.getId(), p.getId(), "top", "TnwxfDE", 10)));
    }

    @Test
    void blockedAuthorsCommentsAreHiddenBothWays() {
        User author = user("yazar");
        User a = user("ali");
        User b = user("veli");
        Post p = post(author);
        CommentView ca = comment(a, p, "ali yorumu");
        CommentView cb = comment(b, p, "veli yorumu");
        blocks.save(new UserBlock(b.getId(), a.getId()));

        List<Long> seenByB = service.list(b.getId(), p.getId(), "new", null, 10).items().stream().map(CommentView::id).toList();
        assertEquals(List.of(cb.id()), seenByB);
        List<Long> seenByA = service.list(a.getId(), p.getId(), "new", null, 10).items().stream().map(CommentView::id).toList();
        assertEquals(List.of(ca.id()), seenByA);
        assertEquals("COMMENT_NOT_FOUND", code(() -> service.like(b.getId(), ca.id())));
        assertEquals("COMMENT_NOT_FOUND", code(() -> service.get(b.getId(), ca.id())));
        assertEquals("COMMENT_PARENT_INVALID", code(() -> service.create(b.getId(), p.getId(), new CreateCommentRequest("x", ca.id()))));
    }

    // ---------------------------------------------------------------- begeni

    @Test
    void likeIsIdempotentAndCounterConsistent() {
        User author = user("yazar");
        User a = user("ali");
        User b = user("veli");
        Post p = post(author);
        CommentView c = comment(a, p, "ilk");

        LikeState l1 = service.like(b.getId(), c.id());
        LikeState l2 = service.like(b.getId(), c.id());
        assertTrue(l1.liked());
        assertEquals(1, l1.likeCount());
        assertEquals(1, l2.likeCount());
        assertTrue(service.get(b.getId(), c.id()).likedByMe());
        assertFalse(service.get(a.getId(), c.id()).likedByMe());

        LikeState u1 = service.unlike(b.getId(), c.id());
        LikeState u2 = service.unlike(b.getId(), c.id());
        assertFalse(u1.liked());
        assertEquals(0, u1.likeCount());
        assertEquals(0, u2.likeCount());
    }

    // ---------------------------------------------------------------- silme

    @Test
    void authorPostOwnerCanDeleteOthersCannot() {
        User author = user("yazar");
        User a = user("ali");
        User b = user("veli");
        Post p = post(author);
        CommentView c1 = comment(a, p, "ali");
        CommentView c2 = comment(a, p, "ali 2");
        CommentView c3 = comment(a, p, "ali 3");

        assertEquals("COMMENT_FORBIDDEN", code(() -> service.delete(b.getId(), c1.id(), false)));
        service.delete(a.getId(), c1.id(), false); // kendi yorumu
        assertEquals(2, postCount(p));
        service.delete(author.getId(), c2.id(), false); // gonderi sahibi
        assertEquals(1, postCount(p));
        service.delete(b.getId(), c3.id(), true); // yonetici mudahalesi
        assertEquals(0, postCount(p));
        assertEquals("COMMENT_NOT_FOUND", code(() -> service.delete(a.getId(), c1.id(), false)));
        assertEquals("", jdbc.queryForObject("SELECT body FROM post_comment WHERE id = ?", String.class, c1.id()),
                "silinen yorumun metni temizlenir (KVKK)");
        assertTrue(service.list(a.getId(), p.getId(), "new", null, 10).items().isEmpty());
    }

    @Test
    void deletingTopLevelWithRepliesLeavesTombstone() {
        User author = user("yazar");
        User a = user("ali");
        User b = user("veli");
        Post p = post(author);
        CommentView c1 = comment(a, p, "ust");
        CommentView keep = comment(a, p, "kalan");
        CommentView r1 = reply(b, p, c1, "y1");
        CommentView r2 = reply(b, p, c1, "y2");
        assertEquals(4, postCount(p));

        service.delete(b.getId(), r1.id(), false);
        assertEquals(3, postCount(p));
        assertEquals(1, replyCount(c1));

        // yanitli ust yorum silinince tombstone kalir, yanit kalir
        service.delete(a.getId(), c1.id(), false);
        assertEquals(2, postCount(p));
        CommentPage page = service.list(b.getId(), p.getId(), "new", null, 10);
        assertEquals(List.of(keep.id(), c1.id()), page.items().stream().map(CommentView::id).toList());
        CommentView tomb = page.items().get(1);
        assertTrue(tomb.deleted());
        assertNull(tomb.author());
        assertNull(tomb.body());
        assertNull(tomb.text());
        assertFalse(tomb.mine());
        assertFalse(tomb.canDelete());
        assertEquals(1, tomb.replyCount());
        assertEquals(List.of(r2.id()), service.replies(b.getId(), c1.id(), null, 10).items().stream().map(CommentView::id).toList());
        assertFalse(service.replies(b.getId(), c1.id(), null, 10).items().get(0).deleted());
        assertEquals("COMMENT_PARENT_INVALID", code(() -> reply(b, p, c1, "silinene yanit")));
        // yanit begenilebilir
        assertEquals(1, service.like(a.getId(), r2.id()).likeCount());

        // son yanit da silinince tombstone listeden kalkar
        service.delete(b.getId(), r2.id(), false);
        assertEquals(1, postCount(p));
        assertEquals(List.of(keep.id()), service.list(b.getId(), p.getId(), "new", null, 10).items().stream().map(CommentView::id).toList());
    }

    @Test
    void viewCarriesContractFieldsAndJsonAliasBody() throws Exception {
        User author = user("yazar");
        User a = user("ali");
        a.setUsername("ali" + System.nanoTime() % 100000);
        users.save(a);
        Post p = post(author);
        CreateCommentRequest req = new com.fasterxml.jackson.databind.ObjectMapper()
                .readValue("{\"body\":\"merhaba\",\"parentId\":null}", CreateCommentRequest.class);
        CommentView c = service.create(a.getId(), p.getId(), req);
        assertEquals("merhaba", c.body());
        assertEquals("merhaba", c.text());
        assertFalse(c.deleted());
        assertEquals(a.getId(), c.author().userId());
        assertEquals(a.getUsername(), c.author().username());
        assertEquals(1, posts.findById(p.getId()).orElseThrow().getCommentCount());
    }

    @Test
    void likeNotifiesOnceAndNeverSelf() {
        User author = user("yazar");
        User a = user("ali");
        User b = user("veli");
        Post p = post(author);
        CommentView c = comment(a, p, "begen");
        String sql = "SELECT COUNT(*) FROM notification WHERE user_id = ? AND type = 'COMMENT_LIKE'";
        service.like(a.getId(), c.id()); // kendi yorumu
        assertEquals(0, jdbc.queryForObject(sql, Integer.class, a.getId()));
        service.like(b.getId(), c.id());
        service.like(b.getId(), c.id()); // cift PUT
        assertEquals(1, jdbc.queryForObject(sql, Integer.class, a.getId()));
        service.unlike(b.getId(), c.id());
        service.like(b.getId(), c.id()); // geri alip tekrar: yeni bildirim yok
        assertEquals(1, jdbc.queryForObject(sql, Integer.class, a.getId()));
        // baska kisi ayni pencerede: yeni satir degil, ayni satir birlesir (grup sayaci 2, govde "ve 1 kisi")
        service.like(author.getId(), c.id());
        assertEquals(1, jdbc.queryForObject(sql, Integer.class, a.getId()));
        assertEquals(2, jdbc.queryForObject(
                "SELECT group_count FROM notification WHERE user_id = ? AND type = 'COMMENT_LIKE'", Integer.class, a.getId()));
        String body = jdbc.queryForObject(
                "SELECT body FROM notification WHERE user_id = ? AND type = 'COMMENT_LIKE'", String.class, a.getId());
        assertTrue(body.contains("1"), body);
        String data = jdbc.queryForObject(
                "SELECT data FROM notification WHERE user_id = ? AND type = 'COMMENT_LIKE'", String.class, a.getId());
        assertTrue(data.contains("\"commentId\""), data);
    }

    // ---------------------------------------------------------------- moderasyon (rapor + yonetici)

    @Test
    void reportHandlerHidesRecountsAndRestores() {
        User author = user("yazar");
        User a = user("ali");
        User b = user("veli");
        Post p = post(author);
        CommentView c1 = comment(a, p, "kotu yorum");
        reply(b, p, c1, "yanit");
        assertEquals(2, postCount(p));

        assertTrue(reportHandler.exists(c1.id()));
        assertTrue(reportHandler.exists(b.getId(), c1.id()));
        assertEquals(a.getId(), reportHandler.ownerId(c1.id()).orElseThrow());
        assertEquals("kotu yorum", reportHandler.preview(c1.id()).orElseThrow().text());
        assertTrue(reportHandler.reversible());

        reportHandler.hide(c1.id());
        assertEquals(0, postCount(p), "gizli ust yorum + yaniti sayilmaz");
        assertFalse(reportHandler.exists(b.getId(), c1.id()), "gizli yorum raporlayana gorunmez");
        assertTrue(service.list(b.getId(), p.getId(), "new", null, 10).items().isEmpty());

        reportHandler.unhide(c1.id());
        assertEquals(2, postCount(p));
        assertEquals(1, replyCount(c1));
        assertTrue(reportHandler.exists(b.getId(), c1.id()));

        blocks.save(new UserBlock(b.getId(), a.getId()));
        assertFalse(reportHandler.exists(b.getId(), c1.id()), "engelli yorum raporlanamaz (varlik sizdirilmaz)");
    }

    @Test
    void adminHideUnhideDeleteAndList() {
        User author = user("yazar");
        User a = user("ali");
        Post p = post(author);
        CommentView c1 = comment(a, p, "yorum 1");
        CommentView c2 = comment(a, p, "yorum 2");

        var row = admin.hide(c1.id(), "kural ihlali");
        assertTrue(row.hidden());
        assertEquals("kural ihlali", row.hiddenReason());
        assertEquals(1, postCount(p));
        assertEquals(1, admin.list(p.getId(), null, 10, "VISIBLE").items().size());
        assertEquals(1, admin.list(p.getId(), null, 10, "HIDDEN").items().size());
        assertEquals(2, admin.list(p.getId(), null, 10, null).items().size());

        assertFalse(admin.unhide(c1.id()).hidden());
        assertEquals(2, postCount(p));

        admin.delete(1L, c2.id(), "spam");
        assertEquals(1, postCount(p));
        assertEquals(1, admin.list(p.getId(), null, 10, "DELETED").items().size());
        assertEquals("COMMENT_NOT_FOUND", code(() -> admin.delete(1L, c2.id(), null)));
        assertEquals("VALIDATION_ERROR", code(() -> admin.list(p.getId(), null, 10, "BOGUS")));
        assertEquals("POST_NOT_FOUND", code(() -> admin.list(987_654L, null, 10, null)));
    }

    // ---------------------------------------------------------------- KVKK + sayac onarimi

    @Test
    void accountPurgeScrubsCommentsAndRemovesLikesAndSaves() {
        User author = user("yazar");
        User a = user("ali");
        User b = user("veli");
        Post p = post(author);
        CommentView mine = comment(a, p, "silinecek yorum");
        CommentView other = comment(b, p, "baskasi");
        service.like(a.getId(), other.id());
        jdbc.update("INSERT INTO post_save (user_id, post_id, created_at) VALUES (?, ?, CURRENT_TIMESTAMP)", a.getId(), p.getId());
        assertEquals(2, postCount(p));

        purger.purge(a.getId());

        assertEquals(1, postCount(p));
        assertEquals("", jdbc.queryForObject("SELECT body FROM post_comment WHERE id = ?", String.class, mine.id()));
        assertEquals(0, commentRepo.findById(other.id()).orElseThrow().getLikeCount());
        assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM post_comment_like WHERE user_id = ?", Integer.class, a.getId()));
        assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM post_save WHERE user_id = ?", Integer.class, a.getId()));
    }

    @Test
    void repairFixesDriftedCounters() {
        User author = user("yazar");
        User a = user("ali");
        Post p = post(author);
        CommentView c1 = comment(a, p, "ilk");
        reply(a, p, c1, "yanit");
        service.like(author.getId(), c1.id());
        jdbc.update("UPDATE post SET comment_count = 42 WHERE id = ?", p.getId());
        jdbc.update("UPDATE post_comment SET reply_count = 9, like_count = 7 WHERE id = ?", c1.id());

        assertTrue(counters.repairAll() >= 3);

        assertEquals(2, postCount(p));
        assertEquals(1, replyCount(c1));
        assertEquals(1, commentRepo.findById(c1.id()).orElseThrow().getLikeCount());
    }

    @Test
    void postViewCarriesCommentCount() {
        User author = user("yazar");
        User a = user("ali");
        Post p = post(author);
        comment(a, p, "bir");
        comment(a, p, "iki");
        PostView v = postService.get(a.getId(), p.getId());
        assertEquals(2, v.commentCount());
        assertFalse(v.savedByMe());
    }
}
