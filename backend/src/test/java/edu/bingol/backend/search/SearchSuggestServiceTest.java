package edu.bingol.backend.search;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.cache.CacheService;
import edu.bingol.backend.profile.ProfileService;
import edu.bingol.backend.profile.dto.ProfileDtos.PublicProfile;
import edu.bingol.backend.profile.dto.ProfileDtos.UserSearchResult;
import edu.bingol.backend.search.SearchSuggestService.SuggestResult;
import java.util.List;
import javax.sql.DataSource;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.datasource.embedded.EmbeddedDatabase;
import org.springframework.jdbc.datasource.embedded.EmbeddedDatabaseBuilder;
import org.springframework.jdbc.datasource.embedded.EmbeddedDatabaseType;

/** B8: onek onerisi (gizli haber/kulup/kisi), sunucuda arama gecmisi yok, kisi suzgeci ProfileService'e ait. */
class SearchSuggestServiceTest {

    private static EmbeddedDatabase db;
    private static NamedParameterJdbcTemplate jdbc;

    @BeforeAll
    static void setUp() {
        db = new EmbeddedDatabaseBuilder().setType(EmbeddedDatabaseType.H2).setName("suggest").build();
        JdbcTemplate j = new JdbcTemplate((DataSource) db);
        j.execute("CREATE TABLE news_item (id BIGINT PRIMARY KEY, type VARCHAR(12), title VARCHAR(300), hidden BOOLEAN, published_date DATE)");
        j.execute("CREATE TABLE community (id BIGINT PRIMARY KEY, name VARCHAR(80), status VARCHAR(16), visibility VARCHAR(16))");
        j.update("INSERT INTO news_item VALUES (1,'HABER','Kampus yemek listesi',FALSE,DATE '2026-11-01')");
        j.update("INSERT INTO news_item VALUES (2,'DUYURU','Kampus kayit duyurusu',FALSE,DATE '2026-11-02')");
        j.update("INSERT INTO news_item VALUES (3,'HABER','Kampus gizli haber',TRUE,DATE '2026-11-03')");
        j.update("INSERT INTO news_item VALUES (4,'ETKINLIK','Kampus 100% senligi',FALSE,DATE '2026-11-04')");
        j.update("INSERT INTO community VALUES (1,'Kampus Muzik','ACTIVE','PUBLIC')");
        j.update("INSERT INTO community VALUES (2,'Kampus Gizli','ACTIVE','PRIVATE')");
        j.update("INSERT INTO community VALUES (3,'Kampus Bekleyen','PENDING_REVIEW','PUBLIC')");
        jdbc = new NamedParameterJdbcTemplate(j);
    }

    @AfterAll
    static void tearDown() {
        db.shutdown();
    }

    private final ProfileService profiles = mock(ProfileService.class);
    private final SearchSuggestService svc = new SearchSuggestService(jdbc, CacheService.passthrough(), profiles);

    @Test
    void suggestsPrefixOfVisibleNewsAndPublicActiveClubsOnly() {
        SuggestResult r = svc.suggest(7L, "  kam ");

        assertEquals("kam", r.q());
        List<String> texts = r.suggestions().stream().map(SearchSuggestService.Suggestion::text).toList();
        assertTrue(texts.contains("Kampus yemek listesi"));
        assertTrue(texts.contains("Kampus Muzik"));
        assertFalse(texts.contains("Kampus gizli haber"), "gizli haber");
        assertFalse(texts.contains("Kampus Gizli"), "ozel kulup");
        assertFalse(texts.contains("Kampus Bekleyen"), "onaysiz kulup");
        assertEquals("ANNOUNCEMENT", r.suggestions().stream().filter(s -> s.id() == 2L && !s.type().equals("COMMUNITY"))
                .findFirst().orElseThrow().type());
        assertEquals("EVENT_OFFICIAL", r.suggestions().stream().filter(s -> s.id() == 4L).findFirst().orElseThrow().type());
        assertTrue(r.suggestions().size() <= SearchSuggestService.MAX_TOTAL);
    }

    @Test
    void likeWildcardsInInputAreEscaped() {
        assertTrue(svc.suggest(7L, "%%").suggestions().isEmpty());
        assertTrue(svc.suggest(7L, "__").suggestions().isEmpty());
        assertEquals("100\\% s%", SearchSuggestService.prefixPattern("100% s"));
    }

    @Test
    void tooShortQueryIsRejected() {
        assertThrows(ApiException.class, () -> svc.suggest(7L, "a"));
    }

    @Test
    void usersComeFromProfileServiceOnlyFromThreeCharsAndNeverCarryEmail() {
        PublicProfile p = new PublicProfile(3L, "Kamil Veli", null, null, null, null, null, "gizli@example.com", null,
                null, null, null, null, null, null, null, null, null, null, null);
        when(profiles.search(eq(7L), eq("kam"), eq(SearchSuggestService.USER_MAX), eq(null)))
                .thenReturn(new UserSearchResult(List.of(p), null));

        SuggestResult three = svc.suggest(7L, "kam");
        assertTrue(three.suggestions().stream().anyMatch(s -> s.type().equals("USER") && s.id() == 3L));
        assertFalse(three.toString().contains("gizli@example.com"));

        svc.suggest(7L, "ka");
        verify(profiles, never()).search(anyLong(), eq("ka"), anyInt(), org.mockito.ArgumentMatchers.any());
    }

    @Test
    void failingUserSourceDoesNotBreakOtherSuggestions() {
        when(profiles.search(anyLong(), anyString(), anyInt(), org.mockito.ArgumentMatchers.any()))
                .thenThrow(new IllegalStateException("db"));
        SuggestResult r = svc.suggest(7L, "kamp");
        assertFalse(r.suggestions().isEmpty());
    }
}
