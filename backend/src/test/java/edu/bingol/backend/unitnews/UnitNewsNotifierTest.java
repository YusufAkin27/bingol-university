package edu.bingol.backend.unitnews;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertSame;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.unitnews.UnitNewsService.Target;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.domain.Pageable;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;

/** "Bolumunuzde yeni duyuru": bir duyuru hangi hedef grubuna uyar (genel akis kaynaga, bolum akisi yalniz o bolume). */
class UnitNewsNotifierTest {

    private static UnitAnnouncement ann(String source, String slug) {
        UnitAnnouncement a = new UnitAnnouncement();
        a.setSourceCode(source);
        a.setDeptSlug(slug);
        return a;
    }

    @Test
    void deptFeedMatchesOnlyThatDepartmentAndCarriesItsName() {
        Target general = new Target("muh", null, null);
        Target dept = new Target("muh", "bilgisayar", "Bilgisayar Mühendisliği");
        UnitNewsNotifier.Group g = new UnitNewsNotifier.Group(List.of(general, dept));

        assertSame(dept, g.match(ann("muh", "bilgisayar")));
        assertNull(g.match(ann("muh", "elektrik")), "baska bolumun akisi bu kullaniciya gitmez");
        assertNull(g.match(ann("fen", "bilgisayar")), "baska kaynak");
    }

    @Test
    void generalFeedMatchesAnyTargetOfThatSourceAndHasNoDeptLabel() {
        Target dept = new Target("muh", "bilgisayar", "Bilgisayar Mühendisliği");
        UnitNewsNotifier.Group g = new UnitNewsNotifier.Group(List.of(new Target("muh", null, null), dept));
        Target hit = g.match(ann("muh", null));
        assertEquals("muh", hit.sourceCode());
        assertNull(hit.unitName());
    }

    @Test
    void groupWithoutTargetsMatchesNothing() {
        assertNull(new UnitNewsNotifier.Group(List.of()).match(ann("muh", null)));
    }

    @Test
    void perUserCapIsThree() {
        assertEquals(3, UnitNewsNotifier.MAX_PER_USER);
    }

    // ---- run(): sahiplenme, alici eleme, kullanici basina ust sinir ----

    private final UnitAnnouncementRepository anns = mock(UnitAnnouncementRepository.class);
    private final UnitSourceRepository sources = mock(UnitSourceRepository.class);
    private final UnitNewsService unitNews = mock(UnitNewsService.class);
    private final NotificationService notifications = mock(NotificationService.class);
    private final JdbcTemplate jdbc = mock(JdbcTemplate.class);

    private UnitAnnouncement ann(long id, String source, String slug, String title) {
        UnitAnnouncement a = ann(source, slug);
        a.setId(id);
        a.setTitle(title);
        a.setPublishedDate(LocalDate.now());
        a.setFetchedAt(Instant.now());
        return a;
    }

    @SuppressWarnings("unchecked")
    private void users(Object[]... rows) {
        when(jdbc.query(anyString(), any(RowMapper.class), any(), any())).thenReturn(List.of(rows));
    }

    @Test
    @SuppressWarnings("unchecked")
    void sendsToMatchingDepartmentUsersOnlyAndLabelsWithDepartmentName() {
        UnitNewsNotifier n = new UnitNewsNotifier(anns, sources, unitNews, notifications, jdbc);
        UnitSource src = new UnitSource();
        src.setCode("muh");
        src.setName("Mühendislik Fakültesi");
        src.setEnabled(true);
        when(sources.findById("muh")).thenReturn(Optional.of(src));
        when(anns.pendingNotify(any(Instant.class), any(LocalDate.class), any(Pageable.class)))
                .thenReturn(List.of(ann(9L, "muh", "bilgisayar", "Bitirme tarihleri")));
        when(anns.claimNotify(eq(9L), any(Instant.class))).thenReturn(1);
        users(new Object[] {1L, "Bilgisayar Mühendisliği", "Mühendislik Fakültesi", "3"},
                new Object[] {2L, "Bilgisayar Mühendisliği", "Mühendislik Fakültesi", "3"},
                new Object[] {3L, "Hukuk", "Hukuk Fakültesi", "2"});
        when(unitNews.targetsFor("Bilgisayar Mühendisliği", "Mühendislik Fakültesi", "3")).thenReturn(
                List.of(new Target("muh", null, null), new Target("muh", "bilgisayar", "Bilgisayar Mühendisliği")));
        when(unitNews.targetsFor("Hukuk", "Hukuk Fakültesi", "2")).thenReturn(List.of()); // eslesme yok: kimseye gitmez
        when(notifications.sendTemplatedBulk(any(), any(), anyMap(), anyString(), anyString())).thenReturn(2);

        assertEquals(2, n.run());

        ArgumentCaptor<Map<String, String>> data = ArgumentCaptor.forClass(Map.class);
        verify(notifications).sendTemplatedBulk(eq(List.of(1L, 2L)), eq(UnitNewsNotifier.TEMPLATE), data.capture(),
                eq("unit:9"), eq("Bitirme tarihleri"));
        assertEquals("Bilgisayar Mühendisliği", data.getValue().get("label"));
        assertEquals("9", data.getValue().get("unitNewsId"));
        assertEquals("UNIT_NEWS", data.getValue().get("target"));
    }

    @Test
    void alreadyClaimedByAnotherInstanceIsNotSentTwice() {
        UnitNewsNotifier n = new UnitNewsNotifier(anns, sources, unitNews, notifications, jdbc);
        when(anns.pendingNotify(any(Instant.class), any(LocalDate.class), any(Pageable.class)))
                .thenReturn(List.of(ann(9L, "muh", null, "x")));
        when(anns.claimNotify(eq(9L), any(Instant.class))).thenReturn(0); // baska ornek aldi
        users(new Object[] {1L, "Bilgisayar Mühendisliği", "Mühendislik Fakültesi", "3"});
        when(unitNews.targetsFor(anyString(), anyString(), anyString())).thenReturn(List.of(new Target("muh", null, null)));

        assertEquals(0, n.run());
        verify(notifications, never()).sendTemplatedBulk(any(), any(), anyMap(), anyString(), anyString());
    }

    @Test
    void aUserGetsAtMostThreeUnitNotificationsPerRun() {
        UnitNewsNotifier n = new UnitNewsNotifier(anns, sources, unitNews, notifications, jdbc);
        UnitSource src = new UnitSource();
        src.setCode("muh");
        src.setName("Mühendislik Fakültesi");
        src.setEnabled(true);
        when(sources.findById("muh")).thenReturn(Optional.of(src));
        List<UnitAnnouncement> five = new ArrayList<>();
        for (long i = 1; i <= 5; i++) {
            five.add(ann(i, "muh", null, "Duyuru " + i));
            when(anns.claimNotify(eq(i), any(Instant.class))).thenReturn(1);
        }
        when(anns.pendingNotify(any(Instant.class), any(LocalDate.class), any(Pageable.class))).thenReturn(five);
        users(new Object[] {1L, "Bilgisayar Mühendisliği", "Mühendislik Fakültesi", "3"});
        when(unitNews.targetsFor(anyString(), anyString(), anyString())).thenReturn(List.of(new Target("muh", null, null)));

        n.run();

        verify(notifications, org.mockito.Mockito.times(3)).sendTemplatedBulk(eq(List.of(1L)), eq(UnitNewsNotifier.TEMPLATE),
                anyMap(), anyString(), anyString());
    }
}
