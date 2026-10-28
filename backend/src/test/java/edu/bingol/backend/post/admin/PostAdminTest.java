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
import edu.bingol.backend.moderation.Report;
import edu.bingol.backend.moderation.ReportReason;
import edu.bingol.backend.moderation.ReportRepository;
import edu.bingol.backend.moderation.ReportTargetHandler;
import edu.bingol.backend.moderation.ReportTargetType;
import edu.bingol.backend.post.PostDtos.CreatePostRequest;
import edu.bingol.backend.post.PostFixtures;
import edu.bingol.backend.post.PostService;
import edu.bingol.backend.post.admin.AdminPostService.PostPage;
import edu.bingol.backend.post.admin.AdminPostService.PostRow;
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
    @Autowired ReportRepository reports;
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

        assertEquals(List.of(p3, p2, p1), ids(admin.list(null, 50, q, null, null, null, null, null, null, null, null)));
        assertEquals(List.of(p2), ids(admin.list(null, 50, q, true, null, null, null, null, null, null, null)));
        assertEquals(List.of(p3), ids(admin.list(null, 50, q, null, true, null, null, null, null, null, null)));
        assertEquals(List.of(p1), ids(admin.list(null, 50, q, false, false, false, null, null, null, null, null)));
        assertEquals(List.of(), ids(admin.list(null, 50, q, null, null, true, null, null, null, null, null)));

        PostPage first = admin.list(null, 2, q, null, null, null, null, null, null, null, null);
        assertEquals(2, first.items().size());
        assertNotNull(first.nextCursor());
        PostPage second = admin.list(first.nextCursor(), 2, q, null, null, null, null, null, null, null, null);
        assertEquals(List.of(p1), ids(second));
        assertNull(second.nextCursor());
        // LIKE ozel karakterleri joker olmaz
        assertEquals(List.of(), ids(admin.list(null, 50, "%", null, null, null, null, null, null, null, null)));
        assertThrows(ApiException.class, () -> admin.list(null, 5, null, null, null, null, "bozuk", null, null, null, null));
    }

    @Test
    void deleteWithReasonNotifiesAuthorAndStoresReason() {
        User a = user("Yazar");
        long id = photoPost(a, "silinecek");
        int before = notifCount(a.getId());

        admin.delete(1L, id, "  uygunsuz  ");

        AdminPostService.PostRow row = admin.detail(id).post();
        assertTrue(row.deleted());
        assertEquals(1L, row.deletedBy());
        assertEquals("uygunsuz", row.hiddenReason());
        assertEquals(before + 1, notifCount(a.getId()), "yazara kaldirildi bildirimi");
        assertThrows(ApiException.class, () -> admin.detail(-1));
        assertEquals("POST_NOT_FOUND", assertThrows(ApiException.class, () -> admin.delete(1L, id, null)).code());
    }

    @Test
    void editTextKeepsFormatRulesAndSkipsProfanityGuard() {
        User a = user("Duzenlenen");
        long id = photoPost(a, "kotu metin");
        int before = notifCount(a.getId());

        PostRow edited = admin.editText(id, "  temiz metin  ");
        assertEquals("temiz metin", edited.text());
        assertNotNull(edited.editedAt());
        assertEquals(before + 1, notifCount(a.getId()), "yazara duzenleme bildirimi");

        assertNull(admin.editText(id, "   ").text(), "bos metin temizlenir (fotograf kalir)");
        assertEquals("POST_TEXT_INVALID", assertThrows(ApiException.class, () -> admin.editText(id, "iki\nsatir")).code());
        assertEquals("POST_TEXT_TOO_LONG", assertThrows(ApiException.class,
                () -> admin.editText(id, "bir iki uc dort bes alti yedi sekiz")).code());
        assertEquals("POST_NOT_FOUND", assertThrows(ApiException.class, () -> admin.editText(-1, "x")).code());
        long textOnly = post(a, "fotografsiz");
        assertEquals("POST_EMPTY", assertThrows(ApiException.class, () -> admin.editText(textOnly, " ")).code());

        posts.delete(a.getId(), id, false);
        assertEquals("POST_NOT_FOUND", assertThrows(ApiException.class, () -> admin.editText(id, "x")).code());
    }

    @Test
    void statusAuthorAndReportFilters() {
        User a = user("Suzgec " + UUID.randomUUID().toString().substring(0, 6));
        User r = user("Rapor");
        long visible = post(a, "gorunur");
        long hidden = post(a, "gizli");
        long deleted = post(a, "silinmis");
        admin.hide(hidden, "x");
        posts.delete(a.getId(), deleted, false);
        Report rep = new Report();
        rep.setReporterId(r.getId());
        rep.setTargetType(ReportTargetType.FEED_POST);
        rep.setTargetId(visible);
        rep.setReason(ReportReason.OTHER);
        reports.saveAndFlush(rep);
        // Rapor-silme entegrasyonu (ReportService.resolve) PostgreSQL ozel SQL kullanir (ON CONFLICT): H2'de degil duman betigiyle.
        assertEquals(1, admin.detail(visible).post().openReportCount());
        assertEquals(1, admin.detail(visible).reports().size());
        assertEquals("OPEN", admin.detail(visible).reports().get(0).status());

        assertEquals(List.of(visible), ids(admin.list(null, 50, null, null, null, null, null, null, "VISIBLE", a.getId(), null)));
        assertEquals(List.of(hidden), ids(admin.list(null, 50, null, null, null, null, null, null, "hidden", a.getId(), null)));
        assertEquals(List.of(deleted), ids(admin.list(null, 50, null, null, null, null, null, null, "DELETED", a.getId(), null)));
        assertEquals(3, admin.list(null, 50, null, null, null, null, null, null, "ALL", a.getId(), null).items().size());
        assertEquals(List.of(visible), ids(admin.list(null, 50, null, null, null, null, null, null, null, a.getId(), 1)));
        assertEquals(List.of(), ids(admin.list(null, 50, null, null, null, null, null, null, null, a.getId(), 2)));
        assertEquals(List.of(hidden), ids(admin.list(null, 50, "gizli", null, null, null, null, null, null, a.getId(), null)),
                "metin aramasi");
        assertEquals("VALIDATION_ERROR", assertThrows(ApiException.class,
                () -> admin.list(null, 5, null, null, null, null, null, null, "bozuk", null, null)).code());
    }

    private int notifCount(Long userId) {
        Integer n = jdbc.queryForObject("SELECT COUNT(*) FROM notification WHERE user_id = ?", Integer.class, userId);
        return n == null ? 0 : n;
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
    void exportersCoverOwnDataOnly() {
        User a = user("Disa Aktar");
        User o = user("Baska");
        long mine = post(a, "benim gonderim");
        long other = post(o, "baskasi");
        likes.like(a.getId(), other);
        likes.like(o.getId(), mine);

        Map<?, ?> p = (Map<?, ?>) export("posts", a.getId());
        assertEquals(1, p.get("count"));
        assertFalse(p.toString().contains("baskasi"));
        assertTrue(exporters.stream().noneMatch(e -> e.section().equals("postComments")));
        assertEquals(1, ((Map<?, ?>) export("postLikes", a.getId())).get("count"));
    }

    private Object export(String section, Long uid) {
        return exporters.stream().filter(e -> e.section().equals(section)).findFirst().orElseThrow().export(uid);
    }

    @Test
    void accountPurgeRemovesPostsAndLikes() {
        User a = user("Silinecek");
        User o = user("Kalan");
        long mine = post(a, "silinecek gonderi");
        long other = post(o, "kalan gonderi");
        likes.like(a.getId(), other);

        purger.purge(a.getId());

        assertTrue(admin.detail(mine).post().deleted());
        assertFalse(admin.detail(other).post().deleted());
        assertEquals(0, admin.detail(other).post().likeCount());
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

    @Test
    void searchVisibilityMatchesFeed() {
        User u = user("Aranan");
        long photo = photoPost(u, "arama metni");
        long textOnly = post(u, "arama metni");
        List<Long> found = jdbc.queryForList("SELECT p.id FROM post p JOIN app_user u ON u.id = p.author_id WHERE "
                + PostSearchProvider.VISIBLE_SQL, Long.class);
        assertTrue(found.contains(photo));
        assertFalse(found.contains(textOnly), "fotografsiz gonderi aramada gorunmez");
        // akisla tutarlilik
        assertTrue(inFeed(u, photo));
        assertFalse(inFeed(u, textOnly));
    }
}
