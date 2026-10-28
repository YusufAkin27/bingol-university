package edu.bingol.backend.admin.bulk;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import edu.bingol.backend.admin.AdminReasonFilter;
import edu.bingol.backend.auth.token.PendingRegistrationStore;
import edu.bingol.backend.auth.token.PendingRegistrationStore.Entry;
import edu.bingol.backend.auth.token.PendingRegistrationStore.EntryPage;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.common.RateLimitedException;
import edu.bingol.backend.media.MediaService;
import edu.bingol.backend.menu.MenuDay;
import edu.bingol.backend.menu.MenuRepository;
import edu.bingol.backend.menu.MenuSyncService;
import edu.bingol.backend.news.ContentType;
import edu.bingol.backend.news.NewsItem;
import edu.bingol.backend.news.NewsRepository;
import edu.bingol.backend.news.NewsSyncService;
import edu.bingol.backend.status.StatusService;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

/** P15 HTTP sozlesmesi: yetki, sebep, 200 siniri, kismi basari, CSV kacirma, maskeleme, menu gorsel temizligi, kaynak durumu. */
@SpringBootTest
class AdminBulkControllerTest {

    private static final ObjectMapper OM = new ObjectMapper();

    @Autowired WebApplicationContext ctx;
    @Autowired NewsRepository news;
    @Autowired MenuRepository menu;
    @Autowired JdbcTemplate jdbc;
    @Autowired StatusService status;
    @Autowired AdminReasonFilter reasonFilter;

    /** Testlerde Redis yok: hiz siniri, bekleyen kayit deposu sahte; gorsel temizligi dogrulanir; scraper cagrilmaz. */
    @MockitoBean RateLimiter limiter;
    @MockitoBean PendingRegistrationStore pending;
    @MockitoBean MediaService media;
    @MockitoBean NewsSyncService newsSync;
    @MockitoBean MenuSyncService menuSync;
    MockMvc mvc;

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.webAppContextSetup(ctx).apply(springSecurity()).addFilters(reasonFilter).build();
    }

    private static UsernamePasswordAuthenticationToken admin() {
        return new UsernamePasswordAuthenticationToken(990001L, null, List.of(new SimpleGrantedAuthority("ROLE_ADMIN")));
    }

    private static UsernamePasswordAuthenticationToken plainUser() {
        return new UsernamePasswordAuthenticationToken(990002L, null, List.of(new SimpleGrantedAuthority("ROLE_USER")));
    }

    private MockHttpServletResponse call(MockHttpServletRequestBuilder b) throws Exception {
        return mvc.perform(b.with(authentication(admin()))).andReturn().getResponse();
    }

    private MockHttpServletResponse postJson(String path, String body) throws Exception {
        return call(post(path).contentType("application/json").content(body));
    }

    private NewsItem news(String title, boolean hidden) {
        NewsItem n = new NewsItem();
        n.setType(ContentType.HABER);
        n.setUrl("https://www.bingol.edu.tr/p15/" + UUID.randomUUID());
        n.setTitle(title);
        n.setHidden(hidden);
        n.setFetchedAt(Instant.now());
        return news.saveAndFlush(n);
    }

    // ---- yetki ----

    @Test
    void everyEndpointRejectsAnonymousAndPlainUsers() throws Exception {
        List<String> gets = List.of("/api/admin/news/export.csv", "/api/admin/academic/export.csv?entity=EXAM",
                "/api/admin/menu/export.csv", "/api/admin/pending-registrations/export.csv", "/api/admin/sources/status");
        for (String p : gets) {
            assertEquals(401, mvc.perform(get(p)).andReturn().getResponse().getStatus(), p);
            assertEquals(403, mvc.perform(get(p).with(authentication(plainUser()))).andReturn().getResponse().getStatus(), p);
        }
        String body = "{\"action\":\"HIDE\",\"ids\":[1],\"reason\":\"deneme sebebi\"}";
        for (String p : List.of("/api/admin/news/bulk", "/api/admin/academic/bulk", "/api/admin/menu/bulk-delete",
                "/api/admin/pending-registrations/bulk-cancel", "/api/admin/sources/sync")) {
            assertEquals(401, mvc.perform(post(p).contentType("application/json").content(body)).andReturn().getResponse()
                    .getStatus(), p);
            assertEquals(403, mvc.perform(post(p).with(authentication(plainUser())).contentType("application/json")
                    .content(body)).andReturn().getResponse().getStatus(), p);
        }
    }

    // ---- haber ----

    @Test
    void newsBulkHidesUnhidesAndReportsPartialSuccess() throws Exception {
        NewsItem a = news("P15 haber A", false);
        NewsItem b = news("P15 haber B", true);
        String body = "{\"action\":\"HIDE\",\"ids\":[" + a.getId() + "," + b.getId() + ",987654321,"
                + a.getId() + "],\"reason\":\"toplu inceleme\"}";
        MockHttpServletResponse res = postJson("/api/admin/news/bulk", body);
        assertEquals(200, res.getStatus(), res.getContentAsString());
        JsonNode j = OM.readTree(res.getContentAsString());
        assertEquals(3, j.get("requested").asInt(), "tekrar atilir");
        assertEquals(1, j.get("done").asInt());
        assertEquals(2, j.get("skipped").asInt());
        assertEquals(0, j.get("failed").asInt());
        assertEquals("DONE", j.get("results").get(0).get("status").asText());
        assertEquals("ALREADY_DONE", j.get("results").get(1).get("code").asText());
        assertEquals("NOT_FOUND", j.get("results").get(2).get("code").asText());
        assertTrue(news.findById(a.getId()).orElseThrow().isHidden());

        MockHttpServletResponse un = postJson("/api/admin/news/bulk",
                "{\"action\":\"UNHIDE\",\"ids\":[" + a.getId() + "," + b.getId() + "],\"reason\":\"yanlis gizlenmis\"}");
        assertEquals(2, OM.readTree(un.getContentAsString()).get("done").asInt());
        assertFalse(news.findById(a.getId()).orElseThrow().isHidden());
        assertFalse(news.findById(b.getId()).orElseThrow().isHidden());
    }

    @Test
    void newsBulkRequiresReasonAndEnforcesLimitAndRejectsEmpty() throws Exception {
        NewsItem a = news("P15 sebep", false);
        MockHttpServletResponse noReason = postJson("/api/admin/news/bulk",
                "{\"action\":\"HIDE\",\"ids\":[" + a.getId() + "]}");
        assertEquals(400, noReason.getStatus());
        assertEquals("REASON_REQUIRED", OM.readTree(noReason.getContentAsString()).get("code").asText());
        assertEquals(400, postJson("/api/admin/news/bulk",
                "{\"action\":\"HIDE\",\"ids\":[" + a.getId() + "],\"reason\":\"abc\"}").getStatus());
        assertFalse(news.findById(a.getId()).orElseThrow().isHidden(), "sebepsiz istek hicbir sey degistirmez");

        // sebep X-Admin-Reason basligindan da gelebilir
        MockHttpServletResponse hdr = call(post("/api/admin/news/bulk").contentType("application/json")
                .header("X-Admin-Reason", "baslik sebebi").content("{\"action\":\"HIDE\",\"ids\":[" + a.getId() + "]}"));
        assertEquals(200, hdr.getStatus(), hdr.getContentAsString());

        StringBuilder many = new StringBuilder();
        for (int i = 0; i < 201; i++) {
            many.append(i == 0 ? "" : ",").append(900_000_000L + i);
        }
        MockHttpServletResponse big = postJson("/api/admin/news/bulk",
                "{\"action\":\"HIDE\",\"ids\":[" + many + "],\"reason\":\"toplu inceleme\"}");
        assertEquals(400, big.getStatus());
        assertEquals("BULK_LIMIT_EXCEEDED", OM.readTree(big.getContentAsString()).get("code").asText());

        StringBuilder ok = new StringBuilder();
        for (int i = 0; i < 200; i++) {
            ok.append(i == 0 ? "" : ",").append(900_000_000L + i);
        }
        MockHttpServletResponse exactly = postJson("/api/admin/news/bulk",
                "{\"action\":\"HIDE\",\"ids\":[" + ok + "],\"reason\":\"toplu inceleme\"}");
        assertEquals(200, exactly.getStatus());
        assertEquals(200, OM.readTree(exactly.getContentAsString()).get("skipped").asInt());

        MockHttpServletResponse empty = postJson("/api/admin/news/bulk",
                "{\"action\":\"HIDE\",\"ids\":[],\"reason\":\"toplu inceleme\"}");
        assertEquals(400, empty.getStatus());
        assertEquals("BULK_EMPTY", OM.readTree(empty.getContentAsString()).get("code").asText());
        assertEquals(400, postJson("/api/admin/news/bulk",
                "{\"action\":\"BOGUS\",\"ids\":[1],\"reason\":\"toplu inceleme\"}").getStatus());
    }

    @Test
    void newsCsvEscapesFormulasAndAppliesFilters() throws Exception {
        String evil = "=HYPERLINK(\"http://x\",\"t\")";
        NewsItem a = news(evil, false);
        NewsItem hidden = news("P15 gizli virgul, ve \"tirnak\"", true);
        MockHttpServletResponse res = call(get("/api/admin/news/export.csv").param("hidden", "false"));
        assertEquals(200, res.getStatus());
        assertTrue(res.getContentType().startsWith("text/csv"));
        assertTrue(res.getHeader("Content-Disposition").contains("news.csv"));
        String csv = res.getContentAsString(java.nio.charset.StandardCharsets.UTF_8);
        assertTrue(csv.startsWith("﻿id,type,title,url"), csv.substring(0, 30));
        assertTrue(csv.contains("\"'=HYPERLINK("), "formul onekli hucre ' ile etkisizlestirilmeli: " + csv);
        assertFalse(csv.contains("," + evil), "ham formul hucresi kalmamali");
        assertTrue(csv.contains(a.getId() + ",HABER,"));
        assertFalse(csv.contains("P15 gizli"), "gizli kayit hidden=false suzgecinde yok");

        String all = call(get("/api/admin/news/export.csv").param("hidden", "true").param("q", "P15 gizli"))
                .getContentAsString(java.nio.charset.StandardCharsets.UTF_8);
        assertTrue(all.contains("\"P15 gizli virgul, ve \"\"tirnak\"\"\""), all);
        assertTrue(all.contains(hidden.getId() + ",HABER,"));
    }

    // ---- menu ----

    @Test
    void menuBulkDeleteRemovesRowsReleasesImagesAndSkipsMissing() throws Exception {
        LocalDate d1 = LocalDate.of(2031, 3, 1);
        LocalDate d2 = LocalDate.of(2031, 3, 2);
        menu.deleteAll(menu.findByMenuDateBetweenOrderByMenuDate(d1, LocalDate.of(2031, 3, 5)));
        MenuDay a = new MenuDay();
        a.setMenuDate(d1);
        a.setItems("Corba\nPilav");
        a.setImageUrl("/files/covers/p15-a.jpg");
        MenuDay b = new MenuDay();
        b.setMenuDate(d2);
        b.setItems("Mercimek");
        menu.saveAllAndFlush(List.of(a, b));

        MockHttpServletResponse res = postJson("/api/admin/menu/bulk-delete",
                "{\"dates\":[\"2031-03-01\",\"2031-03-02\",\"2031-03-04\",\"2031-03-01\"],\"reason\":\"yanlis yuklenmis\"}");
        assertEquals(200, res.getStatus(), res.getContentAsString());
        JsonNode j = OM.readTree(res.getContentAsString());
        assertEquals(3, j.get("requested").asInt());
        assertEquals(2, j.get("done").asInt());
        assertEquals(1, j.get("skipped").asInt());
        assertTrue(menu.findByMenuDate(d1).isEmpty());
        assertTrue(menu.findByMenuDate(d2).isEmpty());
        verify(media).release("/files/covers/p15-a.jpg");
        verify(media, org.mockito.Mockito.times(1)).release(anyString());
    }

    @Test
    void menuBulkDeleteValidatesDatesLimitAndReason() throws Exception {
        assertEquals(400, postJson("/api/admin/menu/bulk-delete", "{\"dates\":[\"31.03.2031\"],\"reason\":\"toplu inceleme\"}")
                .getStatus());
        assertEquals(400, postJson("/api/admin/menu/bulk-delete", "{\"dates\":[\"2031-03-01\"]}").getStatus());
        StringBuilder many = new StringBuilder();
        for (int i = 0; i < 63; i++) {
            many.append(i == 0 ? "" : ",").append("\"").append(LocalDate.of(2032, 1, 1).plusDays(i)).append("\"");
        }
        MockHttpServletResponse big = postJson("/api/admin/menu/bulk-delete",
                "{\"dates\":[" + many + "],\"reason\":\"toplu inceleme\"}");
        assertEquals(400, big.getStatus());
        assertEquals("BULK_LIMIT_EXCEEDED", OM.readTree(big.getContentAsString()).get("code").asText());
        verify(media, never()).release(any());
    }

    @Test
    void menuCsvListsDaysWithinRange() throws Exception {
        LocalDate d = LocalDate.of(2033, 5, 5);
        menu.deleteAll(menu.findByMenuDateBetweenOrderByMenuDate(d, d));
        MenuDay a = new MenuDay();
        a.setMenuDate(d);
        a.setItems("Corba\n=1+1");
        menu.saveAndFlush(a);
        MockHttpServletResponse res = call(get("/api/admin/menu/export.csv").param("from", "2033-05-01").param("to", "2033-05-31"));
        assertEquals(200, res.getStatus());
        String csv = res.getContentAsString(java.nio.charset.StandardCharsets.UTF_8);
        assertTrue(csv.startsWith("﻿date,items,imageUrl"));
        assertTrue(csv.contains("2033-05-05,Corba | =1+1,"), csv);
        assertEquals(400, call(get("/api/admin/menu/export.csv").param("from", "bozuk")).getStatus());
    }

    // ---- bekleyen kayit ----

    @Test
    void pendingBulkCancelNormalizesAndMasksIdentifiers() throws Exception {
        when(pending.remove("226051015@bingol.edu.tr")).thenReturn(true);
        when(pending.remove("yok@bingol.edu.tr")).thenReturn(false);
        MockHttpServletResponse res = postJson("/api/admin/pending-registrations/bulk-cancel",
                "{\"emails\":[\"226051015\",\"226051015@bingol.edu.tr\",\"YOK@bingol.edu.tr\"],\"reason\":\"sahte kayitlar\"}");
        assertEquals(200, res.getStatus(), res.getContentAsString());
        String text = res.getContentAsString();
        JsonNode j = OM.readTree(text);
        assertEquals(2, j.get("requested").asInt(), "okul numarasi ile e-posta ayni kayit");
        assertEquals(1, j.get("done").asInt());
        assertEquals(1, j.get("skipped").asInt());
        assertEquals("226***@bingol.edu.tr", j.get("results").get(0).get("id").asText());
        assertFalse(text.contains("226051015"), "tam kimlik yanitta olmamali");
        verify(pending).remove("226051015@bingol.edu.tr");

        assertEquals(400, postJson("/api/admin/pending-registrations/bulk-cancel",
                "{\"emails\":[\"abc\"],\"reason\":\"sahte kayitlar\"}").getStatus());
        assertEquals(400, postJson("/api/admin/pending-registrations/bulk-cancel",
                "{\"emails\":[\"a@bingol.edu.tr\"]}").getStatus());
    }

    @Test
    void pendingCsvIsMasked() throws Exception {
        when(pending.list(any(), anyInt(), any())).thenReturn(new EntryPage(List.of(
                new Entry("226051015@bingol.edu.tr", "Ali Veli", "Muhendislik", "Bilgisayar", "2", 1_700_000_000L, 3600, 1)),
                null));
        MockHttpServletResponse res = call(get("/api/admin/pending-registrations/export.csv"));
        assertEquals(200, res.getStatus());
        String csv = res.getContentAsString(java.nio.charset.StandardCharsets.UTF_8);
        assertTrue(csv.contains("226***@bingol.edu.tr,A*** V***,Muhendislik,Bilgisayar,2,"), csv);
        assertFalse(csv.contains("226051015"));
        assertFalse(csv.contains("Ali Veli"));
    }

    // ---- akademik ----

    private long insertCalendar(String title, boolean published) {
        jdbc.update("INSERT INTO academic_event (kind, title, starts_at, all_day, published) VALUES ('HOLIDAY', ?, "
                + "CURRENT_TIMESTAMP, TRUE, ?)", title, published);
        return jdbc.queryForObject("SELECT MAX(id) FROM academic_event WHERE title = ?", Long.class, title);
    }

    private long insertAnnouncement(String title, boolean published) {
        jdbc.update("INSERT INTO department_announcement (title, body, published, notify) VALUES (?, 'govde', ?, FALSE)",
                title, published);
        return jdbc.queryForObject("SELECT MAX(id) FROM department_announcement WHERE title = ?", Long.class, title);
    }

    private long insertExam(String title) {
        jdbc.update("INSERT INTO exam_schedule (title, term, starts_at, published) VALUES (?, '2026-GUZ', CURRENT_TIMESTAMP, TRUE)",
                title);
        return jdbc.queryForObject("SELECT MAX(id) FROM exam_schedule WHERE title = ?", Long.class, title);
    }

    @Test
    void academicBulkPublishUnpublishDeleteForEveryEntity() throws Exception {
        long c1 = insertCalendar("P15 takvim 1", false);
        long c2 = insertCalendar("P15 takvim 2", true);
        MockHttpServletResponse pub = postJson("/api/admin/academic/bulk", "{\"entity\":\"CALENDAR\",\"action\":\"PUBLISH\",\"ids\":["
                + c1 + "," + c2 + ",987654321],\"reason\":\"donem basi\"}");
        assertEquals(200, pub.getStatus(), pub.getContentAsString());
        JsonNode j = OM.readTree(pub.getContentAsString());
        assertEquals(1, j.get("done").asInt());
        assertEquals(2, j.get("skipped").asInt());
        assertTrue(jdbc.queryForObject("SELECT published FROM academic_event WHERE id = ?", Boolean.class, c1));

        long x = insertExam("P15 sinav");
        MockHttpServletResponse unExam = postJson("/api/admin/academic/bulk",
                "{\"entity\":\"EXAM\",\"action\":\"UNPUBLISH\",\"ids\":[" + x + "],\"reason\":\"hatali tarih\"}");
        assertEquals(1, OM.readTree(unExam.getContentAsString()).get("done").asInt());
        assertFalse(jdbc.queryForObject("SELECT published FROM exam_schedule WHERE id = ?", Boolean.class, x));

        long a = insertAnnouncement("P15 duyuru", false);
        MockHttpServletResponse pubAnn = postJson("/api/admin/academic/bulk",
                "{\"entity\":\"ANNOUNCEMENT\",\"action\":\"PUBLISH\",\"ids\":[" + a + "],\"reason\":\"duyuru yayini\"}");
        assertEquals(1, OM.readTree(pubAnn.getContentAsString()).get("done").asInt());
        assertTrue(jdbc.queryForObject("SELECT published FROM department_announcement WHERE id = ?", Boolean.class, a));

        MockHttpServletResponse del = postJson("/api/admin/academic/bulk", "{\"entity\":\"CALENDAR\",\"action\":\"DELETE\",\"ids\":["
                + c1 + "," + c2 + "],\"reason\":\"yanlis yuklenmis\"}");
        assertEquals(2, OM.readTree(del.getContentAsString()).get("done").asInt());
        assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM academic_event WHERE id IN (?, ?)", Integer.class, c1, c2));
        MockHttpServletResponse delAnn = postJson("/api/admin/academic/bulk",
                "{\"entity\":\"ANNOUNCEMENT\",\"action\":\"DELETE\",\"ids\":[" + a + "," + a + "],\"reason\":\"yanlis yuklenmis\"}");
        assertEquals(1, OM.readTree(delAnn.getContentAsString()).get("requested").asInt());

        assertEquals(400, postJson("/api/admin/academic/bulk",
                "{\"entity\":\"CALENDAR\",\"action\":\"DELETE\",\"ids\":[" + c1 + "]}").getStatus());
        assertEquals(400, postJson("/api/admin/academic/bulk",
                "{\"entity\":\"NOPE\",\"action\":\"DELETE\",\"ids\":[1],\"reason\":\"toplu inceleme\"}").getStatus());
    }

    @Test
    void academicCsvRequiresEntityAndEscapes() throws Exception {
        MockHttpServletResponse bad = call(get("/api/admin/academic/export.csv"));
        assertEquals(400, bad.getStatus());
        assertEquals("EXPORT_ENTITY_INVALID", OM.readTree(bad.getContentAsString()).get("code").asText());

        insertCalendar("=cmd|' /C calc'!A0 P15", true);
        String csv = call(get("/api/admin/academic/export.csv").param("entity", "CALENDAR").param("q", "P15"))
                .getContentAsString(java.nio.charset.StandardCharsets.UTF_8);
        assertTrue(csv.startsWith("﻿id,kind,title,startsAt"), csv);
        assertTrue(csv.contains("'=cmd"), csv);
        assertFalse(csv.contains(",=cmd"));

        insertAnnouncement("P15 csv duyuru", true);
        String ann = call(get("/api/admin/academic/export.csv").param("entity", "ANNOUNCEMENT").param("q", "P15 csv"))
                .getContentAsString(java.nio.charset.StandardCharsets.UTF_8);
        assertTrue(ann.contains("P15 csv duyuru"));
        assertFalse(ann.contains("govde"), "duyuru govdesi disa aktarilmaz");
        assertEquals(200, call(get("/api/admin/academic/export.csv").param("entity", "EXAM")).getStatus());
    }

    // ---- kaynaklar ----

    @Test
    void sourcesStatusAggregatesExistingStatus() throws Exception {
        status.markMaintenance(StatusService.NEWS, "x".repeat(400));
        status.markOk(StatusService.MENU, "tamam");
        news("P15 durum", false);
        MockHttpServletResponse res = call(get("/api/admin/sources/status"));
        assertEquals(200, res.getStatus(), res.getContentAsString());
        JsonNode j = OM.readTree(res.getContentAsString());
        assertTrue(j.get("news").get("maintenance").asBoolean());
        assertTrue(j.get("news").get("message").asText().length() <= 203, "hata mesaji kisaltilir");
        assertTrue(j.get("news").get("itemsLast7d").asLong() >= 1);
        assertTrue(j.get("news").get("byType").has("HABER"));
        assertFalse(j.get("menu").get("maintenance").asBoolean());
        assertEquals("tamam", j.get("menu").get("message").asText());
        assertEquals(3, j.get("syncPerHour").asInt());
    }

    @Test
    void sourcesSyncRequiresReasonRateLimitsAndDelegates() throws Exception {
        when(newsSync.sync()).thenReturn(Map.of(ContentType.HABER, 2, ContentType.DUYURU, 0));
        when(menuSync.sync()).thenReturn(5);
        assertEquals(400, postJson("/api/admin/sources/sync", "{\"source\":\"NEWS\"}").getStatus());
        verify(newsSync, never()).sync();

        MockHttpServletResponse n = postJson("/api/admin/sources/sync", "{\"source\":\"NEWS\",\"reason\":\"acil haber\"}");
        assertEquals(200, n.getStatus(), n.getContentAsString());
        assertEquals(2, OM.readTree(n.getContentAsString()).get("changed").asInt());
        MockHttpServletResponse m = postJson("/api/admin/sources/sync", "{\"source\":\"MENU\",\"reason\":\"yeni ay menusu\"}");
        assertEquals(5, OM.readTree(m.getContentAsString()).get("changed").asInt());
        verify(limiter).check(eq("sources-sync:NEWS"), eq(3), eq(java.time.Duration.ofHours(1)));

        org.mockito.Mockito.doThrow(new RateLimitedException(120)).when(limiter)
                .check(eq("sources-sync:MENU"), eq(3), any());
        MockHttpServletResponse limited = postJson("/api/admin/sources/sync", "{\"source\":\"MENU\",\"reason\":\"yeni ay menusu\"}");
        assertEquals(429, limited.getStatus());
    }
}
