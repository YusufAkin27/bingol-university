package edu.bingol.backend.unitnews;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
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
        sync.setSleeper(ms -> { });
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

    // ------------------------------------------------------------------ guvenlik duzeltmeleri (HARDEN)

    @Autowired org.springframework.jdbc.core.JdbcTemplate jdbc;

    @Test
    void aTransientDetailFailureDoesNotSaveAHollowRecordButIsRetriedNextRun() throws Exception {
        org.mockito.Mockito.doThrow(new java.io.IOException("timeout")).when(scraper).fetchDetail(BASE + "/duyurular/a/");

        assertEquals(1, sync.syncAll(), "yalniz detayi okunan bolum kaydi eklendi");
        assertFalse(anns.findAll().stream().anyMatch(a -> a.getTitle().equals("Genel A")), "gecici hata: govdesiz kayit yok");

        // sonraki gece detay okunabilir: kayit govdesiyle eklenir
        org.mockito.Mockito.doReturn(new UnitSiteScraper.Detail("Gövde metni", List.of(), null)).when(scraper).fetchDetail(BASE + "/duyurular/a/");
        assertEquals(1, sync.syncAll());
        UnitAnnouncement a = anns.findAll().stream().filter(x -> x.getTitle().equals("Genel A")).findFirst().orElseThrow();
        assertEquals("Gövde metni", a.getBody());
    }

    @Test
    void aPermanentlyBrokenDetailIsSavedAsTitleAndLinkAfterThreeFailedRuns() throws Exception {
        org.mockito.Mockito.doThrow(new java.io.IOException("404")).when(scraper).fetchDetail(BASE + "/duyurular/a/");

        sync.syncAll();
        sync.syncAll();
        assertFalse(anns.findAll().stream().anyMatch(a -> a.getTitle().equals("Genel A")));
        sync.syncAll(); // 3. basarisiz deneme

        UnitAnnouncement a = anns.findAll().stream().filter(x -> x.getTitle().equals("Genel A")).findFirst().orElseThrow();
        assertNull(a.getBody());
        assertEquals(BASE + "/duyurular/a/", a.getUrl());
    }

    @Test
    void syncStateIsWrittenWithAnUpdateSoAnAdminChangeDuringTheRunSurvives() throws Exception {
        // senkron dakikalarca surerken yonetici kaynagi kapatir ve fakulte listesini degistirir (PUT /sources/mmf)
        when(scraper.fetchList(BASE, "/duyurular/")).thenAnswer(inv -> {
            jdbc.update("UPDATE unit_source SET enabled = FALSE, faculty_keys = 'yonetici degisikligi' WHERE code = 'mmf'");
            return List.of(new UnitSiteScraper.ListEntry(BASE + "/duyurular/a/", "Genel A", LocalDate.now()));
        });

        sync.syncAll();

        UnitSource s = sources.findById("mmf").orElseThrow();
        assertFalse(s.isEnabled(), "senkron yoneticinin kapatmasini yeniden acmadi");
        assertEquals("yonetici degisikligi", s.getFacultyKeys());
        assertTrue(s.getLastMessage().endsWith("yeni duyuru"), s.getLastMessage());
        assertTrue(s.getLastAttemptAt() != null && s.getLastSuccessAt() != null && s.getDepartmentsCheckedAt() != null);
        assertFalse(s.isMaintenance());
    }

    @Test
    void aSourceDisabledBeforeItsTurnIsSkipped() throws Exception {
        UnitSource second = new UnitSource();
        second.setCode("zzz");
        second.setName("Ikinci");
        second.setKind(UnitSource.Kind.FACULTY);
        second.setBaseUrl("https://zzz.bingol.edu.tr");
        sources.saveAndFlush(second);
        when(scraper.fetchList(BASE, "/duyurular/")).thenAnswer(inv -> {
            jdbc.update("UPDATE unit_source SET enabled = FALSE WHERE code = 'zzz'");
            return List.of(new UnitSiteScraper.ListEntry(BASE + "/duyurular/a/", "Genel A", LocalDate.now()));
        });

        sync.syncAll();

        org.mockito.Mockito.verify(scraper, org.mockito.Mockito.never()).fetchDepartments("https://zzz.bingol.edu.tr");
        assertNull(sources.findById("zzz").orElseThrow().getLastAttemptAt());
    }

    @Test
    void requestsToTheSourceSiteAreNeverBackToBack() throws Exception {
        java.util.List<String> events = new java.util.ArrayList<>();
        sync.setPauseMs(600);
        sync.setSleeper(ms -> events.add("pause"));
        when(scraper.fetchDepartments(BASE)).thenAnswer(inv -> {
            events.add("req");
            return List.of(new UnitSiteScraper.Dept("bilgisayar-muhendisligi", "Bilgisayar Mühendisliği"));
        });
        when(scraper.fetchFeedPath(eq(BASE), eq("bilgisayar-muhendisligi"))).thenAnswer(inv -> {
            events.add("req");
            return "/bolumler_/bilgisayar-muhendisligi/duyurular/";
        });
        when(scraper.fetchList(eq(BASE), any())).thenAnswer(inv -> {
            events.add("req");
            String feed = inv.getArgument(1);
            return List.of(new UnitSiteScraper.ListEntry(BASE + feed + "n/", "Yeni " + feed, LocalDate.now()));
        });
        when(scraper.fetchDetail(any())).thenAnswer(inv -> {
            events.add("req");
            return new UnitSiteScraper.Detail("g", List.of(), null);
        });

        sync.syncAll();

        assertTrue(events.stream().filter("req"::equals).count() >= 5, events.toString());
        for (int i = 1; i < events.size(); i++) {
            assertFalse(events.get(i).equals("req") && events.get(i - 1).equals("req"),
                    "iki istek arasinda bekleme yok: " + events);
        }
        sync.setPauseMs(0);
    }

    @Test
    void departmentsRemovedFromTheSiteAreDeletedButAShortListNeverWipesTheTable() throws Exception {
        sync.syncAll();
        assertEquals(1, depts.countBySourceCode("mmf"));
        // site yenilenince iki bolum: biri eskisi, biri yeni; ilk yenileme zamani gelsin
        jdbc.update("UPDATE unit_source SET departments_checked_at = NULL WHERE code = 'mmf'");
        when(scraper.fetchDepartments(BASE)).thenReturn(List.of(
                new UnitSiteScraper.Dept("bilgisayar-muhendisligi", "Bilgisayar Mühendisliği"),
                new UnitSiteScraper.Dept("elektrik", "Elektrik Mühendisliği")));
        sync.syncAll();
        assertEquals(2, depts.countBySourceCode("mmf"));

        // bolum kalkti: yalniz biri kaldi (2 -> 1: yarisindan fazla) => kalkan silinir
        jdbc.update("UPDATE unit_source SET departments_checked_at = NULL WHERE code = 'mmf'");
        when(scraper.fetchDepartments(BASE)).thenReturn(List.of(new UnitSiteScraper.Dept("elektrik", "Elektrik Mühendisliği")));
        sync.syncAll();
        assertEquals(List.of("elektrik"), depts.findBySourceCodeOrderByNameAsc("mmf").stream().map(UnitDepartment::getSlug).toList());

        // ayristirma neredeyse bos dondu (1 -> 0 gecerli): hicbir sey silinmez
        jdbc.update("UPDATE unit_source SET departments_checked_at = NULL WHERE code = 'mmf'");
        when(scraper.fetchDepartments(BASE)).thenReturn(List.of(new UnitSiteScraper.Dept("x".repeat(200), "Cok Uzun Slug")));
        sync.syncAll();
        assertEquals(1, depts.countBySourceCode("mmf"), "gecerli bolum yokken tablo bosaltilmaz");
    }

    @Test
    void anOverlongSlugOrFeedPathNeverPutsTheSourceIntoMaintenance() throws Exception {
        when(scraper.fetchDepartments(BASE)).thenReturn(List.of(
                new UnitSiteScraper.Dept("x".repeat(200), "Cok Uzun Slug Bolumu"),
                new UnitSiteScraper.Dept("tarih", "Tarih Bölümü")));
        when(scraper.fetchFeedPath(eq(BASE), eq("tarih"))).thenReturn("/bolumler_/" + "y".repeat(300) + "/duyurular/");

        sync.syncAll();

        assertFalse(sources.findById("mmf").orElseThrow().isMaintenance());
        List<UnitDepartment> rows = depts.findBySourceCodeOrderByNameAsc("mmf");
        assertEquals(List.of("tarih"), rows.stream().map(UnitDepartment::getSlug).toList());
        assertNull(rows.get(0).getFeedPath(), "uzun akis yolu sutuna sigmaz: null");
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
