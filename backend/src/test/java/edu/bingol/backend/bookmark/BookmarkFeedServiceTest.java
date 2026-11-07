package edu.bingol.backend.bookmark;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.bookmark.dto.BookmarkItem;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.news.NewsRepository;
import edu.bingol.backend.post.PostRepository;
import edu.bingol.backend.post.media.PostMediaRepository;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import javax.sql.DataSource;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.embedded.EmbeddedDatabase;
import org.springframework.jdbc.datasource.embedded.EmbeddedDatabaseBuilder;
import org.springframework.jdbc.datasource.embedded.EmbeddedDatabaseType;

/** Birlesik Kaydedilenler: H2 uzerinde okuma birlestirmesi (UNION ALL), imec, suzgec, gorunurluk. */
class BookmarkFeedServiceTest {

    private EmbeddedDatabase db;
    private JdbcTemplate jdbc;
    private BookmarkRepository repo;
    private BookmarkService newsSvc;
    private BookmarkFeedService svc;

    @BeforeEach
    void setUp() {
        db = new EmbeddedDatabaseBuilder().setType(EmbeddedDatabaseType.H2).setName("bm_feed").build();
        jdbc = new JdbcTemplate((DataSource) db);
        jdbc.execute("CREATE TABLE bookmark (id BIGINT AUTO_INCREMENT PRIMARY KEY, user_id BIGINT, target_type VARCHAR(16), target_id BIGINT, created_at TIMESTAMP WITH TIME ZONE)");
        jdbc.execute("CREATE TABLE post_save (user_id BIGINT, post_id BIGINT, created_at TIMESTAMP WITH TIME ZONE)");
        jdbc.execute("CREATE TABLE forum_bookmark (user_id BIGINT, target_type VARCHAR(10), target_id BIGINT, created_at TIMESTAMP WITH TIME ZONE)");
        jdbc.execute("CREATE TABLE user_event (id BIGINT PRIMARY KEY, title VARCHAR(150), location VARCHAR(200), cover_url VARCHAR(300), status VARCHAR(16))");
        jdbc.execute("CREATE TABLE community (id BIGINT PRIMARY KEY, name VARCHAR(80), category VARCHAR(40), logo_url VARCHAR(300), cover_url VARCHAR(300), status VARCHAR(16), visibility VARCHAR(16))");
        jdbc.execute("CREATE TABLE community_member (community_id BIGINT, user_id BIGINT, status VARCHAR(16))");
        jdbc.execute("CREATE TABLE poll (id BIGINT PRIMARY KEY, title VARCHAR(150), status VARCHAR(10))");
        jdbc.execute("CREATE TABLE academic_event (id BIGINT PRIMARY KEY, title VARCHAR(150), kind VARCHAR(20), published BOOLEAN)");
        jdbc.execute("CREATE TABLE forum_topic (id BIGINT PRIMARY KEY, title VARCHAR(150), status VARCHAR(10), deleted_at TIMESTAMP WITH TIME ZONE)");
        jdbc.execute("CREATE TABLE forum_comment (id BIGINT PRIMARY KEY, topic_id BIGINT, body VARCHAR(4000), status VARCHAR(16), deleted_at TIMESTAMP WITH TIME ZONE)");

        repo = mock(BookmarkRepository.class);
        newsSvc = mock(BookmarkService.class);
        svc = new BookmarkFeedService(jdbc, repo, mock(NewsRepository.class), newsSvc, mock(PostRepository.class),
                mock(PostMediaRepository.class));
    }

    @AfterEach
    void tearDown() {
        db.shutdown();
    }

    private static Timestamp ts(String iso) {
        return Timestamp.from(Instant.parse(iso));
    }

    private void bm(long uid, String type, long id, String at) {
        jdbc.update("INSERT INTO bookmark (user_id, target_type, target_id, created_at) VALUES (?,?,?,?)",
                uid, type, id, ts(at));
    }

    @Test
    void mergesBookmarkAndForumNewestFirstAndDropsInvisible() {
        jdbc.update("INSERT INTO user_event VALUES (1,'Turnuva','Salon','/files/a.jpg','ACTIVE'),(2,'Iptal',NULL,NULL,'CANCELLED')");
        jdbc.update("INSERT INTO community VALUES (3,'Satranc','Spor',NULL,'/files/c.jpg','ACTIVE','PUBLIC'),(4,'Gizli',NULL,NULL,NULL,'ACTIVE','PRIVATE')");
        jdbc.update("INSERT INTO poll VALUES (5,'Anket','OPEN')");
        jdbc.update("INSERT INTO academic_event VALUES (6,'Final haftasi','EXAM',TRUE)");
        jdbc.update("INSERT INTO forum_topic VALUES (7,'Konu','ACTIVE',NULL)");
        jdbc.update("INSERT INTO forum_comment VALUES (8,7,'bir yorum','ACTIVE',NULL)");
        bm(1, "EVENT", 1, "2026-01-01T10:00:00Z");
        bm(1, "EVENT", 2, "2026-01-01T10:01:00Z");
        bm(1, "COMMUNITY", 3, "2026-01-01T10:02:00Z");
        bm(1, "COMMUNITY", 4, "2026-01-01T10:03:00Z");
        bm(1, "POLL", 5, "2026-01-01T10:04:00Z");
        bm(1, "ACADEMIC", 6, "2026-01-01T10:05:00Z");
        bm(2, "EVENT", 1, "2026-01-01T10:06:00Z");
        jdbc.update("INSERT INTO forum_bookmark VALUES (1,'TOPIC',7,?),(1,'COMMENT',8,?)",
                ts("2026-01-01T10:07:00Z"), ts("2026-01-01T10:08:00Z"));

        CursorPage<BookmarkItem> page = svc.list(1L, "ALL", null, 20);

        assertNull(page.nextCursor());
        // iptal edilen etkinlik ve uye olunmayan gizli kulup dusurulur; baska kullanicinin kaydi gelmez
        assertEquals(List.of("FORUM_COMMENT", "FORUM_TOPIC", "ACADEMIC", "POLL", "COMMUNITY", "EVENT"),
                page.items().stream().map(BookmarkItem::type).toList());
        BookmarkItem ev = page.items().get(5);
        assertEquals("Turnuva", ev.title());
        assertEquals("/events/1", ev.link());
        assertEquals("/files/a.jpg", ev.imageUrl());
        assertEquals("/files/c.jpg", page.items().get(4).imageUrl());
        assertEquals("bir yorum", page.items().get(0).title());
        assertEquals("Konu", page.items().get(0).subtitle());
    }

    @Test
    void privateCommunityVisibleToActiveMember() {
        jdbc.update("INSERT INTO community VALUES (4,'Gizli',NULL,NULL,NULL,'ACTIVE','PRIVATE')");
        jdbc.update("INSERT INTO community_member VALUES (4,1,'ACTIVE')");
        bm(1, "COMMUNITY", 4, "2026-01-01T10:03:00Z");
        bm(9, "COMMUNITY", 4, "2026-01-01T10:03:00Z");

        assertEquals(1, svc.list(1L, "COMMUNITY", null, 20).items().size());
        assertEquals(0, svc.list(9L, "COMMUNITY", null, 20).items().size());
    }

    @Test
    void cursorPagingAndTypeFilter() {
        for (int i = 1; i <= 5; i++) {
            jdbc.update("INSERT INTO poll VALUES (?, 'Anket', 'OPEN')", i);
            bm(1, "POLL", i, "2026-01-01T10:0" + i + ":00Z");
        }
        bm(1, "EVENT", 99, "2026-01-01T11:00:00Z");

        CursorPage<BookmarkItem> p1 = svc.list(1L, "POLL", null, 2);
        assertEquals(List.of(5L, 4L), p1.items().stream().map(BookmarkItem::targetId).toList());
        assertNotNull(p1.nextCursor());
        CursorPage<BookmarkItem> p2 = svc.list(1L, "POLL", p1.nextCursor(), 2);
        assertEquals(List.of(3L, 2L), p2.items().stream().map(BookmarkItem::targetId).toList());
        CursorPage<BookmarkItem> p3 = svc.list(1L, "POLL", p2.nextCursor(), 2);
        assertEquals(List.of(1L), p3.items().stream().map(BookmarkItem::targetId).toList());
        assertNull(p3.nextCursor());
    }

    @Test
    void parseFilterAndTarget() {
        assertEquals("ALL", BookmarkFeedService.parseFilter(null));
        assertEquals("ALL", BookmarkFeedService.parseFilter(""));
        assertEquals("FORUM_TOPIC", BookmarkFeedService.parseFilter("forum_topic"));
        assertEquals("BOOKMARK_TYPE_INVALID",
                assertThrows(ApiException.class, () -> BookmarkFeedService.parseFilter("x")).code());
        assertEquals(BookmarkTarget.EVENT, BookmarkFeedService.parseTarget("event"));
        // gonderi/forum genel uctan kaydedilmez
        assertThrows(ApiException.class, () -> BookmarkFeedService.parseTarget("post"));
    }

    @Test
    void addChecksVisibilityIdempotencyAndLimit() {
        assertEquals(404, assertThrows(ApiException.class, () -> svc.add(1L, BookmarkTarget.EVENT, 1L)).status().value());
        jdbc.update("INSERT INTO user_event VALUES (1,'T',NULL,NULL,'ACTIVE')");

        when(repo.existsByUserIdAndTargetTypeAndTargetId(1L, BookmarkTarget.EVENT, 1L)).thenReturn(true);
        svc.add(1L, BookmarkTarget.EVENT, 1L);
        verify(repo, never()).insertIfAbsent(anyLong(), anyString(), anyLong());

        when(repo.existsByUserIdAndTargetTypeAndTargetId(1L, BookmarkTarget.EVENT, 1L)).thenReturn(false);
        when(repo.countByUserId(1L)).thenReturn((long) BookmarkService.MAX_PER_USER);
        assertEquals("BOOKMARK_LIMIT",
                assertThrows(ApiException.class, () -> svc.add(1L, BookmarkTarget.EVENT, 1L)).code());

        when(repo.countByUserId(1L)).thenReturn(3L);
        svc.add(1L, BookmarkTarget.EVENT, 1L);
        verify(repo).insertIfAbsent(1L, "EVENT", 1L);

        svc.add(1L, BookmarkTarget.NEWS, 9L);
        verify(newsSvc).addNews(1L, 9L);
    }

    @Test
    void microsCursorRoundTrips() {
        Instant i = Instant.parse("2026-03-04T05:06:07.123456Z");
        assertEquals(i, BookmarkFeedService.fromMicros(BookmarkFeedService.toMicros(i)));
        assertTrue(BookmarkFeedService.toMicros(i) > 0);
    }
}
