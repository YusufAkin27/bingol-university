package edu.bingol.backend.forum.share;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.forum.ForumTestDb;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.post.follow.PrivateAccountGate;
import edu.bingol.backend.share.ShareRef;
import edu.bingol.backend.share.ShareService;
import edu.bingol.backend.share.ShareType;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.context.support.ResourceBundleMessageSource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;

/** Paylasim karti / OG: gorunurluk, anonimlik, engel/sessize alma, gizli hesap, silinmis, dil, gorsel. */
class ForumShareResolverTest {

    private JdbcTemplate jdbc;
    private BlockService blocks;
    private PrivateAccountGate gate;
    private JdbcForumShareResolver resolver;

    @BeforeEach
    void setUp() {
        jdbc = ForumTestDb.create();
        blocks = mock(BlockService.class);
        gate = mock(PrivateAccountGate.class);
        when(blocks.hiddenFrom(anyLong())).thenReturn(Set.of());
        when(gate.privateAmong(anyCollection())).thenReturn(Set.of());
        ResourceBundleMessageSource ms = new ResourceBundleMessageSource();
        ms.setBasename("i18n/forumn");
        ms.setDefaultEncoding("UTF-8");
        ms.setFallbackToSystemLocale(false);
        resolver = new JdbcForumShareResolver(new NamedParameterJdbcTemplate(jdbc), blocks, gate,
                new I18n(ms, mock(UserRepository.class)));
        jdbc.update("INSERT INTO forum_category (id, name_tr, name_en, name_ar) VALUES (1, 'Yemekhane', 'Cafeteria', 'المطعم')");
        ForumTestDb.user(jdbc, 1, "Ayse Yazar", "ACTIVE");
        ForumTestDb.user(jdbc, 2, "Mehmet Okur", "ACTIVE");
        ForumTestDb.user(jdbc, 3, "Pasif Kisi", "SUSPENDED");
        ForumTestDb.topic(jdbc, 10, 1, false, "Bugun ne var", "Ogle yemegi hakkinda uzun bir aciklama", "ACTIVE", false,
                "2026-11-01 10:00:00");
        ForumTestDb.topic(jdbc, 11, 1, true, "Anonim itiraf", "Gizli govde", "ACTIVE", false, "2026-11-01 11:00:00");
        ForumTestDb.topic(jdbc, 12, 1, false, "Silinmis", "x", "ACTIVE", true, "2026-11-01 12:00:00");
        ForumTestDb.topic(jdbc, 13, 1, false, "Kaldirilmis", "x", "REMOVED", false, "2026-11-01 13:00:00");
        ForumTestDb.topic(jdbc, 14, 3, false, "Pasif yazar", "x", "ACTIVE", false, "2026-11-01 14:00:00");
        LocaleContextHolder.setLocale(java.util.Locale.forLanguageTag("tr"));
    }

    @AfterEach
    void tearDown() {
        LocaleContextHolder.resetLocaleContext();
    }

    private static ShareRef topic(long id) {
        return new ShareRef(ShareType.FORUM_TOPIC, id);
    }

    private static ShareRef comment(long id) {
        return new ShareRef(ShareType.FORUM_COMMENT, id);
    }

    @Test
    void visibleTopicCardCarriesTitleAuthorCategoryAndBody() {
        Map<ShareRef, ShareService.Resolved> out = resolver.resolve(2L, List.of(topic(10)));
        ShareService.Resolved r = out.get(topic(10));
        assertNotNull(r);
        assertEquals("Bugun ne var", r.title());
        assertEquals("Ayse Yazar · Yemekhane", r.subtitle());
        assertEquals("Ogle yemegi hakkinda uzun bir aciklama", r.description());
        assertNull(r.imageUrl());
        assertNull(r.mediaId());
    }

    @Test
    void deletedRemovedInactiveAndUnknownAreNotAvailable() {
        Map<ShareRef, ShareService.Resolved> out = resolver.resolve(2L,
                List.of(topic(12), topic(13), topic(14), topic(999), comment(999)));
        assertTrue(out.isEmpty());
        assertTrue(resolver.resolve(null, List.of(topic(12), topic(13), topic(14))).isEmpty());
    }

    @Test
    void anonymousTopicNeverShowsTheAuthorsNameOrIdInTheCard() {
        for (Long viewer : new Long[] {2L, null}) {
            ShareService.Resolved r = resolver.resolve(viewer, List.of(topic(11))).get(topic(11));
            assertNotNull(r);
            assertEquals("Anonim · Yemekhane", r.subtitle());
            assertFalse((r.title() + r.subtitle() + r.description()).contains("Ayse"));
        }
        LocaleContextHolder.setLocale(java.util.Locale.ENGLISH);
        assertEquals("Anonymous · Cafeteria", resolver.resolve(2L, List.of(topic(11))).get(topic(11)).subtitle());
    }

    @Test
    void blockedMutedAndPrivateAuthorsAreHiddenFromTheViewer() {
        when(blocks.hiddenFrom(2L)).thenReturn(Set.of(1L));
        assertTrue(resolver.resolve(2L, List.of(topic(10))).isEmpty());
        assertEquals(1, resolver.resolve(1L, List.of(topic(10))).size()); // kendi icerigi
        when(blocks.hiddenFrom(2L)).thenReturn(Set.of());
        jdbc.update("INSERT INTO forum_user_mute (user_id, muted_user_id) VALUES (2, 1)");
        assertTrue(resolver.resolve(2L, List.of(topic(10))).isEmpty());
        jdbc.update("DELETE FROM forum_user_mute");
        // gizli hesap: herkese acik sayfada ADIYLA gorunen icerik onizlenmez, anonim olan onizlenir
        when(gate.privateAmong(anyCollection())).thenReturn(Set.of(1L));
        assertTrue(resolver.resolve(null, List.of(topic(10))).isEmpty());
        assertEquals(1, resolver.resolve(null, List.of(topic(11))).size());
        assertEquals(1, resolver.resolve(2L, List.of(topic(10))).size()); // forum kampus ici
    }

    @Test
    void commentCardUsesCommentTextAuthorAndTopicTitleAndHidesAnonymousIdentity() {
        ForumTestDb.comment(jdbc, 50, 10, 2, false, "Bence cok guzel bir menu", "ACTIVE", false, "2026-11-02 10:00:00");
        ForumTestDb.comment(jdbc, 51, 10, 2, true, "Anonim yorum", "ACTIVE", false, "2026-11-02 11:00:00");
        // anonim konunun yazari (1) kendi konusuna ADIYLA yorum yazdi: adi gosterilemez
        ForumTestDb.comment(jdbc, 52, 11, 1, false, "Ben yazdim", "ACTIVE", false, "2026-11-02 12:00:00");
        ForumTestDb.comment(jdbc, 53, 10, 2, false, "silinmis", "ACTIVE", true, "2026-11-02 13:00:00");
        ForumTestDb.comment(jdbc, 54, 12, 2, false, "silinmis konuda", "ACTIVE", false, "2026-11-02 14:00:00");
        Map<ShareRef, ShareService.Resolved> out = resolver.resolve(1L,
                List.of(comment(50), comment(51), comment(52), comment(53), comment(54)));
        assertEquals(3, out.size());
        ShareService.Resolved named = out.get(comment(50));
        assertEquals("Bence cok guzel bir menu", named.title());
        assertEquals("Mehmet Okur · Bugun ne var", named.subtitle());
        assertEquals("Anonim · Bugun ne var", out.get(comment(51)).subtitle());
        assertEquals("Anonim · Anonim itiraf", out.get(comment(52)).subtitle());
        for (ShareService.Resolved r : out.values()) {
            assertEquals(ShareType.FORUM_COMMENT, r.ref().type());
        }
    }

    @Test
    void firstVisibleImageBecomesThumbAndMediaId() {
        jdbc.update("INSERT INTO forum_media (id, owner_id, thumb_key, hidden_at) VALUES (7, 1, 'forum/t7.jpg', NULL)");
        jdbc.update("INSERT INTO forum_media (id, owner_id, thumb_key, hidden_at) VALUES (8, 1, 'forum/t8.jpg', TIMESTAMP '2026-01-01 00:00:00')");
        jdbc.update("INSERT INTO forum_topic_image (id, topic_id, media_id, position) VALUES (1, 10, 8, 0), (2, 10, 7, 1)");
        ShareService.Resolved r = resolver.resolve(2L, List.of(topic(10))).get(topic(10));
        assertEquals(7L, r.mediaId()); // gizlenen 8 atlanir
        assertEquals("/api/forum/media/7?thumb=true", r.imageUrl());
    }

    @Test
    void longBodyIsClippedTo140() {
        ForumTestDb.topic(jdbc, 20, 1, false, "Uzun", "x".repeat(400), "ACTIVE", false, "2026-11-01 10:00:00");
        ShareService.Resolved r = resolver.resolve(2L, List.of(topic(20))).get(topic(20));
        assertEquals(140, r.description().length());
        assertTrue(r.description().endsWith("…"));
    }
}
