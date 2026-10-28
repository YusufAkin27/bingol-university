package edu.bingol.backend.moderation.admin;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import edu.bingol.backend.admin.AdminReasonFilter;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.moderation.ModerationAppeal;
import edu.bingol.backend.moderation.ModerationAppealRepository;
import edu.bingol.backend.moderation.ModerationStrike;
import edu.bingol.backend.moderation.ModerationStrikeRepository;
import edu.bingol.backend.moderation.ModerationTargetState;
import edu.bingol.backend.moderation.ModerationTargetStateRepository;
import edu.bingol.backend.moderation.Report;
import edu.bingol.backend.moderation.ReportReason;
import edu.bingol.backend.moderation.ReportRepository;
import edu.bingol.backend.moderation.ReportTargetType;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

/**
 * P11 HTTP sozlesmesi (H2): yetki, strike listesi/affi (sayac etkisi, bildirim), gizlenen icerik listesi ve geri alma
 * (geri alinamayan hedefte hata), sebep sablonu CRUD + geriye uyum, rapor/itiraz CSV (formul kacisi).
 */
@SpringBootTest
class ModerationAdminHttpTest {

    private static final ObjectMapper OM = new ObjectMapper();
    private static final long ADMIN_ID = 990101L;

    @Autowired WebApplicationContext ctx;
    @Autowired UserRepository users;
    @Autowired ModerationStrikeRepository strikes;
    @Autowired ModerationTargetStateRepository states;
    @Autowired ReportRepository reports;
    @Autowired ModerationAppealRepository appeals;
    @Autowired ModerationReasonTemplateRepository templates;
    /** Testlerde Redis yok: hiz siniri sahte. Bildirim gonderimi dogrulanir. */
    @MockitoBean RateLimiter limiter;
    @MockitoBean NotificationService notifications;
    MockMvc mvc;

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.webAppContextSetup(ctx).addFilters(ctx.getBean(AdminReasonFilter.class))
                .apply(springSecurity()).build();
        templates.deleteAll(); // her test bos tabloyla (eski sabit liste) baslar
    }

    private static UsernamePasswordAuthenticationToken admin() {
        return new UsernamePasswordAuthenticationToken(ADMIN_ID, null, List.of(new SimpleGrantedAuthority("ROLE_ADMIN")));
    }

    private static UsernamePasswordAuthenticationToken plainUser() {
        return new UsernamePasswordAuthenticationToken(990102L, null, List.of(new SimpleGrantedAuthority("ROLE_USER")));
    }

    private MvcResult run(MockHttpServletRequestBuilder b) throws Exception {
        return mvc.perform(b.with(authentication(admin()))).andReturn();
    }

    private static JsonNode json(MvcResult r, int status) throws Exception {
        MockHttpServletResponse res = r.getResponse();
        assertEquals(status, res.getStatus(), res.getContentAsString());
        String body = res.getContentAsString();
        return body.isEmpty() ? null : OM.readTree(body);
    }

    private static String code(MvcResult r) throws Exception {
        return OM.readTree(r.getResponse().getContentAsString()).get("code").asText();
    }

    private static String tag() {
        return UUID.randomUUID().toString().substring(0, 8);
    }

    private User user(String name) {
        User u = new User();
        u.setEmail(name.toLowerCase().replace(' ', '.') + "." + tag() + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName(name);
        u.setEmailVerified(true);
        return users.save(u);
    }

    private ModerationStrike strike(User u, ReportTargetType type, Long targetId, boolean revoked) {
        ModerationStrike s = new ModerationStrike();
        s.setUserId(u.getId());
        s.setTargetType(type);
        s.setTargetId(targetId);
        s.setResolution(Report.Resolution.HIDE);
        if (revoked) {
            s.setRevokedAt(java.time.Instant.now());
        }
        return strikes.save(s);
    }

    private static String body(String reason) {
        return "{\"reason\":\"" + reason + "\"}";
    }

    // ---- yetki ----

    @Test
    void everyEndpointRejectsAnonymousAndPlainUsers() throws Exception {
        List<MockHttpServletRequestBuilder> reqs = List.of(
                get("/api/admin/moderation/strikes"),
                get("/api/admin/users/1/strikes"),
                post("/api/admin/moderation/strikes/1/forgive").contentType("application/json").content(body("neden yok")),
                get("/api/admin/moderation/hidden"),
                post("/api/admin/moderation/hidden/POST/1/restore").contentType("application/json").content(body("neden yok")),
                get("/api/admin/moderation/reason-templates"),
                post("/api/admin/moderation/reason-templates").contentType("application/json").content("{}"),
                put("/api/admin/moderation/reason-templates/1").contentType("application/json").content("{}"),
                delete("/api/admin/moderation/reason-templates/1"),
                get("/api/admin/reports/export.csv"),
                get("/api/admin/appeals/export.csv"));
        for (MockHttpServletRequestBuilder b : reqs) {
            assertEquals(401, mvc.perform(b).andReturn().getResponse().getStatus(), b.toString());
        }
        for (MockHttpServletRequestBuilder b : reqs) {
            assertEquals(403, mvc.perform(b.with(authentication(plainUser()))).andReturn().getResponse().getStatus(), b.toString());
        }
    }

    // ---- strike ----

    @Test
    void forgiveLowersCounterStoresReasonAndNotifiesUser() throws Exception {
        User u = user("Ihlalli Kisi");
        ModerationStrike a = strike(u, ReportTargetType.POST, 11L, false);
        ModerationStrike b = strike(u, ReportTargetType.POST, 12L, false);
        strike(u, ReportTargetType.POST, 13L, true); // zaten sayilmiyor

        JsonNode before = json(run(get("/api/admin/users/" + u.getId() + "/strikes")), 200);
        assertEquals(2, before.get("activeCount").asLong());
        assertEquals(3, before.get("items").size());

        JsonNode res = json(run(post("/api/admin/moderation/strikes/" + a.getId() + "/forgive")
                .contentType("application/json").content(body("Hatali karar verilmisti"))), 200);
        assertEquals(1, res.get("remaining").asLong(), "sayac dustu");
        assertEquals(u.getId(), res.get("userId").asLong());

        ModerationStrike saved = strikes.findById(a.getId()).orElseThrow();
        assertNotNull(saved.getRevokedAt());
        assertEquals(ADMIN_ID, saved.getForgivenBy());
        assertEquals("Hatali karar verilmisti", saved.getForgivenReason());
        verify(notifications).sendTemplated(eq(u.getId()), eq(NotificationType.SYSTEM), eq("notif.mod.strike.forgiven"), any());

        JsonNode after = json(run(get("/api/admin/users/" + u.getId() + "/strikes")), 200);
        assertEquals(1, after.get("activeCount").asLong());
        // ikinci af ve baska kayit etkilenmez
        assertEquals("STRIKE_ALREADY_REVOKED", code(run(post("/api/admin/moderation/strikes/" + a.getId() + "/forgive")
                .contentType("application/json").content(body("tekrar deneme")))));
        assertNull(strikes.findById(b.getId()).orElseThrow().getRevokedAt());
    }

    @Test
    void forgiveValidatesReasonAndExistence() throws Exception {
        User u = user("Af Dogrulama");
        ModerationStrike s = strike(u, ReportTargetType.POST, 21L, false);
        assertEquals(400, run(post("/api/admin/moderation/strikes/" + s.getId() + "/forgive")
                .contentType("application/json").content(body("kisa"))).getResponse().getStatus());
        assertEquals(400, run(post("/api/admin/moderation/strikes/" + s.getId() + "/forgive")
                .contentType("application/json").content("{}")).getResponse().getStatus());
        assertEquals("STRIKE_NOT_FOUND", code(run(post("/api/admin/moderation/strikes/999999999/forgive")
                .contentType("application/json").content(body("yeterince uzun")))));
        assertNull(strikes.findById(s.getId()).orElseThrow().getRevokedAt(), "gecersiz istek afetmez");
        verify(notifications, never()).sendTemplated(eq(u.getId()), any(), eq("notif.mod.strike.forgiven"), any());
        assertEquals("USER_NOT_FOUND", code(run(get("/api/admin/users/999999999/strikes"))));
    }

    @Test
    void strikeListFiltersByUserStatusTypeAndDate() throws Exception {
        User u = user("Liste Kisi");
        strike(u, ReportTargetType.POST, 31L, false);
        strike(u, ReportTargetType.EVENT, 32L, false);
        strike(u, ReportTargetType.POST, 33L, true);
        String base = "/api/admin/moderation/strikes?userId=" + u.getId();

        JsonNode all = json(run(get(base)), 200);
        assertEquals(3, all.get("total").asLong());
        for (String f : List.of("id", "userId", "userName", "userEmail", "targetType", "targetId", "resolution", "createdAt",
                "revokedAt", "active", "forgiven")) {
            assertTrue(all.get("items").get(0).has(f), "StrikeRow." + f);
        }
        assertEquals(2, json(run(get(base + "&status=ACTIVE")), 200).get("total").asLong());
        assertEquals(1, json(run(get(base + "&status=REVOKED")), 200).get("total").asLong());
        assertEquals(1, json(run(get(base + "&targetType=EVENT")), 200).get("total").asLong());
        String today = java.time.LocalDate.now(java.time.ZoneId.of("Europe/Istanbul")).toString();
        assertEquals(3, json(run(get(base + "&from=" + today + "&to=" + today)), 200).get("total").asLong());
        assertEquals(0, json(run(get(base + "&from=2999-01-01")), 200).get("total").asLong());
        assertEquals(1, json(run(get(base + "&size=1&page=1")), 200).get("items").size());
    }

    // ---- gizlenen icerik ----

    private ModerationTargetState hidden(ReportTargetType type, long id, ModerationTargetState.HiddenBy by) {
        ModerationTargetState st = new ModerationTargetState();
        st.setTargetType(type);
        st.setTargetId(id);
        st.setHiddenBy(by);
        st.setHiddenAt(java.time.Instant.now());
        return states.save(st);
    }

    @Test
    void hiddenListAndNonReversibleRestoreIsRejected() throws Exception {
        User target = user("Gizli Kullanici"); // USER turu geri alinamaz (askiya alma ayri akis)
        hidden(ReportTargetType.USER, target.getId(), ModerationTargetState.HiddenBy.ADMIN);

        JsonNode list = json(run(get("/api/admin/moderation/hidden?targetType=USER&hiddenBy=ADMIN&size=100")), 200);
        JsonNode row = null;
        for (JsonNode r : list.get("items")) {
            if (r.get("targetId").asLong() == target.getId()) {
                row = r;
            }
        }
        assertNotNull(row, "gizli satir listede");
        assertFalse(row.get("reversible").asBoolean());
        assertTrue(row.get("exists").asBoolean());
        assertEquals("Gizli Kullanici", row.get("ownerName").asText());

        assertEquals("TARGET_NOT_REVERSIBLE", code(run(post("/api/admin/moderation/hidden/USER/" + target.getId() + "/restore")
                .contentType("application/json").content(body("geri almayi deniyorum")))));
        assertTrue(states.findByTargetTypeAndTargetId(ReportTargetType.USER, target.getId()).isPresent(),
                "hata durumunda gizleme isareti silinmez");
    }

    @Test
    void restoreValidatesTypeReasonAndExistence() throws Exception {
        assertEquals("HIDDEN_CONTENT_NOT_FOUND", code(run(post("/api/admin/moderation/hidden/POST/987654321/restore")
                .contentType("application/json").content(body("yeterince uzun")))));
        assertEquals("TARGET_TYPE_UNSUPPORTED", code(run(post("/api/admin/moderation/hidden/NOPE/1/restore")
                .contentType("application/json").content(body("yeterince uzun")))));
        assertEquals(400, run(post("/api/admin/moderation/hidden/POST/1/restore")
                .contentType("application/json").content(body("kisa"))).getResponse().getStatus());
    }

    // ---- sebep sablonlari ----

    @Test
    void legacyReasonTemplatesKeepShapeAndFallBackToFixedList() throws Exception {
        JsonNode legacy = json(run(get("/api/admin/reports/reason-templates")), 200);
        assertEquals(9, legacy.size(), "tablo bosken eski sabit liste");
        assertEquals("SPAM", legacy.get(0).get("code").asText());
        assertTrue(legacy.get(0).has("text"));
        assertTrue(legacy.get(0).get("texts").has("tr") && legacy.get(0).get("texts").has("en")
                && legacy.get(0).get("texts").has("ar"));
    }

    @Test
    void templateCrudStaysConsistentWithLegacyEndpoint() throws Exception {
        String c = "T" + tag().toUpperCase();
        MvcResult created = run(post("/api/admin/moderation/reason-templates").contentType("application/json")
                .content("{\"code\":\"" + c.toLowerCase() + "\",\"textTr\":\"Kural ihlali\",\"textEn\":\"Rule violation\"}"));
        JsonNode t = json(created, 201);
        long id = t.get("id").asLong();
        assertEquals(c, t.get("code").asText(), "kod buyuk harfe cevrilir");
        assertEquals("DECISION", t.get("kind").asText());
        assertTrue(t.get("active").asBoolean());
        assertTrue(t.get("textAr").isNull());

        // ayni kod ikinci kez
        assertEquals("REASON_TEMPLATE_EXISTS", code(run(post("/api/admin/moderation/reason-templates")
                .contentType("application/json").content("{\"code\":\"" + c + "\",\"textTr\":\"x\"}"))));
        // eski uc artik tablodan okur; ar metni bos oldugu icin Turkceye duser
        JsonNode legacy = json(run(get("/api/admin/reports/reason-templates")), 200);
        assertEquals(1, legacy.size());
        assertEquals(c, legacy.get(0).get("code").asText());
        assertEquals("Rule violation", legacy.get(0).get("texts").get("en").asText());
        assertEquals("Kural ihlali", legacy.get(0).get("texts").get("ar").asText());

        // guncelle: pasif sablon eski uctan kalkar
        json(run(put("/api/admin/moderation/reason-templates/" + id).contentType("application/json")
                .content("{\"textTr\":\"Kural ihlali 2\",\"active\":false}")), 200);
        assertEquals(0, json(run(get("/api/admin/reports/reason-templates")), 200).size());
        JsonNode admin = json(run(get("/api/admin/moderation/reason-templates")), 200);
        assertEquals(50, admin.get("max").asInt());
        assertEquals(1, admin.get("items").size(), "yonetim listesi pasifleri de gosterir");
        assertFalse(admin.get("items").get(0).get("active").asBoolean());

        assertEquals(204, run(delete("/api/admin/moderation/reason-templates/" + id)).getResponse().getStatus());
        assertEquals("REASON_TEMPLATE_NOT_FOUND", code(run(delete("/api/admin/moderation/reason-templates/" + id))));
        assertEquals("REASON_TEMPLATE_NOT_FOUND", code(run(put("/api/admin/moderation/reason-templates/" + id)
                .contentType("application/json").content("{\"textTr\":\"x\"}"))));
    }

    @Test
    void templateValidationAndLimit() throws Exception {
        assertEquals(400, run(post("/api/admin/moderation/reason-templates").contentType("application/json")
                .content("{\"code\":\"X\",\"textTr\":\"x\"}")).getResponse().getStatus(), "kod en az 2 karakter");
        assertEquals(400, run(post("/api/admin/moderation/reason-templates").contentType("application/json")
                .content("{\"code\":\"OK_CODE\"}")).getResponse().getStatus(), "Turkce metin zorunlu");
        assertEquals("REASON_TEMPLATE_INVALID", code(run(post("/api/admin/moderation/reason-templates")
                .contentType("application/json").content("{\"textTr\":\"kodsuz\"}"))));
        for (int i = 0; i < ReasonTemplateService.MAX; i++) {
            json(run(post("/api/admin/moderation/reason-templates").contentType("application/json")
                    .content("{\"code\":\"LIM_" + i + "\",\"textTr\":\"Sablon " + i + "\"}")), 201);
        }
        assertEquals("REASON_TEMPLATE_LIMIT", code(run(post("/api/admin/moderation/reason-templates")
                .contentType("application/json").content("{\"code\":\"LIM_EXTRA\",\"textTr\":\"fazla\"}"))));
    }

    // ---- CSV ----

    private Report report(long reporter, ReportTargetType type, long target, String note, Report.Status st) {
        Report r = new Report();
        r.setReporterId(reporter);
        r.setTargetType(type);
        r.setTargetId(target);
        r.setReason(ReportReason.SPAM);
        r.setNote(note);
        r.setStatus(st);
        if (st == Report.Status.RESOLVED) {
            r.setResolution(Report.Resolution.DISMISS);
        }
        return reports.save(r);
    }

    @Test
    void reportsCsvEscapesFormulasAndFilters() throws Exception {
        long target = 700_000L + (long) (Math.random() * 90_000);
        report(5L, ReportTargetType.COMMUNITY, target, "=HYPERLINK(\"http://x\")", Report.Status.OPEN);
        report(6L, ReportTargetType.COMMUNITY, target, "normal not", Report.Status.RESOLVED);

        MvcResult all = run(get("/api/admin/reports/export.csv").param("targetType", "COMMUNITY"));
        assertEquals(200, all.getResponse().getStatus());
        assertTrue(all.getResponse().getContentType().startsWith("text/csv"));
        assertTrue(all.getResponse().getHeader("Content-Disposition").contains("raporlar.csv"));
        String csv = all.getResponse().getContentAsString(java.nio.charset.StandardCharsets.UTF_8);
        assertTrue(csv.startsWith("﻿id,durum,karar"), "BOM + baslik");
        assertTrue(csv.contains("\"'=HYPERLINK(\"\"http://x\"\")\""), "formul oneki kacirildi: " + csv);
        assertFalse(csv.contains(",=HYPERLINK"), "ham formul hucre basinda olmaz");

        String open = run(get("/api/admin/reports/export.csv").param("status", "OPEN").param("targetType", "COMMUNITY"))
                .getResponse().getContentAsString(java.nio.charset.StandardCharsets.UTF_8);
        assertTrue(open.contains("HYPERLINK"));
        assertFalse(open.contains("normal not"), "durum suzgeci");
        String resolved = run(get("/api/admin/reports/export.csv").param("status", "RESOLVED").param("resolution", "DISMISS")
                .param("targetType", "COMMUNITY")).getResponse().getContentAsString(java.nio.charset.StandardCharsets.UTF_8);
        assertTrue(resolved.contains("normal not"));
        assertFalse(resolved.contains("HYPERLINK"));
        String none = run(get("/api/admin/reports/export.csv").param("from", "2999-01-01"))
                .getResponse().getContentAsString(java.nio.charset.StandardCharsets.UTF_8);
        assertEquals(1, none.split("\r\n").length, "yalniz baslik");
    }

    @Test
    void appealsCsvEscapesFormulasAndFilters() throws Exception {
        ModerationAppeal a = new ModerationAppeal();
        a.setUserId(8L);
        a.setTargetType(ReportTargetType.EVENT_COVER);
        a.setTargetId(800_001L);
        a.setMessage("+SUM(1;1) itiraz metni");
        appeals.save(a);
        ModerationAppeal b = new ModerationAppeal();
        b.setUserId(9L);
        b.setTargetType(ReportTargetType.EVENT_COVER);
        b.setTargetId(800_002L);
        b.setMessage("kabul edilen itiraz");
        b.setStatus(ModerationAppeal.Status.ACCEPTED);
        appeals.save(b);

        MvcResult res = run(get("/api/admin/appeals/export.csv").param("targetType", "EVENT_COVER"));
        assertEquals(200, res.getResponse().getStatus());
        String csv = res.getResponse().getContentAsString(java.nio.charset.StandardCharsets.UTF_8);
        assertTrue(csv.startsWith("﻿id,durum,kullaniciId"));
        assertTrue(csv.contains("'+SUM(1;1) itiraz metni"), "formul oneki kacirildi: " + csv);
        String accepted = run(get("/api/admin/appeals/export.csv").param("status", "ACCEPTED")
                .param("targetType", "EVENT_COVER")).getResponse().getContentAsString(java.nio.charset.StandardCharsets.UTF_8);
        assertTrue(accepted.contains("kabul edilen itiraz"));
        assertFalse(accepted.contains("SUM(1;1)"));
    }
}
