package edu.bingol.backend.unitnews;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

import java.time.LocalDate;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

/** Cekim: yalniz yeni adresler kaydedilir, bolum akisi slug ile, bos genel akis = bakim (eski veri kalir). */
@SpringBootTest
class UnitNewsSyncServiceTest {

    private static final String BASE = "https://mmf.bingol.edu.tr";

    @MockitoBean UnitSiteScraper scraper;
    @Autowired UnitNewsSyncService sync;
    @Autowired UnitSourceRepository sources;
    @Autowired UnitDepartmentRepository depts;
    @Autowired UnitAnnouncementRepository anns;

    @BeforeEach
    void seed() throws Exception {
        anns.deleteAll();
        depts.deleteAll();
        sources.deleteAll();
        sync.setPauseMs(0);
        UnitSource s = new UnitSource();
        s.setCode("mmf");
        s.setName("Mühendislik ve Mimarlık Fakültesi");
        s.setKind(UnitSource.Kind.FACULTY);
        s.setBaseUrl(BASE);
        s.setFacultyKeys("muhendislik fakultesi");
        sources.saveAndFlush(s);
        LocalDate today = LocalDate.now();
        when(scraper.fetchDepartments(BASE)).thenReturn(List.of(new UnitSiteScraper.Dept("bilgisayar-muhendisligi", "Bilgisayar Mühendisliği")));
        when(scraper.fetchFeedPath(eq(BASE), eq("bilgisayar-muhendisligi"))).thenReturn("/bolumler_/bilgisayar-muhendisligi/duyurular/");
        when(scraper.fetchList(BASE, "/duyurular/")).thenReturn(List.of(
                new UnitSiteScraper.ListEntry(BASE + "/duyurular/a/", "Genel A", today),
                new UnitSiteScraper.ListEntry(BASE + "/duyurular/eski/", "Çok eski", today.minusDays(400))));
        when(scraper.fetchList(BASE, "/bolumler_/bilgisayar-muhendisligi/duyurular/")).thenReturn(List.of(
                new UnitSiteScraper.ListEntry(BASE + "/bolumler_/bilgisayar-muhendisligi/duyurular/b/", "Bölüm B", today.minusDays(1))));
        when(scraper.fetchDetail(any())).thenReturn(new UnitSiteScraper.Detail("Gövde metni",
                List.of(new UnitSiteScraper.Attachment("program.pdf", BASE + "/media/1/program.pdf", "PDF")), null));
    }

    @Test
    void savesOnlyNewRecentEntriesOnceWithDepartmentSlugAndAttachments() {
        assertEquals(2, sync.syncAll());
        assertEquals(2, anns.count(), "400 gunluk kayit alinmaz");
        UnitAnnouncement dept = anns.findAll().stream().filter(a -> a.getTitle().equals("Bölüm B")).findFirst().orElseThrow();
        assertEquals("bilgisayar-muhendisligi", dept.getDeptSlug());
        assertTrue(dept.getAttachments().contains("program.pdf"));
        assertEquals("Gövde metni", dept.getBody());
        UnitDepartment d = depts.findBySourceCodeOrderByNameAsc("mmf").get(0);
        assertEquals("bilgisayar muhendisligi", d.getNameKey());
        assertEquals("/bolumler_/bilgisayar-muhendisligi/duyurular/", d.getFeedPath());

        assertEquals(0, sync.syncAll(), "ikinci calistirmada yeni kayit yok");
        assertEquals(2, anns.count());
        UnitSource s = sources.findById("mmf").orElseThrow();
        assertFalse(s.isMaintenance());
        assertEquals("0 yeni duyuru", s.getLastMessage());
    }

    @Test
    void emptyGeneralFeedMarksMaintenanceAndKeepsOldData() throws Exception {
        sync.syncAll();
        when(scraper.fetchList(BASE, "/duyurular/")).thenReturn(List.of());
        assertEquals(0, sync.syncAll());
        UnitSource s = sources.findById("mmf").orElseThrow();
        assertTrue(s.isMaintenance());
        assertEquals(2, anns.count());
    }

    @Test
    void unreachableSourceNeverThrowsAndDisabledSourcesAreSkipped() throws Exception {
        org.mockito.Mockito.doThrow(new java.io.IOException("timeout")).when(scraper).fetchList(BASE, "/duyurular/");
        assertEquals(0, sync.syncAll());
        assertTrue(sources.findById("mmf").orElseThrow().isMaintenance());
        UnitSource s = sources.findById("mmf").orElseThrow();
        s.setEnabled(false);
        sources.saveAndFlush(s);
        org.mockito.Mockito.doReturn(List.of(new UnitSiteScraper.ListEntry(BASE + "/duyurular/z/", "Z", LocalDate.now()))).when(scraper).fetchList(BASE, "/duyurular/");
        assertEquals(0, sync.syncAll());
        assertEquals(0, anns.count());
        assertEquals(-1, sync.sync("yok"));
    }
}
