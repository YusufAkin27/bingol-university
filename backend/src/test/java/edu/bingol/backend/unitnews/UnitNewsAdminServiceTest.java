package edu.bingol.backend.unitnews;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.common.ApiException;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

/** Yonetici tarafi: fakulte listesi dogrulamasi (A10), duyuru listesi suzgecleri, gizleme ve 404. */
@SpringBootTest
class UnitNewsAdminServiceTest {

    @Autowired UnitNewsAdminService admin;
    @Autowired UnitSourceRepository sources;
    @Autowired UnitDepartmentRepository depts;
    @Autowired UnitAnnouncementRepository anns;

    @BeforeEach
    void seed() {
        anns.deleteAll();
        depts.deleteAll();
        sources.deleteAll();
        UnitSource s = new UnitSource();
        s.setCode("mmf");
        s.setName("Mühendislik ve Mimarlık Fakültesi");
        s.setKind(UnitSource.Kind.FACULTY);
        s.setBaseUrl("https://mmf.bingol.edu.tr");
        s.setFacultyKeys("muhendislik fakultesi");
        sources.saveAndFlush(s);
        ann("Sınav programı %100", 1);
        ann("Staj duyurusu", 2);
        ann("Burs_başvurusu", 3);
    }

    private long ann(String title, int daysAgo) {
        UnitAnnouncement a = new UnitAnnouncement();
        a.setSourceCode("mmf");
        a.setTitle(title);
        a.setUrl("https://mmf.bingol.edu.tr/duyurular/" + UUID.randomUUID() + "/");
        a.setPublishedDate(LocalDate.now().minusDays(daysAgo));
        a.setSummary(title);
        return anns.saveAndFlush(a).getId();
    }

    @Test
    void facultyKeysAreNormalisedDeduplicatedAndInvalidOnesAreRejectedNotSilentlyDropped() {
        assertEquals(List.of("muhendislik fakultesi", "fen-edebiyat fakultesi"),
                UnitNewsAdminService.keys(List.of("Mühendislik Fakültesi", " muhendislik fakultesi ", "", "  ", "Fen-Edebiyat Fakültesi")));

        ApiException comma = assertThrows(ApiException.class, () -> UnitNewsAdminService.keys(List.of("A Fakültesi, B Fakültesi")));
        assertEquals("UNIT_FACULTY_KEY_INVALID", comma.code());
        assertEquals(400, comma.status().value());
        assertEquals("UNIT_FACULTY_KEY_INVALID",
                assertThrows(ApiException.class, () -> UnitNewsAdminService.keys(List.of("Ziraat Fakültesi", "x,y"))).code());

        List<String> tooMany = java.util.stream.IntStream.range(0, 41).mapToObj(i -> "Fakulte " + i).toList();
        assertEquals("UNIT_FACULTY_KEYS_INVALID", assertThrows(ApiException.class, () -> UnitNewsAdminService.keys(tooMany)).code());
    }

    @Test
    void updateSavesEnabledAndKeysAndAnInvalidListChangesNothing() {
        var view = admin.update("mmf", new UnitNewsDtos.SourceUpdate(false, List.of("Mimarlık Fakültesi")));
        assertFalse(view.enabled());
        assertEquals(List.of("mimarlik fakultesi"), view.facultyKeys());

        assertThrows(ApiException.class, () -> admin.update("mmf", new UnitNewsDtos.SourceUpdate(true, List.of("a,b"))));
        UnitSource s = sources.findById("mmf").orElseThrow();
        assertFalse(s.isEnabled(), "gecersiz istek hicbir alani degistirmedi");
        assertEquals("mimarlik fakultesi", s.getFacultyKeys());

        assertEquals("UNIT_SOURCE_NOT_FOUND",
                assertThrows(ApiException.class, () -> admin.update("yok", new UnitNewsDtos.SourceUpdate(true, null))).code());
    }

    @Test
    void announcementListFiltersByTitleEscapingLikeWildcardsAndByHiddenAndPages() {
        // '%' ve '_' joker degil, duz karakterdir
        assertEquals(1, admin.announcements(null, "%100", null, 0, 10).totalElements());
        assertEquals(1, admin.announcements(null, "Burs_ba", null, 0, 10).totalElements());
        assertEquals(0, admin.announcements(null, "Burs-ba", null, 0, 10).totalElements());
        assertEquals(3, admin.announcements("mmf", null, null, 0, 10).totalElements());
        assertEquals(0, admin.announcements("yok", null, null, 0, 10).totalElements());

        UnitNewsDtos.AdminPage p = admin.announcements(null, null, null, 0, 2);
        assertEquals(3, p.totalElements());
        assertEquals(2, p.totalPages());
        assertEquals(2, p.content().size());
        assertEquals("Sınav programı %100", p.content().get(0).title(), "yeniden eskiye");
        assertEquals(1, admin.announcements(null, null, null, 1, 2).content().size());
        // boyut sinirlanir
        assertEquals(UnitNewsAdminService.MAX_PAGE_SIZE, admin.announcements(null, null, null, 0, 100000).size());
    }

    @Test
    void hidingIsPersistedFilteredAndAnUnknownIdIsNotFound() {
        long id = anns.findAll().get(0).getId();

        admin.setHidden(id, true);
        assertEquals(1, admin.announcements(null, null, true, 0, 10).totalElements());
        assertEquals(2, admin.announcements(null, null, false, 0, 10).totalElements());
        admin.setHidden(id, false);
        assertEquals(0, admin.announcements(null, null, true, 0, 10).totalElements());

        ApiException e = assertThrows(ApiException.class, () -> admin.setHidden(987654321L, true));
        assertEquals("UNIT_NEWS_NOT_FOUND", e.code());
        assertEquals(404, e.status().value());
        assertTrue(admin.sources().stream().anyMatch(v -> v.code().equals("mmf") && v.announcementCount() == 3));
    }
}
