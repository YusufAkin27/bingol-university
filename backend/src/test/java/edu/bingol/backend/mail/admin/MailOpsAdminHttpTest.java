package edu.bingol.backend.mail.admin;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import edu.bingol.backend.admin.AdminReasonFilter;
import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.mail.MailOutbox;
import edu.bingol.backend.mail.MailOutboxRepository;
import edu.bingol.backend.mail.MailStatus;
import edu.bingol.backend.mail.MailSuppression;
import edu.bingol.backend.mail.MailSuppressionService;
import edu.bingol.backend.mail.MailTemplate;
import edu.bingol.backend.mail.SuppressionReason;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
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
 * P13 HTTP sozlesmesi (H2): yetki, bastirma (maskeleme, elle ekleme, UNSUBSCRIBED/COMPLAINT cift onayli kaldirma, CSV
 * kacisi), kuyruk (maskeli liste, icerigin HICBIR yanitta olmamasi, retry/cancel durum kurallari, toplu kismi basari).
 */
@SpringBootTest
class MailOpsAdminHttpTest {

    private static final ObjectMapper OM = new ObjectMapper();
    private static final long ADMIN_ID = 990301L;
    private static final String SECRET_CODE = "KOD-987654-GIZLI";

    @Autowired WebApplicationContext ctx;
    @Autowired UserRepository users;
    @Autowired MailOutboxRepository outbox;
    @Autowired MailSuppressionQueryRepository suppressionRepo;
    @Autowired MailSuppressionService suppression;
    @MockitoBean RateLimiter limiter;
    MockMvc mvc;

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.webAppContextSetup(ctx).addFilters(ctx.getBean(AdminReasonFilter.class))
                .apply(springSecurity()).build();
    }

    // ---- yardimcilar ----

    private static UsernamePasswordAuthenticationToken admin() {
        return new UsernamePasswordAuthenticationToken(ADMIN_ID, null, List.of(new SimpleGrantedAuthority("ROLE_ADMIN")));
    }

    private static UsernamePasswordAuthenticationToken asUser(Long id) {
        return new UsernamePasswordAuthenticationToken(id, null, List.of(new SimpleGrantedAuthority("ROLE_USER")));
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

    private static String body(MvcResult r) throws Exception {
        return r.getResponse().getContentAsString(StandardCharsets.UTF_8);
    }

    private static String reason(String r) {
        return "{\"reason\":\"" + r + "\"}";
    }

    private String email(String prefix) {
        return prefix + "." + tag() + "@bingol.edu.tr";
    }

    private User user(String mail) {
        User u = new User();
        u.setEmail(mail);
        u.setPasswordHash("x");
        u.setDisplayName("Test Kullanici");
        u.setEmailVerified(true);
        u.setRole(Role.USER);
        return users.save(u);
    }

    private MailOutbox row(String to, MailTemplate t, MailStatus st, String vars, Instant created) {
        MailOutbox m = new MailOutbox();
        m.setToAddress(to);
        m.setTemplate(t);
        m.setLang("tr");
        m.setVarsJson(vars);
        m.setStatus(st);
        m.setAttempts(st == MailStatus.DEAD ? 5 : 0);
        m.setNextAttemptAt(Instant.now());
        m.setCreatedAt(created);
        m.setPriority(t == MailTemplate.ANNOUNCEMENT || t == MailTemplate.CUSTOM ? 1 : 0);
        m.setLastError(st == MailStatus.DEAD ? "SMTPSendFailedException: 550 mailbox " + to + " unavailable" : null);
        return outbox.save(m);
    }

    private MailSuppression supp(long id) {
        return suppressionRepo.findById(id).orElse(null);
    }

    // ---- yetki ----

    @Test
    void everyEndpointRequiresAdmin() throws Exception {
        List<MockHttpServletRequestBuilder> reqs = List.of(
                get("/api/admin/mail/suppressions"),
                get("/api/admin/mail/suppressions/1"),
                post("/api/admin/mail/suppressions").contentType("application/json")
                        .content("{\"email\":\"a@b.co\",\"note\":\"neden yok\"}"),
                delete("/api/admin/mail/suppressions/1"),
                get("/api/admin/mail/suppressions/export.csv"),
                get("/api/admin/mail/outbox"),
                get("/api/admin/mail/outbox/1"),
                post("/api/admin/mail/outbox/1/retry"),
                post("/api/admin/mail/outbox/1/cancel"),
                post("/api/admin/mail/outbox/bulk").contentType("application/json")
                        .content("{\"action\":\"RETRY\",\"ids\":[1],\"reason\":\"neden yok\"}"),
                get("/api/admin/mail/quota"));
        for (MockHttpServletRequestBuilder b : reqs) {
            assertEquals(401, mvc.perform(b).andReturn().getResponse().getStatus(), b.toString());
        }
        for (MockHttpServletRequestBuilder b : reqs) {
            assertEquals(403, mvc.perform(b.with(authentication(asUser(990302L)))).andReturn().getResponse().getStatus(),
                    b.toString());
        }
    }

    // ---- bastirma ----

    @Test
    void manualAddMasksEverywhereAndRejectsBadInput() throws Exception {
        String mail = email("elle.ekle");
        String payload = "{\"email\":\"" + mail + "\",\"reason\":\"MANUAL\",\"note\":\"Kullanici telefonla istedi\"}";
        MvcResult created = run(post("/api/admin/mail/suppressions").contentType("application/json").content(payload));
        JsonNode j = json(created, 201);
        assertEquals("MANUAL", j.get("reason").asText());
        assertEquals("e***@bingol.edu.tr", j.get("emailMasked").asText());
        assertFalse(body(created).contains(mail), "ekleme yaniti tam adres icermemeli");
        assertEquals("MAIL_SUPPRESSION", AuditContext.of(created.getRequest()).targetType(), "denetim hedefi");

        // ayni adres (buyuk harf farki) -> 409
        assertEquals("MAILOPS_SUPPRESSION_EXISTS", code(run(post("/api/admin/mail/suppressions")
                .contentType("application/json").content(payload.replace(mail, mail.toUpperCase())))));
        assertEquals(409, run(post("/api/admin/mail/suppressions").contentType("application/json").content(payload))
                .getResponse().getStatus());
        // gecersiz adres, gecersiz sebep, kisa not
        assertEquals("MAILOPS_EMAIL_INVALID", code(run(post("/api/admin/mail/suppressions")
                .contentType("application/json").content("{\"email\":\"yok-etmez\",\"note\":\"Yeterli not\"}"))));
        assertEquals("MAILOPS_REASON_INVALID", code(run(post("/api/admin/mail/suppressions")
                .contentType("application/json")
                .content("{\"email\":\"" + email("x") + "\",\"reason\":\"BOUNCED\",\"note\":\"Yeterli not\"}"))));
        assertEquals(400, run(post("/api/admin/mail/suppressions").contentType("application/json")
                .content("{\"email\":\"" + email("y") + "\",\"note\":\"ab\"}")).getResponse().getStatus());
        assertEquals(400, run(post("/api/admin/mail/suppressions").contentType("application/json")
                .content("{\"email\":\"" + email("z") + "\"}")).getResponse().getStatus());
        // bastirma gercekten calisiyor
        assertTrue(suppression.isSuppressed(mail));
    }

    @Test
    void listIsMaskedFilteredAndSearchable() throws Exception {
        String known = email("kayitli.kisi");
        user(known);
        suppression.suppress(known, SuppressionReason.UNSUBSCRIBED);
        String stranger = email("yabanci.adres");
        suppression.suppress(stranger, SuppressionReason.BOUNCED);

        MvcResult all = run(get("/api/admin/mail/suppressions").param("size", "100"));
        String text = body(all);
        assertFalse(text.contains(known), "liste tam adres icermemeli");
        assertFalse(text.contains(stranger), "liste tam adres icermemeli");

        // tam adresle arama (ozete cevrilir)
        JsonNode byKnown = json(run(get("/api/admin/mail/suppressions").param("q", known.toUpperCase())), 200);
        assertEquals(1, byKnown.get("total").asInt());
        assertEquals("k***@bingol.edu.tr", byKnown.get("items").get(0).get("emailMasked").asText());
        assertEquals("UNSUBSCRIBED", byKnown.get("items").get(0).get("reason").asText());
        assertTrue(byKnown.get("items").get(0).get("userOptOut").asBoolean());

        // kayitli kullanici adresinde parca arama
        JsonNode partial = json(run(get("/api/admin/mail/suppressions").param("q", "kayitli.kisi")), 200);
        assertTrue(partial.get("total").asInt() >= 1);

        // kayitsiz adres: ozet on eki var, maske yok (duz adres saklanmadigi icin)
        JsonNode byStranger = json(run(get("/api/admin/mail/suppressions").param("q", stranger)), 200);
        assertEquals(1, byStranger.get("total").asInt());
        JsonNode item = byStranger.get("items").get(0);
        assertTrue(item.get("emailMasked").isNull());
        assertEquals(10, item.get("hashPrefix").asText().length());
        assertFalse(item.get("userOptOut").asBoolean());

        // sebep suzgeci + olmayan arama
        JsonNode bounced = json(run(get("/api/admin/mail/suppressions").param("reason", "BOUNCED").param("size", "100")), 200);
        for (JsonNode n : bounced.get("items")) {
            assertEquals("BOUNCED", n.get("reason").asText());
        }
        assertEquals(0, json(run(get("/api/admin/mail/suppressions").param("q", "yok.boyle.biri@x.com")), 200)
                .get("total").asInt());
        assertEquals(400, run(get("/api/admin/mail/suppressions").param("reason", "BILINMEYEN")).getResponse().getStatus());
    }

    @Test
    void detailShowsFullEmailOnlyWhenAUserAccountMatches() throws Exception {
        String known = email("tam.gorunur");
        User u = user(known);
        suppression.suppress(known, SuppressionReason.COMPLAINT);
        String stranger = email("gorunmez");
        suppression.suppress(stranger, SuppressionReason.BOUNCED);

        long idKnown = suppressionRepo.findByEmailHash(MailSuppressionService.hash(known)).orElseThrow().getId();
        MvcResult r = run(get("/api/admin/mail/suppressions/" + idKnown));
        JsonNode d = json(r, 200);
        assertEquals(known, d.get("fullEmail").asText());
        assertTrue(d.get("fullEmailResolved").asBoolean());
        assertEquals(u.getId().longValue(), d.get("userId").asLong());
        assertTrue(d.get("removeNeedsConfirm").asBoolean());
        assertEquals(20, d.get("removeMinReason").asInt());
        assertEquals("COMPLAINT", d.get("removeWarning").asText());
        assertEquals("MAIL_SUPPRESSION", AuditContext.of(r.getRequest()).targetType());

        long idStranger = suppressionRepo.findByEmailHash(MailSuppressionService.hash(stranger)).orElseThrow().getId();
        MvcResult r2 = run(get("/api/admin/mail/suppressions/" + idStranger));
        JsonNode d2 = json(r2, 200);
        assertTrue(d2.get("fullEmail").isNull());
        assertFalse(d2.get("fullEmailResolved").asBoolean());
        assertFalse(body(r2).contains(stranger));
        assertEquals(5, d2.get("removeMinReason").asInt());
        assertFalse(d2.get("removeNeedsConfirm").asBoolean());

        assertEquals("MAILOPS_SUPPRESSION_NOT_FOUND", code(run(get("/api/admin/mail/suppressions/999999999"))));
    }

    @Test
    void removingUserOptOutNeedsConfirmAndLongReason() throws Exception {
        for (SuppressionReason sr : new SuppressionReason[] {SuppressionReason.UNSUBSCRIBED, SuppressionReason.COMPLAINT}) {
            String mail = email("cikti." + sr.name().toLowerCase());
            suppression.suppress(mail, sr);
            long id = suppressionRepo.findByEmailHash(MailSuppressionService.hash(mail)).orElseThrow().getId();

            // onay basligi yok -> 409 uyari (kullanici kendisi cikti)
            MvcResult noConfirm = run(delete("/api/admin/mail/suppressions/" + id)
                    .header("X-Admin-Reason", "Bu bir deneme gerekcesi yirmi karakterden uzun"));
            assertEquals(409, noConfirm.getResponse().getStatus());
            assertEquals("MAILOPS_USER_OPTED_OUT", code(noConfirm));
            // yanlis onay -> 409
            assertEquals(409, run(delete("/api/admin/mail/suppressions/" + id).header("X-Admin-Confirm", "123456")
                    .header("X-Admin-Reason", "Bu bir deneme gerekcesi yirmi karakterden uzun")).getResponse().getStatus());
            // onay var ama sebep < 20 -> 400
            MvcResult shortReason = run(delete("/api/admin/mail/suppressions/" + id)
                    .header("X-Admin-Confirm", String.valueOf(id)).header("X-Admin-Reason", "on dokuz karakter!!"));
            assertEquals(400, shortReason.getResponse().getStatus());
            assertEquals("REASON_REQUIRED", code(shortReason));
            assertNotNull(supp(id), "hatali denemelerde kayit silinmemeli");
            assertTrue(suppression.isSuppressed(mail));
            // sebep yok -> 400
            assertEquals(400, run(delete("/api/admin/mail/suppressions/" + id).header("X-Admin-Confirm", String.valueOf(id)))
                    .getResponse().getStatus());
            // dogru -> 204
            MvcResult ok = run(delete("/api/admin/mail/suppressions/" + id).header("X-Admin-Confirm", String.valueOf(id))
                    .header("X-Admin-Reason", "Kullanici yazili olarak yeniden abone olmak istedi"));
            assertEquals(204, ok.getResponse().getStatus());
            assertNull(supp(id));
            assertFalse(suppression.isSuppressed(mail));
            assertEquals("MAIL_SUPPRESSION", AuditContext.of(ok.getRequest()).targetType());
            assertEquals(String.valueOf(id), AuditContext.of(ok.getRequest()).targetId());
        }
    }

    @Test
    void removingBouncedAndManualNeedsOnlyShortReason() throws Exception {
        String bounced = email("sekti");
        suppression.suppress(bounced, SuppressionReason.BOUNCED);
        long id = suppressionRepo.findByEmailHash(MailSuppressionService.hash(bounced)).orElseThrow().getId();
        assertEquals(400, run(delete("/api/admin/mail/suppressions/" + id).header("X-Admin-Reason", "kisa"))
                .getResponse().getStatus());
        assertEquals(204, run(delete("/api/admin/mail/suppressions/" + id).header("X-Admin-Reason", "adres duzeltildi"))
                .getResponse().getStatus());

        String manual = email("elle");
        JsonNode created = json(run(post("/api/admin/mail/suppressions").contentType("application/json")
                .content("{\"email\":\"" + manual + "\",\"note\":\"Yanlis eklendi\"}")), 201);
        long mid = created.get("id").asLong();
        assertEquals(204, run(delete("/api/admin/mail/suppressions/" + mid).header("X-Admin-Reason", "yanlis eklenmisti"))
                .getResponse().getStatus());
        assertFalse(suppression.isSuppressed(manual));
        assertEquals("MAILOPS_SUPPRESSION_NOT_FOUND",
                code(run(delete("/api/admin/mail/suppressions/" + mid).header("X-Admin-Reason", "tekrar silme"))));
    }

    @Test
    void csvEscapesFormulasAndNeverContainsFullEmail() throws Exception {
        String mail = email("csv.kisi");
        json(run(post("/api/admin/mail/suppressions").contentType("application/json")
                .content("{\"email\":\"" + mail + "\",\"note\":\"=HYPERLINK(\\\"http://x\\\")\"}")), 201);
        MvcResult r = run(get("/api/admin/mail/suppressions/export.csv").param("reason", "MANUAL"));
        assertEquals(200, r.getResponse().getStatus());
        assertTrue(r.getResponse().getContentType().startsWith("text/csv"));
        String csv = body(r);
        assertTrue(csv.startsWith("﻿id,"), csv);
        assertFalse(csv.contains(mail), "CSV tam adres icermemeli");
        assertTrue(csv.contains("\"'=HYPERLINK("), "formul onekli hucre kacirilmali: " + csv);
        assertFalse(csv.contains(",=HYPERLINK"), csv);
        assertEquals("MAIL_SUPPRESSION", AuditContext.of(r.getRequest()).targetType());
    }

    // ---- kuyruk ----

    @Test
    void outboxListAndDetailNeverExposeContentOrFullRecipient() throws Exception {
        String to = email("alici.gizli");
        String vars = "{\"code\":\"" + SECRET_CODE + "\",\"minutes\":\"10\"}";
        MailOutbox pending = row(to, MailTemplate.VERIFICATION_CODE, MailStatus.PENDING, vars, Instant.now());
        MailOutbox dead = row(to, MailTemplate.ANNOUNCEMENT, MailStatus.DEAD, "{}", Instant.now());

        MvcResult list = run(get("/api/admin/mail/outbox").param("q", to).param("size", "50"));
        JsonNode j = json(list, 200);
        assertEquals(2, j.get("total").asInt());
        String text = body(list);
        assertFalse(text.contains(to), "liste tam alici icermemeli");
        assertFalse(text.contains(SECRET_CODE));
        assertFalse(text.contains("varsJson"));
        assertEquals("a***@bingol.edu.tr", j.get("items").get(0).get("toMasked").asText());
        // hata metnindeki adres de maskelenir
        assertFalse(text.contains("mailbox " + to));

        MvcResult detail = run(get("/api/admin/mail/outbox/" + pending.getId()));
        JsonNode d = json(detail, 200);
        String dt = body(detail);
        assertFalse(dt.contains(SECRET_CODE), "ayrinti icerik/degisken donmemeli");
        assertFalse(dt.contains(to));
        assertFalse(dt.contains("varsJson"));
        assertFalse(d.get("contentIncluded").asBoolean());
        assertEquals("PENDING", d.get("status").asText());
        assertTrue(d.get("cancellable").asBoolean());
        assertEquals("MAIL_OUTBOX", AuditContext.of(detail.getRequest()).targetType());
        assertEquals("CREATED", d.get("timeline").get(0).get("event").asText());
        assertEquals("MAILOPS_OUTBOX_NOT_FOUND", code(run(get("/api/admin/mail/outbox/999999999"))));
        assertNotNull(dead);
    }

    @Test
    void outboxFiltersByStatusTemplateRecipientDomainAndId() throws Exception {
        String domain = "alan" + tag() + ".example.org";
        String to = "kisi@" + domain;
        MailOutbox a = row(to, MailTemplate.ACCOUNT_DELETED, MailStatus.SENT, "{}", Instant.now());
        MailOutbox b = row("baska@" + domain, MailTemplate.ANNOUNCEMENT, MailStatus.DEAD, "{}", Instant.now());

        assertEquals(2, json(run(get("/api/admin/mail/outbox").param("q", "@" + domain)), 200).get("total").asInt());
        assertEquals(1, json(run(get("/api/admin/mail/outbox").param("q", to.toUpperCase())), 200).get("total").asInt());
        assertEquals(1, json(run(get("/api/admin/mail/outbox").param("q", String.valueOf(a.getId()))), 200)
                .get("total").asInt());
        assertEquals(1, json(run(get("/api/admin/mail/outbox").param("q", "@" + domain).param("status", "DEAD")), 200)
                .get("total").asInt());
        assertEquals(1, json(run(get("/api/admin/mail/outbox").param("q", "@" + domain).param("template", "ANNOUNCEMENT")), 200)
                .get("total").asInt());
        assertEquals(1, json(run(get("/api/admin/mail/outbox").param("q", "@" + domain).param("category", "ANNOUNCEMENT")), 200)
                .get("total").asInt());
        // parca metin aramasi (adres kesfi) yok
        assertEquals(0, json(run(get("/api/admin/mail/outbox").param("q", "kisi")), 200).get("total").asInt());
        assertEquals(0, json(run(get("/api/admin/mail/outbox").param("q", "@" + domain)
                .param("from", "2000-01-01").param("to", "2000-01-02")), 200).get("total").asInt());
        assertEquals(400, run(get("/api/admin/mail/outbox").param("status", "SENDING")).getResponse().getStatus());
        assertNotNull(b);
    }

    @Test
    void retryRulesProtectAgainstUselessOrUnsafeResends() throws Exception {
        Instant old = Instant.now().minus(1, ChronoUnit.HOURS);
        // ACCOUNT_DELETED: degisken gerektirmez -> denenebilir
        MailOutbox ok = row(email("r1"), MailTemplate.ACCOUNT_DELETED, MailStatus.DEAD, "{}", old);
        MvcResult res = run(post("/api/admin/mail/outbox/" + ok.getId() + "/retry").header("X-Admin-Reason", "sunucu duzeldi"));
        JsonNode j = json(res, 200);
        assertEquals("PENDING", j.get("status").asText());
        assertEquals(MailStatus.PENDING, outbox.findById(ok.getId()).orElseThrow().getStatus());
        assertEquals(0, outbox.findById(ok.getId()).orElseThrow().getAttempts());
        assertEquals("MAIL_OUTBOX", AuditContext.of(res.getRequest()).targetType());
        // PENDING artik denenemez
        assertEquals("MAILOPS_RETRY_STATE", code(run(post("/api/admin/mail/outbox/" + ok.getId() + "/retry"))));

        // eski kod postasi
        MailOutbox stale = row(email("r2"), MailTemplate.VERIFICATION_CODE, MailStatus.DEAD, "{\"code\":\"1\"}", old);
        assertEquals("MAILOPS_RETRY_STALE_CODE", code(run(post("/api/admin/mail/outbox/" + stale.getId() + "/retry"))));
        assertEquals(409, run(post("/api/admin/mail/outbox/" + stale.getId() + "/retry")).getResponse().getStatus());
        assertEquals(MailStatus.DEAD, outbox.findById(stale.getId()).orElseThrow().getStatus());

        // icerigi silinmis duyuru (DEAD/SKIPPED hep silinir)
        MailOutbox cleared = row(email("r3"), MailTemplate.ANNOUNCEMENT, MailStatus.DEAD, "{}", old);
        assertEquals("MAILOPS_RETRY_NO_CONTENT", code(run(post("/api/admin/mail/outbox/" + cleared.getId() + "/retry"))));
        JsonNode cd = json(run(get("/api/admin/mail/outbox/" + cleared.getId())), 200);
        assertFalse(cd.get("retryable").asBoolean());
        assertEquals("MAILOPS_RETRY_NO_CONTENT", cd.get("retryBlockedCode").asText());
        assertTrue(cd.get("contentCleared").asBoolean());

        // degiskeni duran duyuru: bastirilmis adres -> reddedilir; degilse denenir
        String blocked = email("r4");
        suppression.suppress(blocked, SuppressionReason.UNSUBSCRIBED);
        MailOutbox sup = row(blocked, MailTemplate.ANNOUNCEMENT, MailStatus.SKIPPED, "{\"heading\":\"h\",\"message\":\"m\"}", old);
        assertEquals("MAILOPS_RETRY_SUPPRESSED", code(run(post("/api/admin/mail/outbox/" + sup.getId() + "/retry"))));
        MailOutbox fine = row(email("r5"), MailTemplate.ANNOUNCEMENT, MailStatus.SKIPPED, "{\"heading\":\"h\",\"message\":\"m\"}", old);
        assertEquals("PENDING", json(run(post("/api/admin/mail/outbox/" + fine.getId() + "/retry")), 200).get("status").asText());

        // SENT denenemez
        MailOutbox sent = row(email("r6"), MailTemplate.ACCOUNT_DELETED, MailStatus.SENT, "{}", old);
        assertEquals("MAILOPS_RETRY_STATE", code(run(post("/api/admin/mail/outbox/" + sent.getId() + "/retry"))));
        assertEquals("MAILOPS_OUTBOX_NOT_FOUND", code(run(post("/api/admin/mail/outbox/999999999/retry"))));
    }

    @Test
    void cancelOnlyWaitingRecordsAndScrubsVariables() throws Exception {
        MailOutbox pending = row(email("c1"), MailTemplate.VERIFICATION_CODE, MailStatus.PENDING,
                "{\"code\":\"" + SECRET_CODE + "\"}", Instant.now());
        MvcResult res = run(post("/api/admin/mail/outbox/" + pending.getId() + "/cancel").header("X-Admin-Reason", "yanlis gonderim"));
        JsonNode j = json(res, 200);
        assertEquals("SKIPPED", j.get("status").asText());
        assertFalse(body(res).contains(SECRET_CODE));
        MailOutbox after = outbox.findById(pending.getId()).orElseThrow();
        assertEquals(MailStatus.SKIPPED, after.getStatus());
        assertEquals("{}", after.getVarsJson(), "iptalde degiskenler temizlenmeli");
        assertEquals("MAIL_OUTBOX", AuditContext.of(res.getRequest()).targetType());

        MailOutbox failed = row(email("c2"), MailTemplate.ANNOUNCEMENT, MailStatus.FAILED, "{\"heading\":\"h\"}", Instant.now());
        assertEquals("SKIPPED", json(run(post("/api/admin/mail/outbox/" + failed.getId() + "/cancel")), 200).get("status").asText());

        // tekrar iptal / gonderilmis / olu: 409
        assertEquals("MAILOPS_CANCEL_STATE", code(run(post("/api/admin/mail/outbox/" + pending.getId() + "/cancel"))));
        MailOutbox sent = row(email("c3"), MailTemplate.ACCOUNT_DELETED, MailStatus.SENT, "{}", Instant.now());
        assertEquals("MAILOPS_CANCEL_STATE", code(run(post("/api/admin/mail/outbox/" + sent.getId() + "/cancel"))));
        assertEquals(MailStatus.SENT, outbox.findById(sent.getId()).orElseThrow().getStatus());
        assertEquals("MAILOPS_OUTBOX_NOT_FOUND", code(run(post("/api/admin/mail/outbox/999999999/cancel"))));
    }

    @Test
    void bulkSupportsPartialSuccessAndValidatesInput() throws Exception {
        Instant old = Instant.now().minus(1, ChronoUnit.HOURS);
        MailOutbox ok1 = row(email("b1"), MailTemplate.ACCOUNT_DELETED, MailStatus.DEAD, "{}", old);
        MailOutbox ok2 = row(email("b2"), MailTemplate.ACCOUNT_DELETED, MailStatus.SKIPPED, "{}", old);
        MailOutbox cleared = row(email("b3"), MailTemplate.ANNOUNCEMENT, MailStatus.DEAD, "{}", old);
        MailOutbox pending = row(email("b4"), MailTemplate.ACCOUNT_DELETED, MailStatus.PENDING, "{}", old);

        String ids = ok1.getId() + "," + ok2.getId() + "," + cleared.getId() + "," + pending.getId() + ",999999999,"
                + ok1.getId();
        MvcResult res = run(post("/api/admin/mail/outbox/bulk").contentType("application/json")
                .content("{\"action\":\"retry\",\"ids\":[" + ids + "],\"reason\":\"toplu duzeltme\"}"));
        JsonNode j = json(res, 200);
        assertEquals("RETRY", j.get("action").asText());
        assertEquals(5, j.get("requested").asInt(), "yinelenen kimlik tek sayilir");
        assertEquals(2, j.get("succeeded").asInt());
        List<String> failures = new ArrayList<>();
        j.get("failed").forEach(f -> failures.add(f.get("id").asLong() + ":" + f.get("code").asText()));
        assertEquals(3, failures.size(), failures.toString());
        assertTrue(failures.contains(cleared.getId() + ":MAILOPS_RETRY_NO_CONTENT"), failures.toString());
        assertTrue(failures.contains(pending.getId() + ":MAILOPS_RETRY_STATE"), failures.toString());
        assertTrue(failures.contains("999999999:MAILOPS_OUTBOX_NOT_FOUND"), failures.toString());
        assertEquals(MailStatus.PENDING, outbox.findById(ok1.getId()).orElseThrow().getStatus());
        assertEquals(MailStatus.PENDING, outbox.findById(ok2.getId()).orElseThrow().getStatus());
        assertEquals(MailStatus.DEAD, outbox.findById(cleared.getId()).orElseThrow().getStatus());
        assertEquals("MAIL_OUTBOX", AuditContext.of(res.getRequest()).targetType());

        // toplu iptal: yeni PENDING'ler iptal, SENT hata
        MailOutbox sent = row(email("b5"), MailTemplate.ACCOUNT_DELETED, MailStatus.SENT, "{}", old);
        JsonNode cancel = json(run(post("/api/admin/mail/outbox/bulk").contentType("application/json")
                .content("{\"action\":\"CANCEL\",\"ids\":[" + ok1.getId() + "," + sent.getId()
                        + "],\"reason\":\"toplu iptal gerekcesi\"}")), 200);
        assertEquals(1, cancel.get("succeeded").asInt());
        assertEquals("MAILOPS_CANCEL_STATE", cancel.get("failed").get(0).get("code").asText());

        // gecersiz girdiler
        assertEquals("MAILOPS_BULK_INVALID", code(run(post("/api/admin/mail/outbox/bulk").contentType("application/json")
                .content("{\"action\":\"DELETE\",\"ids\":[1],\"reason\":\"gecersiz eylem\"}"))));
        List<String> many = new ArrayList<>();
        for (int i = 1; i <= 201; i++) {
            many.add(String.valueOf(i));
        }
        assertEquals(400, run(post("/api/admin/mail/outbox/bulk").contentType("application/json")
                .content("{\"action\":\"RETRY\",\"ids\":[" + String.join(",", many) + "],\"reason\":\"cok fazla\"}"))
                .getResponse().getStatus());
        assertEquals(400, run(post("/api/admin/mail/outbox/bulk").contentType("application/json")
                .content("{\"action\":\"RETRY\",\"ids\":[],\"reason\":\"bos liste\"}")).getResponse().getStatus());
        assertEquals(400, run(post("/api/admin/mail/outbox/bulk").contentType("application/json")
                .content("{\"action\":\"RETRY\",\"ids\":[1],\"reason\":\"abc\"}")).getResponse().getStatus());
        assertEquals(400, run(post("/api/admin/mail/outbox/bulk").contentType("application/json")
                .content("{\"action\":\"RETRY\",\"ids\":[1]}")).getResponse().getStatus());
    }

    // ---- kota ----

    @Test
    void quotaEndpointReturnsReadOnlyShape() throws Exception {
        JsonNode q = json(run(get("/api/admin/mail/quota")), 200);
        for (String f : new String[] {"enabled", "limit", "reserve", "used", "remaining", "percent", "level", "resetHourUtc",
                "nextReset", "publicCodeUsed", "history", "queue"}) {
            assertTrue(q.has(f), f);
        }
        assertEquals(2, q.get("history").size());
        assertTrue(q.get("queue").has("dead"));
        // salt okunur: yazma yolu yok
        assertEquals(405, run(post("/api/admin/mail/quota")).getResponse().getStatus());
    }
}
