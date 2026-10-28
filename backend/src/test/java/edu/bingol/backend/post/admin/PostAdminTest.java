package edu.bingol.backend.post.admin;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.export.DataExporter;
import edu.bingol.backend.moderation.MediaPreview;
import edu.bingol.backend.moderation.ReportTargetHandler;
import edu.bingol.backend.moderation.ReportTargetType;
import edu.bingol.backend.post.PostDtos.CreatePostRequest;
import edu.bingol.backend.post.PostFixtures;
import edu.bingol.backend.post.PostService;
import edu.bingol.backend.post.admin.AdminPostService.CommentPage;
import edu.bingol.backend.post.admin.AdminPostService.PostPage;
import edu.bingol.backend.post.admin.AdminPostService.PostRow;
import edu.bingol.backend.post.comment.PostCommentService;
import edu.bingol.backend.post.like.PostLikeService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

/** Yonetici gonderi moderasyonu, rapor handler'lari, KVKK disa aktarim/silme, saklama isi (H2, gercek bean'ler). */
@SpringBootTest
class PostAdminTest {

    @Autowired AdminPostService admin;
    @Autowired PostService posts;
    @Autowired edu.bingol.backend.post.PostRepository postRepo;
    @Autowired edu.bingol.backend.post.media.PostMediaRepository mediaRepo;
    @Autowired PostCommentService comments;
    @Autowired PostLikeService likes;
    @Autowired UserRepository users;
    @Autowired JdbcTemplate jdbc;
    @Autowired List<ReportTargetHandler> handlers;
    @Autowired List<DataExporter> exporters;
    @Autowired PostAccountPurger purger;
    @Autowired PostRetentionJob retention;

    private User user(String name) {
        User u = new User();
        u.setEmail("e" + UUID.randomUUID().toString().substring(0, 8) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName(name);
        u.setEmailVerified(true);
        return users.saveAndFlush(u);
    }

    /** Fotografsiz (yonetici listeleri/handler/saklama testleri; akis disinda). */
    private long post(User u, String text) {
        return PostFixtures.textOnly(postRepo, u.getId(), text).getId();
    }

    /** Fotografli: sade Kesfet'te akista gorunen gonderi. */
    private long photoPost(User u, String text) {
        return PostFixtures.withPhoto(postRepo, mediaRepo, u.getId(), text).getId();
    }

    private ReportTargetHandler handler(ReportTargetType t) {
        return handlers.stream().filter(h -> h.type() == t).findFirst().orElseThrow();
    }

    private boolean inFeed(User viewer, long postId) {
        return posts.feed(viewer.getId(), "latest", null, 20).items().stream().anyMatch(p -> p.id().equals(postId));
    }

    private static List<Long> ids(PostPage p) {
        return p.items().stream().map(PostRow::id).toList();
    }

    @Test
    void hideRemovesFromFeedAndUnhideRestores() {
        User a = user("Yazar Bir");
        User v = user("Okur");
        long id = photoPost(a, "gizlenecek gonderi");
        assertTrue(inFeed(v, id));

        PostRow hidden = admin.hide(id, "  spam  ");
        assertTrue(hidden.hidden());
        assertEquals("spam", hidden.hiddenReason());
        assertFalse(inFeed(v, id));
        assertTrue(admin.hide(id, null).hidden()); // idempotent

        PostRow back = admin.unhide(id);
        assertFalse(back.hidden());
        assertNull(back.hiddenReason());
        assertTrue(inFeed(v, id));
    }

    @Test
    void listFiltersAndCursor() {
        User a = user("Filtre Yazari " + UUID.randomUUID().toString().substring(0, 6));
        long p1 = post(a, "bir");
        long p2 = post(a, "iki");
        long p3 = post(a, "uc");
        admin.hide(p2, "x");
        posts.delete(a.getId(), p3, false);
        String q = a.getDisplayName();

        assertEquals(List.of(p3, p2, p1), ids(admin.list(null, 50, q, null, null, null, null, null)));
        assertEquals(List.of(p2), ids(admin.list(null, 50, q, true, null, null, null, null)));
        assertEquals(List.of(p3), ids(admin.list(null, 50, q, null, true, null, null, null)));
        assertEquals(List.of(p1), ids(admin.list(null, 50, q, false, false, false, null, null)));
        assertEquals(List.of(), ids(admin.list(null, 50, q, null, null, true, null, null)));

        PostPage first = admin.list(null, 2, q, null, null, null, null, null);
        assertEquals(2, first.items().size());
        assertNotNull(first.nextCursor());
        PostPage second = admin.list(first.nextCursor(), 2, q, null, null, null, null, null);
        assertEquals(List.of(p1), ids(second));
        assertNull(second.nextCursor());
        // LIKE ozel karakterleri joker olmaz
        assertEquals(List.of(), ids(admin.list(null, 50, "%", null, null, null, null, null)));
        assertThrows(ApiException.class, () -> admin.list(null, 5, null, null, null, null, "bozuk", null));
    }

    @Test
    void deleteAndCommentModeration() {
        User a = user("Yazar");
        User c = user("Yorumcu");
        long id = post(a, "yorumlu");
        long cid = comments.create(c.getId(), id, "guzel", null).id();
        long rid = comments.create(a.getId(), id, "tesekkurler", cid).id();

        CommentPage page = admin.comments(id, null, 10);
        assertEquals(2, page.items().size());
        assertTrue(admin.hideComment(cid).hidden());
        assertFalse(admin.unhideComment(cid).hidden());

        admin.deleteComment(1L, rid);
        assertTrue(admin.comments(id, null, 10).items().stream().filter(x -> x.id() == rid).findFirst().orElseThrow().deleted());
        assertThrows(ApiException.class, () -> admin.hideComment(-5));

        admin.delete(1L, id);
        assertTrue(admin.detail(id).post().deleted());
        assertEquals(1L, admin.detail(id).post().deletedBy());
        assertThrows(ApiException.class, () -> admin.detail(-1));
    }

    @Test
    void statsCountVisibleAndHidden() {
        User a = user("Istatistik");
        long p = post(a, "s1");
        post(a, "s2");
        admin.hide(p, null);
        AdminPostService.Stats s = admin.stats();
        assertTrue(s.postCount() >= 2);
        assertTrue(s.hiddenCount() >= 1);
        assertTrue(s.last24h().postCount() >= 2);
    }

    @Test
    void feedPostHandler() {
        User a = user("Sikayetli");
        long id = post(a, "sikayet edilen metin");
        ReportTargetHandler h = handler(ReportTargetType.FEED_POST);
        assertTrue(h.reversible());
        assertTrue(h.exists(id));
        assertEquals(a.getId(), h.ownerId(id).orElseThrow());
        MediaPreview p = h.preview(id).orElseThrow();
        assertEquals("TEXT", p.kind());
        assertEquals("sikayet edilen metin", p.text());

        h.hide(id);
        h.hide(id); // idempotent
        assertTrue(admin.detail(id).post().hidden());
        assertTrue(h.exists(id)); // gizli gonderi itiraz icin "var"
        h.unhide(id);
        assertFalse(admin.detail(id).post().hidden());

        posts.delete(a.getId(), id, false);
        assertFalse(h.exists(id));
        assertTrue(h.preview(id).isEmpty());
        assertFalse(h.exists(-1L));
        assertTrue(h.ownerId(-1L).isEmpty());
    }

    @Test
    void feedCommentHandler() {
        User a = user("Yazar");
        User c = user("Yorumcu");
        long id = post(a, "metin");
        long cid = comments.create(c.getId(), id, "kotu yorum", null).id();
        ReportTargetHandler h = handler(ReportTargetType.FEED_COMMENT);
        assertTrue(h.exists(cid));
        assertEquals(c.getId(), h.ownerId(cid).orElseThrow());
        assertEquals("kotu yorum", h.preview(cid).orElseThrow().text());
        h.hide(cid);
        assertTrue(admin.comments(id, null, 10).items().get(0).hidden());
        h.unhide(cid);
        assertFalse(admin.comments(id, null, 10).items().get(0).hidden());
        comments.delete(c.getId(), cid, false);
        assertFalse(h.exists(cid));
    }

    @Test
    void exportersCoverOwnDataOnly() {
        User a = user("Disa Aktar");
        User o = user("Baska");
        long mine = post(a, "benim gonderim");
        long other = post(o, "baskasi");
        comments.create(a.getId(), other, "benim yorumum", null);
        likes.like(a.getId(), other);
        likes.like(o.getId(), mine);

        Map<?, ?> p = (Map<?, ?>) export("posts", a.getId());
        assertEquals(1, p.get("count"));
        assertFalse(p.toString().contains("baskasi"));
        assertEquals(1, ((Map<?, ?>) export("postComments", a.getId())).get("count"));
        assertEquals(1, ((Map<?, ?>) export("postLikes", a.getId())).get("count"));
    }

    private Object export(String section, Long uid) {
        return exporters.stream().filter(e -> e.section().equals(section)).findFirst().orElseThrow().export(uid);
    }

    @Test
    void accountPurgeRemovesPostsLikesComments() {
        User a = user("Silinecek");
        User o = user("Kalan");
        long mine = post(a, "silinecek gonderi");
        long other = post(o, "kalan gonderi");
        comments.create(a.getId(), other, "silinecek yorum", null);
        likes.like(a.getId(), other);

        purger.purge(a.getId());

        assertTrue(admin.detail(mine).post().deleted());
        assertFalse(admin.detail(other).post().deleted());
        assertEquals(0, admin.detail(other).post().likeCount());
        assertEquals(0, admin.detail(other).post().commentCount());
        assertEquals(0L, jdbc.queryForObject("SELECT COUNT(*) FROM post_like WHERE user_id = ?", Long.class, a.getId()));
    }

    @Test
    void retentionPurgesOldDeletedAndSoftDeletesLongHidden() {
        User a = user("Saklama");
        long oldDeleted = post(a, "eski silinmis");
        long freshDeleted = post(a, "yeni silinmis");
        long oldHidden = post(a, "eski gizli");
        long freshHidden = post(a, "yeni gizli");
        long live = post(a, "canli");
        posts.delete(a.getId(), oldDeleted, false);
        posts.delete(a.getId(), freshDeleted, false);
        admin.hide(oldHidden, null);
        admin.hide(freshHidden, null);
        Instant old = Instant.now().minus(45, ChronoUnit.DAYS);
        jdbc.update("UPDATE post SET deleted_at = ? WHERE id = ?", java.sql.Timestamp.from(old), oldDeleted);
        jdbc.update("UPDATE post SET hidden_at = ? WHERE id = ?", java.sql.Timestamp.from(old), oldHidden);

        int n = retention.run(Instant.now());

        assertTrue(n >= 1);
        assertEquals(0L, count(oldDeleted));
        assertEquals(1L, count(freshDeleted));
        assertEquals(1L, count(live));
        // uzun suredir gizli: yumusak silindi (kalici silme 30 gun sonra)
        assertTrue(admin.detail(oldHidden).post().deleted());
        assertFalse(admin.detail(freshHidden).post().deleted());
        retention.run(Instant.now()); // idempotent
        assertEquals(1L, count(oldHidden));
    }

    private long count(long postId) {
        return jdbc.queryForObject("SELECT COUNT(*) FROM post WHERE id = ?", Long.class, postId);
    }

    @Test
    void searchSnippetTrimsAndFlattens() {
        assertNull(PostSearchProvider.snippet("   "));
        assertEquals("a b", PostSearchProvider.snippet("a\n  b"));
        assertTrue(PostSearchProvider.snippet("x".repeat(400)).length() <= 161);
    }
}
