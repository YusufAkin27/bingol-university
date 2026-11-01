package edu.bingol.backend.unitnews;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

/** Ogrenci-kaynak eslesmesi: bolum akisi + genel akis, belirsizlikte/eslesmemede BOS liste, lisansustu enstituler, gizleme. */
@SpringBootTest
class UnitNewsServiceTest {

    @Autowired UnitNewsService service;
    @Autowired UnitSourceRepository sources;
    @Autowired UnitDepartmentRepository depts;
    @Autowired UnitAnnouncementRepository anns;
    @Autowired UserRepository users;

    @BeforeEach
    void seed() {
        anns.deleteAll();
        depts.deleteAll();
        sources.deleteAll();
        source("mmf", "Mühendislik ve Mimarlık Fakültesi", UnitSource.Kind.FACULTY, false,
                "muhendislik fakultesi,mimarlik fakultesi,muhendislik ve mimarlik fakultesi");
        source("fef", "Fen Edebiyat Fakültesi", UnitSource.Kind.FACULTY, false, "fen-edebiyat fakultesi");
        source("btmyo", "Bilişim Teknolojileri MYO", UnitSource.Kind.VOCATIONAL, false, "meslek yuksekokulu");
        source("tbmyo", "Teknik Bilimler MYO", UnitSource.Kind.VOCATIONAL, false, "meslek yuksekokulu");
        source("fbe", "Fen Bilimleri Enstitüsü", UnitSource.Kind.INSTITUTE, true, "muhendislik fakultesi,fen-edebiyat fakultesi");
        dept("mmf", "bilgisayar-muhendisligi", "Bilgisayar Mühendisliği", "/bolumler_/bilgisayar-muhendisligi/duyurular/");
        dept("mmf", "mimarlik", "Mimarlık", null);
        dept("fef", "tarih-bolumu", "Tarih Bölümü", null);
        dept("btmyo", "elektronik-ve-otomasyon-bolumu", "Elektronik ve Otomasyon Bölümü", null);
        dept("btmyo", "x-bilgisayar-teknolojileri", "Bilgisayar Teknolojileri Bölümü", null);
        dept("tbmyo", "elektronik-ve-otomasyon-bolumu", "Elektronik ve Otomasyon Bölümü", null);
        ann("mmf", null, "Fakülte genel duyurusu", 5);
        ann("mmf", "bilgisayar-muhendisligi", "Bilgisayar sınav programı", 1);
        ann("mmf", "mimarlik", "Mimarlık özel (akışı yok, gelmemeli)", 2);
        ann("fef", null, "Fen-Edebiyat duyurusu", 3);
        ann("btmyo", null, "BT MYO duyurusu", 4);
        ann("fbe", null, "Enstitü duyurusu", 6);
    }

    private void source(String code, String name, UnitSource.Kind kind, boolean graduate, String keys) {
        UnitSource s = new UnitSource();
        s.setCode(code);
        s.setName(name);
        s.setKind(kind);
        s.setBaseUrl("https://" + code + ".bingol.edu.tr");
        s.setGraduate(graduate);
        s.setFacultyKeys(keys);
        sources.saveAndFlush(s);
    }

    private void dept(String code, String slug, String name, String feed) {
        UnitDepartment d = new UnitDepartment();
        d.setSourceCode(code);
        d.setSlug(slug);
        d.setName(name);
        d.setNameKey(UnitKeys.deptKey(name));
        d.setFeedPath(feed);
        depts.saveAndFlush(d);
    }

    private void ann(String code, String slug, String title, int daysAgo) {
        UnitAnnouncement a = new UnitAnnouncement();
        a.setSourceCode(code);
        a.setDeptSlug(slug);
        a.setTitle(title);
        a.setUrl("https://" + code + ".bingol.edu.tr/duyurular/" + UUID.randomUUID() + "/");
        a.setPublishedDate(LocalDate.now().minusDays(daysAgo));
        a.setSummary(title);
        a.setBody("Metin: " + title);
        a.setAttachments("[{\"name\":\"program.pdf\",\"url\":\"https://" + code
                + ".bingol.edu.tr/media/1/program.pdf\",\"type\":\"PDF\"}]");
        anns.saveAndFlush(a);
    }

    private long user(String faculty, String department, String grade) {
        User u = new User();
        u.setEmail("un" + UUID.randomUUID().toString().substring(0, 10) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName("Ogr");
        u.setEmailVerified(true);
        u.setFaculty(faculty);
        u.setDepartment(department);
        u.setGrade(grade);
        return users.saveAndFlush(u).getId();
    }

    private static List<String> titles(List<UnitNewsDtos.Item> items) {
        return items.stream().map(UnitNewsDtos.Item::title).toList();
    }

    @Test
    void departmentWithOwnFeedGetsItsFeedPlusGeneralFeedNewestFirst() {
        long id = user("Mühendislik Fakültesi", "Bilgisayar Mühendisliği", "2");
        List<UnitNewsDtos.Item> items = service.feed(id, 10);
        assertEquals(List.of("Bilgisayar sınav programı", "Fakülte genel duyurusu"), titles(items));
        assertEquals("Bilgisayar Mühendisliği", items.get(0).unitName());
        assertNull(items.get(1).unitName());
        assertEquals("Mühendislik ve Mimarlık Fakültesi", items.get(0).sourceName());
        assertEquals("PDF", items.get(0).attachments().get(0).type());
    }

    @Test
    void departmentWithoutOwnFeedGetsOnlyGeneralFeed() {
        long id = user("Mimarlık Fakültesi", "Mimarlık", "3");
        assertEquals(List.of("Fakülte genel duyurusu"), titles(service.feed(id, 10)));
    }

    @Test
    void noMatchOrNoDepartmentYieldsEmptyListNotAnError() {
        assertTrue(service.feed(user("Mühendislik Fakültesi", "Yok Böyle Bölüm", "1"), 10).isEmpty());
        assertTrue(service.feed(user("Mühendislik Fakültesi", null, "1"), 10).isEmpty());
        assertTrue(service.feed(user(null, null, null), 10).isEmpty());
    }

    @Test
    void sameDepartmentNameInTwoSchoolsIsHiddenWhenFacultyCannotSeparateThem() {
        // "Elektronik ve Otomasyon" hem btmyo hem tbmyo'da; fakulte ("Meslek Yuksekokulu") ikisine de hizmet eder -> belirsiz -> bos
        assertTrue(service.feed(user("Meslek Yüksekokulu", "Elektronik ve Otomasyon", "1"), 10).isEmpty());
        assertTrue(service.feed(user(null, "Elektronik ve Otomasyon", "1"), 10).isEmpty());
        // tek okulda gecen program: eslesir
        assertEquals(List.of("BT MYO duyurusu"),
                titles(service.feed(user("Meslek Yüksekokulu", "Bilgisayar Teknolojileri", "1"), 10)));
    }

    @Test
    void graduateStudentsAlsoGetTheirInstituteFeed() {
        assertEquals(List.of("Bilgisayar sınav programı", "Fakülte genel duyurusu", "Enstitü duyurusu"),
                titles(service.feed(user("Mühendislik Fakültesi", "Bilgisayar Mühendisliği", "MASTER"), 10)));
        assertEquals(List.of("Bilgisayar sınav programı", "Fakülte genel duyurusu"),
                titles(service.feed(user("Mühendislik Fakültesi", "Bilgisayar Mühendisliği", "3"), 10)));
    }

    @Test
    void hiddenAnnouncementsAndDisabledSourcesAreNotShown() {
        long id = user("Mühendislik Fakültesi", "Bilgisayar Mühendisliği", "2");
        UnitAnnouncement a = anns.findAll().stream().filter(x -> x.getTitle().startsWith("Fakülte genel")).findFirst().orElseThrow();
        a.setHidden(true);
        anns.saveAndFlush(a);
        assertEquals(List.of("Bilgisayar sınav programı"), titles(service.feed(id, 10)));
        UnitSource s = sources.findById("mmf").orElseThrow();
        s.setEnabled(false);
        sources.saveAndFlush(s);
        assertTrue(service.feed(id, 10).isEmpty());
    }

    @Test
    void detailReturnsBodyForOwnScopeAndNotFoundOtherwise() {
        long mine = user("Mühendislik Fakültesi", "Bilgisayar Mühendisliği", "2");
        long other = user("Fen-Edebiyat Fakültesi", "Tarih Bölümü", "2");
        UnitAnnouncement a = anns.findAll().stream().filter(x -> x.getTitle().startsWith("Bilgisayar")).findFirst().orElseThrow();
        assertEquals("Metin: Bilgisayar sınav programı", service.detail(mine, a.getId()).body());
        ApiException e = assertThrows(ApiException.class, () -> service.detail(other, a.getId()));
        assertEquals("UNIT_NEWS_NOT_FOUND", e.code());
    }

    @Test
    void limitIsClamped() {
        long id = user("Mühendislik Fakültesi", "Bilgisayar Mühendisliği", "2");
        assertEquals(1, service.feed(id, 0).size());
        assertEquals(2, service.feed(id, 500).size());
    }
}
