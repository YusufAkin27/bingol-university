package edu.bingol.backend.forum.media;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.forum.category.ForumCategory;
import edu.bingol.backend.forum.category.ForumCategoryRepository;
import edu.bingol.backend.forum.topic.ForumTestSupport;
import edu.bingol.backend.forum.topic.ForumTopicDtos.CreateTopicRequest;
import edu.bingol.backend.forum.topic.ForumTopicService;
import edu.bingol.backend.forum.topic.dto.TopicView;
import edu.bingol.backend.forum.topic.spi.ForumTopicStateService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

/** Forum gorseli: yukleme dogrulamasi, konuya atomik baglama, erisim kurallari, supurucu (H2 + gercek ozel depo). */
@SpringBootTest
class ForumMediaServiceTest {

    @MockitoBean edu.bingol.backend.common.RateLimiter limiter;

    @Autowired ForumMediaService media;
    @Autowired ForumMediaRepository repo;
    @Autowired ForumTopicService topics;
    @Autowired ForumTopicStateService state;
    @Autowired ForumCategoryRepository cats;
    @Autowired UserRepository users;
    @Autowired JdbcTemplate jdbc;

    private ForumCategory cat;

    @BeforeEach
    void setUp() {
        org.springframework.context.i18n.LocaleContextHolder.setLocale(java.util.Locale.forLanguageTag("tr"));
        cat = ForumTestSupport.category(cats, "Medya");
    }

    private User u(String n) {
        return ForumTestSupport.user(users, n);
    }

    private ForumMediaService.Uploaded up(User by) {
        return media.upload(by.getId(), new MockMultipartFile("file", "a.png", "image/png", ForumTestSupport.png(64, 48)));
    }

    private TopicView topicWith(User by, List<Long> ids) {
        return topics.create(by.getId(), new CreateTopicRequest("Resimli " + java.util.UUID.randomUUID(), "govde", cat.getId(), false, ids, null), null);
    }

    private static String code(Runnable r) {
        return assertThrows(ApiException.class, r::run).code();
    }

    @Test
    void uploadReencodesAndServesOnlyToOwnerUntilAttached() {
        User me = u("ben");
        User other = u("diger");
        ForumMediaService.Uploaded up = up(me);
        assertNotNull(up.id());
        assertEquals("/api/forum/media/" + up.id(), up.url());
        assertEquals("/api/forum/media/" + up.id() + "?thumb=true", up.thumbUrl());
        assertEquals(64, up.width());
        assertEquals(48, up.height());

        ResponseEntity<Resource> own = media.serve(me.getId(), up.id(), false, null);
        assertEquals(HttpStatus.OK, own.getStatusCode());
        assertTrue(own.getHeaders().getContentType().toString().startsWith("image/"));
        assertEquals("nosniff", own.getHeaders().getFirst("X-Content-Type-Options"));
        String etag = own.getHeaders().getETag();
        assertNotNull(etag);
        assertEquals(HttpStatus.NOT_MODIFIED, media.serve(me.getId(), up.id(), false, etag).getStatusCode());
        assertEquals(HttpStatus.OK, media.serve(me.getId(), up.id(), true, null).getStatusCode());
        assertEquals("FORUM_MEDIA_NOT_FOUND", code(() -> media.serve(other.getId(), up.id(), false, null)),
                "baglanmamis gorsel yalniz sahibine");
        assertEquals("FORUM_MEDIA_NOT_FOUND", code(() -> media.serve(me.getId(), 987654321L, false, null)));
    }

    @Test
    void rejectsNonImagesEmptyAndOversizedContent() {
        User me = u("ben");
        assertThrows(ApiException.class, () -> media.upload(me.getId(),
                new MockMultipartFile("file", "x.png", "image/png", "bu bir resim degil".getBytes())));
        assertThrows(ApiException.class, () -> media.upload(me.getId(),
                new MockMultipartFile("file", "x.png", "image/png", new byte[0])));
        assertThrows(ApiException.class, () -> media.upload(me.getId(),
                new MockMultipartFile("file", "x.html", "text/html", "<script>alert(1)</script>".getBytes())));
        assertEquals(0, repo.countUnattached(me.getId()));
    }

    @Test
    void attachingMakesImagesVisibleToOthersAndFollowsTopicVisibility() {
        User me = u("ben");
        User other = u("diger");
        ForumMediaService.Uploaded a = up(me);
        ForumMediaService.Uploaded b = up(me);
        TopicView t = topicWith(me, List.of(b.id(), a.id()));
        assertEquals(2, t.images().size());
        assertEquals(b.id(), t.images().get(0).id(), "sira korunur");
        assertEquals(2, t.imageCount());
        assertEquals(b.id(), t.thumbnail().id());
        assertEquals(HttpStatus.OK, media.serve(other.getId(), a.id(), false, null).getStatusCode(), "baglanmis gorsel gorunur konuda herkese");

        state.remove(t.id(), "ihlal");
        assertEquals("FORUM_MEDIA_NOT_FOUND", code(() -> media.serve(other.getId(), a.id(), false, null)),
                "kaldirilmis konunun gorseli 404");
        assertEquals("FORUM_MEDIA_NOT_FOUND", code(() -> media.serve(me.getId(), a.id(), false, null)));
        state.restore(t.id());
        assertEquals(HttpStatus.OK, media.serve(other.getId(), a.id(), false, null).getStatusCode());
    }

    @Test
    void attachRulesAreStrictAndAtomic() {
        User me = u("ben");
        User other = u("diger");
        ForumMediaService.Uploaded mine = up(me);
        ForumMediaService.Uploaded theirs = up(other);
        assertEquals("FORUM_MEDIA_INVALID", code(() -> topicWith(me, List.of(theirs.id()))), "baskasinin gorseli");
        assertEquals("FORUM_MEDIA_INVALID", code(() -> topicWith(me, List.of(mine.id(), mine.id()))), "tekrar eden kimlik");
        assertEquals("FORUM_MEDIA_INVALID", code(() -> topicWith(me, List.of(mine.id(), 777777L))), "olmayan gorsel");
        // basarisiz olusturmada ilk gorsel de baglanmamis kalir (tek transaction) ve konu olusmaz
        assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM forum_topic_image WHERE media_id = ?", Integer.class, mine.id()));
        TopicView ok = topicWith(me, List.of(mine.id()));
        assertEquals(1, ok.images().size());
        assertEquals("FORUM_MEDIA_INVALID", code(() -> topicWith(me, List.of(mine.id()))), "kullanilmis gorsel ikinci konuya baglanmaz");
    }

    @Test
    void maxFourImagesPerTopic() {
        User me = u("ben");
        List<Long> ids = new ArrayList<>();
        for (int i = 0; i < 4; i++) {
            ids.add(up(me).id());
        }
        TopicView ok = topicWith(me, ids);
        assertEquals(4, ok.images().size());
        ids.add(up(me).id());
        assertEquals("FORUM_TOO_MANY_IMAGES", code(() -> topicWith(me, ids)));
    }

    @Test
    void pendingLimitAndCancelOfUnattachedUpload() {
        User me = u("ben");
        User other = u("diger");
        ForumMediaService.Uploaded x = up(me);
        assertEquals(1, repo.countUnattached(me.getId()));
        assertEquals("FORUM_MEDIA_NOT_FOUND", code(() -> media.deleteUnattached(other.getId(), x.id())));
        media.deleteUnattached(me.getId(), x.id());
        assertEquals(0, repo.countUnattached(me.getId()));
        ForumMediaService.Uploaded y = up(me);
        topicWith(me, List.of(y.id()));
        assertEquals("FORUM_MEDIA_INVALID", code(() -> media.deleteUnattached(me.getId(), y.id())), "baglanmis gorsel silinemez");

        List<ForumMediaService.Uploaded> many = new ArrayList<>();
        for (int i = 0; i < 12; i++) {
            many.add(up(me));
        }
        assertEquals("FORUM_MEDIA_PENDING_LIMIT", code(() -> up(me)));
    }

    @Test
    void sweepRemovesOnlyOldUnattachedUploads() {
        User me = u("ben");
        ForumMediaService.Uploaded old = up(me);
        ForumMediaService.Uploaded fresh = up(me);
        ForumMediaService.Uploaded attached = up(me);
        topicWith(me, List.of(attached.id()));
        jdbc.update("UPDATE forum_media SET created_at = ? WHERE id IN (?, ?)",
                java.sql.Timestamp.from(java.time.Instant.now().minus(Duration.ofDays(3))), old.id(), attached.id());

        int n = media.sweepUnattached(Duration.ofHours(24));
        assertTrue(n >= 1);
        assertFalse(repo.existsById(old.id()), "eski ve baglanmamis silinir");
        assertTrue(repo.existsById(fresh.id()), "yeni yukleme kalir");
        assertTrue(repo.existsById(attached.id()), "baglanmis gorsel eski olsa da kalir");
    }

    @Test
    void deletedTopicMediaIsRemovedAfterRetention() {
        User me = u("ben");
        ForumMediaService.Uploaded m = up(me);
        TopicView t = topicWith(me, List.of(m.id()));
        topics.delete(me.getId(), t.id());
        assertTrue(repo.existsById(m.id()), "saklama suresi dolmadan kalir");
        jdbc.update("UPDATE forum_topic SET deleted_at = ? WHERE id = ?",
                java.sql.Timestamp.from(java.time.Instant.now().minus(Duration.ofDays(40))), t.id());
        assertTrue(media.sweepDeleted() >= 1);
        assertFalse(repo.existsById(m.id()));
    }
}
