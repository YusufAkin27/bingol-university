package edu.bingol.backend.search;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.RateLimitedException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.forum.search.ForumSearchItem;
import edu.bingol.backend.forum.search.ForumSearchProvider;
import edu.bingol.backend.forum.search.ForumSearchService;
import edu.bingol.backend.forum.topic.dto.Author;
import edu.bingol.backend.forum.topic.dto.CategoryRef;
import edu.bingol.backend.forum.topic.dto.ForumPage;
import edu.bingol.backend.forum.topic.dto.TopicSummary;
import edu.bingol.backend.profile.ProfileService;
import edu.bingol.backend.profile.UserSearchProvider;
import edu.bingol.backend.profile.dto.ProfileDtos.PublicProfile;
import edu.bingol.backend.profile.dto.ProfileDtos.UserSearchResult;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

/** B8: kisi ve forum konusu arama saglayicilari (gizlilik/anonimlik sizintisi yok, gorunurluk servise ait). */
class SearchProvidersTest {

    @AfterEach
    void clear() {
        SecurityContextHolder.clearContext();
    }

    private static void login(Long id) {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(id, null, List.of()));
    }

    private static PublicProfile profile(long id, String name) {
        return new PublicProfile(id, name, "Fen Fakultesi", "Bilgisayar", (short) 2, "bio", "/files/a.png",
                "gizli@example.com", 10L, 20L, true, false, null, null, null, null, null, null, null, null);
    }

    @Test
    void searchTypeKeepsExistingNamesAndAppendsNewOnes() {
        List<String> names = java.util.Arrays.stream(SearchType.values()).map(Enum::name).toList();
        assertEquals(List.of("NEWS", "ANNOUNCEMENT", "EVENT_OFFICIAL", "COMMUNITY", "EVENT", "POSTS", "REELS", "USER",
                "FORUM_TOPIC"), names);
    }

    @Test
    void userProviderUsesProfileFilterAndLeaksNoEmailOrCounts() {
        ProfileService profiles = mock(ProfileService.class);
        when(profiles.search(eq(7L), eq("ali"), eq(5), eq(0L)))
                .thenReturn(new UserSearchResult(List.of(profile(3, "Ali Veli")), null));
        login(7L);

        List<SearchHit> hits = new UserSearchProvider(profiles, mock(RateLimiter.class)).search("ali", 5);

        assertEquals(1, hits.size());
        SearchHit h = hits.get(0);
        assertEquals(SearchType.USER, h.type());
        assertEquals(3L, h.targetId());
        assertEquals("Ali Veli", h.title());
        assertEquals("Bilgisayar", h.snippet());
        assertFalse(h.toString().contains("gizli@example.com"));
        assertEquals(null, h.memberCount());
        assertEquals(null, h.likeCount());
    }

    @Test
    void userProviderIsEmptyWithoutLoginAndHonoursDailyQuota() {
        ProfileService profiles = mock(ProfileService.class);
        RateLimiter limiter = mock(RateLimiter.class);
        UserSearchProvider p = new UserSearchProvider(profiles, limiter);
        assertTrue(p.search("ali", 5).isEmpty());
        verify(profiles, never()).search(anyLong(), anyString(), anyInt(), any());

        login(7L);
        doThrow(new RateLimitedException(60)).when(limiter).check(eq("gsearch-user-day:user:7"), anyInt(), any());
        try {
            p.search("ali", 5);
        } catch (RateLimitedException expected) {
            // SearchService saglayici hatasini yutar: tur sessizce bos doner
        }
        verify(profiles, never()).search(anyLong(), anyString(), anyInt(), any());
    }

    @Test
    void forumProviderNeverExposesAuthorAndAnonymousTopicsStayAnonymous() {
        ForumSearchService forum = mock(ForumSearchService.class);
        TopicSummary anon = new TopicSummary(11L, "Yurt sorunlari", "onizleme", new CategoryRef(1L, "Genel", "genel"),
                Author.anonymous("Anonim #3"), Instant.parse("2026-11-01T10:00:00Z"), null, 4, 2, false, false, false,
                null, 0, false, false, false, false, false, "ACTIVE");
        TopicSummary named = new TopicSummary(12L, "Staj ilanlari", "x", null,
                new Author(55L, "Gercek Ad", null, "Bilgisayar", false), Instant.parse("2026-11-02T10:00:00Z"), null, 0,
                0, false, false, false, null, 0, false, false, false, false, false, "ACTIVE");
        when(forum.search(eq(7L), eq("yurt"), eq(null), eq(null), eq(null), eq(5)))
                .thenReturn(new ForumPage<>(List.of(new ForumSearchItem(anon, "TITLE", null),
                        new ForumSearchItem(named, "BODY", "parca")), null));
        login(7L);

        List<SearchHit> hits = new ForumSearchProvider(forum).search("yurt", 5);

        assertEquals(2, hits.size());
        assertEquals(SearchType.FORUM_TOPIC, hits.get(0).type());
        assertEquals(11L, hits.get(0).targetId());
        assertEquals("onizleme", hits.get(0).snippet());
        assertEquals("Genel", hits.get(0).category());
        assertEquals("parca", hits.get(1).snippet());
        for (SearchHit h : hits) {
            String s = h.toString();
            assertFalse(s.contains("Anonim #3"), s);
            assertFalse(s.contains("Gercek Ad"), s);
            assertFalse(s.contains("55"), s);
        }
    }

    @Test
    void forumProviderPagesWithOffsetCursorAndIsEmptyWithoutLogin() {
        ForumSearchService forum = mock(ForumSearchService.class);
        assertTrue(new ForumSearchProvider(forum).search("yurt", 5).isEmpty());
        login(7L);
        when(forum.search(eq(7L), eq("yurt"), eq(null), eq(null), anyString(), eq(5)))
                .thenReturn(new ForumPage<>(List.of(), null));
        assertTrue(new ForumSearchProvider(forum).search("yurt", 5, 10).isEmpty());
        verify(forum).search(eq(7L), eq("yurt"), eq(null), eq(null), anyString(), eq(5));
    }
}
