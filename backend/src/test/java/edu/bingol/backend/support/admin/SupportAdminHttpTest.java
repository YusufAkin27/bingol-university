package edu.bingol.backend.support.admin;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import edu.bingol.backend.admin.AdminReasonFilter;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.Hashing;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.support.faq.FaqItem;
import edu.bingol.backend.support.faq.FaqRepository;
import edu.bingol.backend.support.feedback.Feedback;
import edu.bingol.backend.support.feedback.FeedbackRepository;
import edu.bingol.backend.support.ticket.PublicSupportService;
import edu.bingol.backend.support.ticket.SupportMessage;
import edu.bingol.backend.support.ticket.SupportMessageRepository;
import edu.bingol.backend.support.ticket.SupportTicket;
import edu.bingol.backend.support.ticket.SupportTrackToken;
import edu.bingol.backend.support.ticket.SupportTrackTokenRepository;
import edu.bingol.backend.support.ticket.TicketDtos.TicketDetail;
import edu.bingol.backend.support.ticket.TicketRepository;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.nio.charset.StandardCharsets;
import java.util.List;
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
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

/**
 * P12 HTTP sozlesmesi (H2): yetki, ic not (MUSTERIYE GORUNMEZ: kullanici ucu + herkese acik durum sorgusu), yeniden
 * ac, oncelik/atama, silme (token temizligi), geri bildirim silme/birlestirme (oy tasima), SSS siralama, CSV.
 */
@SpringBootTest
class SupportAdminHttpTest {

    private static final ObjectMapper OM = new ObjectMapper();
    private static final long ADMIN_ID = 990201L;
    private static final String SECRET = "GIZLI-IC-NOT-";

    @Autowired WebApplicationContext ctx;
    @Autowired UserRepository users;
    @Autowired TicketRepository tickets;
    @Autowired SupportMessageRepository messages;
    @Autowired SupportTrackTokenRepository trackTokens;
    @Autowired SupportTicketNoteRepository notes;
    @Autowired FeedbackRepository feedback;
    @Autowired FaqRepository faq;
    @Autowired PublicSupportService publicSupport;
    @Autowired JdbcTemplate jdbc;
    @MockitoBean RateLimiter limiter;
    @MockitoBean NotificationService notifications;
    MockMvc mvc;

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.webAppContextSetup(ctx).addFilters(ctx.getBean(AdminReasonFilter.class))
                .apply(springSecurity()).build();
        // feedback_vote bir JPA varligi degil (yalniz Flyway): testte elle olusturulur
        jdbc.execute("CREATE TABLE IF NOT EXISTS feedback_vote (feedback_id BIGINT NOT NULL, user_id BIGINT NOT NULL, "
                + "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (feedback_id, user_id))");
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

    private MvcResult runAs(Long uid, MockHttpServletRequestBuilder b) throws Exception {
        return mvc.perform(b.with(authentication(asUser(uid)))).andReturn();
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

    private static String csv(MvcResult r) throws Exception {
        assertEquals(200, r.getResponse().getStatus());
        return r.getResponse().getContentAsString(StandardCharsets.UTF_8);
    }

    private User user(String name, Role role) {
        User u = new User();
        u.setEmail(name.toLowerCase().replace(' ', '.') + "." + tag() + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName(name);
        u.setEmailVerified(true);
        u.setRole(role);
        return users.save(u);
    }

    private SupportTicket ticket(User owner, String subject, SupportTicket.Status st) {
        SupportTicket t = new SupportTicket();
        t.setUserId(owner.getId());
        t.setCategory(SupportTicket.Category.TECHNICAL);
        t.setSubject(subject);
        t.setStatus(st);
        t = tickets.save(t);
        SupportMessage m = new SupportMessage();
        m.setTicketId(t.getId());
        m.setAuthorId(owner.getId());
        m.setText("Musteri mesaji " + subject);
        messages.save(m);
        return t;
    }

    private SupportTicket publicTicket(String subject) {
        SupportTicket t = new SupportTicket();
        t.setPublicTicket(true);
        t.setEmailVerified(true);
        t.setContactEmail("misafir." + tag() + "@example.com");
        t.setContactName("Misafir");
        t.setCategory(SupportTicket.Category.OTHER);
        t.setSubject(subject);
        t = tickets.save(t);
        SupportMessage m = new SupportMessage();
        m.setTicketId(t.getId());
        m.setText("Misafir mesaji");
        messages.save(m);
        return t;
    }

    private Feedback fb(User u, String subject, boolean isPublic, int votes) {
        Feedback f = new Feedback();
        f.setUserId(u.getId());
        f.setCategory(Feedback.Category.SUGGESTION);
        f.setSubject(subject);
        f.setMessage("mesaj " + subject);
        f.setPublicVisible(isPublic);
        f.setVoteCount(votes);
        return feedback.save(f);
    }

    private void vote(Feedback f, User u) {
        jdbc.update("INSERT INTO feedback_vote (feedback_id, user_id) VALUES (?, ?)", f.getId(), u.getId());
    }

    private int voteRows(long feedbackId) {
        return jdbc.queryForObject("SELECT COUNT(*) FROM feedback_vote WHERE feedback_id = ?", Integer.class, feedbackId);
    }

    private static String reason(String r) {
        return "{\"reason\":\"" + r + "\"}";
    }

    // ---- yetki ----

    @Test
    void everyEndpointRejectsAnonymousAndPlainUsers() throws Exception {
        List<MockHttpServletRequestBuilder> reqs = List.of(
                post("/api/admin/support/tickets/1/reopen"),
                patch("/api/admin/support/tickets/1").contentType("application/json").content("{\"priority\":\"HIGH\"}"),
                post("/api/admin/support/tickets/1/notes").contentType("application/json").content("{\"text\":\"x\"}"),
                delete("/api/admin/support/tickets/1"),
                get("/api/admin/support/tickets/1"),
                get("/api/admin/support/tickets/export.csv"),
                get("/api/admin/support/feedback/export.csv"),
                delete("/api/admin/support/feedback/1"),
                post("/api/admin/support/feedback/merge").contentType("application/json")
                        .content("{\"sourceId\":1,\"targetId\":2,\"reason\":\"neden yok\"}"),
                put("/api/admin/faq/order").contentType("application/json").content("{\"ids\":[1]}"));
        for (MockHttpServletRequestBuilder b : reqs) {
            assertEquals(401, mvc.perform(b).andReturn().getResponse().getStatus(), b.toString());
        }
        for (MockHttpServletRequestBuilder b : reqs) {
            assertEquals(403, mvc.perform(b.with(authentication(asUser(990202L)))).andReturn().getResponse().getStatus(),
                    b.toString());
        }
    }

    // ---- ic not: musteriye GORUNMEZ (guvenlik) ----

    @Test
    void internalNoteIsVisibleToAdminButNeverToCustomerEndpoints() throws Exception {
        User owner = user("Musteri Bir", Role.USER);
        SupportTicket t = ticket(owner, "Not testi", SupportTicket.Status.OPEN);

        JsonNode created = json(run(post("/api/admin/support/tickets/" + t.getId() + "/notes")
                .contentType("application/json").content("{\"text\":\"" + SECRET + "1\"}")), 201);
        assertTrue(created.get("internal").asBoolean());
        assertEquals(ADMIN_ID, created.get("authorId").asLong());

        // yonetici: mesaj + ic not birlikte, internal ile ayrilir
        JsonNode adminView = json(run(get("/api/admin/support/tickets/" + t.getId())), 200);
        assertEquals(2, adminView.get("messages").size());
        int internalCount = 0;
        for (JsonNode m : adminView.get("messages")) {
            if (m.get("internal").asBoolean()) {
                internalCount++;
                assertEquals(SECRET + "1", m.get("text").asText());
            }
        }
        assertEquals(1, internalCount);
        assertEquals("NORMAL", adminView.get("priority").asText());
        assertTrue(adminView.get("assigneeId").isNull());

        // musteri: kendi talep ayrintisi
        MvcResult own = runAs(owner.getId(), get("/api/support/tickets/" + t.getId()));
        String ownBody = own.getResponse().getContentAsString();
        assertEquals(200, own.getResponse().getStatus(), ownBody);
        assertFalse(ownBody.contains(SECRET), "ic not musteri ayrintisinde gorunmemeli");
        assertFalse(ownBody.contains("internal"), "internal alani musteri yanitinda yok");
        assertFalse(ownBody.contains("priority") || ownBody.contains("assignee"), "oncelik/atama musteriye sizmaz");
        assertEquals(1, OM.readTree(ownBody).get("messages").size());

        // musteri: yanit yazinca donen ayrinti da temiz
        MvcResult reply = runAs(owner.getId(), post("/api/support/tickets/" + t.getId() + "/messages")
                .contentType("application/json").content("{\"text\":\"ek bilgi\"}"));
        assertEquals(200, reply.getResponse().getStatus());
        assertFalse(reply.getResponse().getContentAsString().contains(SECRET));
        // musteri: listesi
        String list = runAs(owner.getId(), get("/api/support/tickets")).getResponse().getContentAsString();
        assertFalse(list.contains(SECRET));
        // personel yaniti sonucu da (musteri gorunumu) ic not icermez
        String staff = run(post("/api/admin/support/tickets/" + t.getId() + "/reply").contentType("application/json")
                .content("{\"text\":\"Personel yaniti\"}")).getResponse().getContentAsString();
        assertFalse(staff.contains(SECRET));
        // bildirim/e-posta: ic not musteriye bildirim gondermez (yalniz personel yaniti bildirir)
        verify(notifications, never()).sendLocalized(any(), any(), anyString(), any(), eq(SECRET + "1"), any());
        assertEquals(1, notes.findByTicketIdOrderByIdAsc(t.getId()).size());
    }

    @Test
    void internalNoteIsInvisibleOnPublicTrackLink() throws Exception {
        SupportTicket t = publicTicket("Herkese acik not testi");
        String token = "tok-" + tag() + "-" + tag();
        SupportTrackToken row = new SupportTrackToken();
        row.setTicketId(t.getId());
        row.setTokenHash(Hashing.sha256(token));
        trackTokens.save(row);

        json(run(post("/api/admin/support/tickets/" + t.getId() + "/notes").contentType("application/json")
                .content("{\"text\":\"" + SECRET + "PUBLIC\"}")), 201);

        TicketDetail d = publicSupport.track(token, "127.0.0.1");
        assertEquals(1, d.messages().size());
        assertFalse(OM.writeValueAsString(d).contains(SECRET));
        // yonetici gorur
        assertEquals(2, json(run(get("/api/admin/support/tickets/" + t.getId())), 200).get("messages").size());
    }

    @Test
    void noteValidationAndMissingTicket() throws Exception {
        User owner = user("Not Dogrulama", Role.USER);
        SupportTicket t = ticket(owner, "Dogrulama", SupportTicket.Status.OPEN);
        assertEquals(400, run(post("/api/admin/support/tickets/" + t.getId() + "/notes").contentType("application/json")
                .content("{\"text\":\"  \"}")).getResponse().getStatus());
        assertEquals("TICKET_NOT_FOUND", code(run(post("/api/admin/support/tickets/987654321/notes")
                .contentType("application/json").content("{\"text\":\"x\"}"))));
        assertEquals(0, notes.findByTicketIdOrderByIdAsc(t.getId()).size());
    }

    // ---- yeniden ac ----

    @Test
    void reopenOnlyClosedTicketsAndNotifiesOwner() throws Exception {
        User owner = user("Yeniden Ac", Role.USER);
        SupportTicket closed = ticket(owner, "Kapali", SupportTicket.Status.CLOSED);
        closed.setClosedAt(java.time.Instant.now());
        tickets.save(closed);
        SupportTicket open = ticket(owner, "Acik", SupportTicket.Status.OPEN);

        JsonNode res = json(run(post("/api/admin/support/tickets/" + closed.getId() + "/reopen")), 200);
        assertEquals("OPEN", res.get("ticket").get("status").asText());
        SupportTicket saved = tickets.findById(closed.getId()).orElseThrow();
        assertEquals(SupportTicket.Status.OPEN, saved.getStatus());
        assertNull(saved.getClosedAt());
        verify(notifications).sendLocalized(eq(owner.getId()), eq(NotificationType.SYSTEM),
                eq("notif.ticket.reopened.title"), isNull(), eq("Kapali"), any());

        assertEquals("TICKET_NOT_CLOSED", code(run(post("/api/admin/support/tickets/" + open.getId() + "/reopen"))));
        assertEquals("TICKET_NOT_FOUND", code(run(post("/api/admin/support/tickets/987654321/reopen"))));
    }

    // ---- oncelik / atama ----

    @Test
    void patchPriorityCategoryAndAssignee() throws Exception {
        User owner = user("Atama Musteri", Role.USER);
        User staff = user("Atama Yonetici", Role.ADMIN);
        User plain = user("Atama Normal", Role.USER);
        SupportTicket t = ticket(owner, "Atama", SupportTicket.Status.OPEN);
        String url = "/api/admin/support/tickets/" + t.getId();

        JsonNode r = json(run(patch(url).contentType("application/json")
                .content("{\"priority\":\"URGENT\",\"category\":\"ACCOUNT\",\"assigneeId\":" + staff.getId() + "}")), 200);
        assertEquals("URGENT", r.get("priority").asText());
        assertEquals(staff.getId(), r.get("assigneeId").asLong());
        assertEquals("Atama Yonetici", r.get("assigneeName").asText());
        assertEquals("ACCOUNT", r.get("ticket").get("category").asText());

        // yonetici olmayana atanamaz; durum degismez
        assertEquals("ASSIGNEE_NOT_ADMIN", code(run(patch(url).contentType("application/json")
                .content("{\"assigneeId\":" + plain.getId() + "}"))));
        assertEquals(staff.getId(), tickets.findById(t.getId()).orElseThrow().getAssigneeId());
        assertEquals("USER_NOT_FOUND", code(run(patch(url).contentType("application/json").content("{\"assigneeId\":987654321}"))));
        // bos / celiskili istek
        assertEquals("TICKET_PATCH_EMPTY", code(run(patch(url).contentType("application/json").content("{}"))));
        assertEquals("TICKET_PATCH_EMPTY", code(run(patch(url).contentType("application/json")
                .content("{\"assigneeId\":" + staff.getId() + ",\"unassign\":true}"))));
        assertEquals(400, run(patch(url).contentType("application/json").content("{\"priority\":\"NOPE\"}"))
                .getResponse().getStatus());

        // kuyrukta gorunur
        JsonNode queue = json(run(get("/api/admin/support/tickets").param("size", "50")), 200);
        boolean found = false;
        for (JsonNode i : queue.get("items")) {
            if (i.get("id").asLong() == t.getId()) {
                found = true;
                assertEquals("URGENT", i.get("priority").asText());
                assertEquals(staff.getId(), i.get("assigneeId").asLong());
            }
        }
        assertTrue(found);

        // atamayi kaldir
        JsonNode un = json(run(patch(url).contentType("application/json").content("{\"unassign\":true}")), 200);
        assertTrue(un.get("assigneeId").isNull());
        assertNull(tickets.findById(t.getId()).orElseThrow().getAssigneeId());
    }

    // ---- silme ----

    @Test
    void deleteRemovesMessagesNotesAndTrackTokens() throws Exception {
        SupportTicket t = publicTicket("Silinecek");
        String token = "tok-" + tag() + "-" + tag();
        SupportTrackToken row = new SupportTrackToken();
        row.setTicketId(t.getId());
        row.setTokenHash(Hashing.sha256(token));
        trackTokens.save(row);
        json(run(post("/api/admin/support/tickets/" + t.getId() + "/notes").contentType("application/json")
                .content("{\"text\":\"not\"}")), 201);
        assertEquals(1, publicSupport.track(token, "127.0.0.1").messages().size(), "silmeden once baglanti calisir");

        assertEquals(204, run(delete("/api/admin/support/tickets/" + t.getId())
                .header("X-Admin-Reason", "Mukerrer talep silindi")).getResponse().getStatus());

        assertTrue(tickets.findById(t.getId()).isEmpty());
        assertTrue(messages.findByTicketIdOrderByIdAsc(t.getId()).isEmpty());
        assertTrue(notes.findByTicketIdOrderByIdAsc(t.getId()).isEmpty());
        assertTrue(trackTokens.findByTokenHash(Hashing.sha256(token)).isEmpty(), "durum baglantisi temizlendi");
        ApiException e = assertThrows(ApiException.class, () -> publicSupport.track(token, "127.0.0.1"));
        assertEquals("TICKET_NOT_FOUND", e.code());
        assertEquals("TICKET_NOT_FOUND", code(run(delete("/api/admin/support/tickets/" + t.getId()))));
    }

    // ---- geri bildirim ----

    @Test
    void feedbackDeleteRemovesVotes() throws Exception {
        User a = user("Oy Bir", Role.USER);
        Feedback f = fb(a, "Silinecek oneri", true, 1);
        vote(f, a);
        assertEquals(204, run(delete("/api/admin/support/feedback/" + f.getId())
                .header("X-Admin-Reason", "Uygunsuz oneri")).getResponse().getStatus());
        assertTrue(feedback.findById(f.getId()).isEmpty());
        assertEquals(0, voteRows(f.getId()));
        assertEquals("FEEDBACK_NOT_FOUND", code(run(delete("/api/admin/support/feedback/" + f.getId()))));
    }

    @Test
    void feedbackMergeMovesVotesWithoutDoubleCountingAndDeletesSource() throws Exception {
        User a = user("Birlestir A", Role.USER);
        User b = user("Birlestir B", Role.USER);
        User c = user("Birlestir C", Role.USER);
        Feedback source = fb(a, "Kaynak oneri", true, 2);
        Feedback target = fb(b, "Hedef oneri", true, 2);
        vote(source, a);
        vote(source, b); // b zaten hedefe de oy verdi
        vote(target, b);
        vote(target, c);

        JsonNode res = json(run(post("/api/admin/support/feedback/merge").contentType("application/json")
                .content("{\"sourceId\":" + source.getId() + ",\"targetId\":" + target.getId()
                        + ",\"reason\":\"Ayni oneri tekrar edilmis\"}")), 200);
        assertEquals(3, res.get("voteCount").asInt(), "a, b, c: cift oy sayilmadi");
        assertEquals(3, feedback.findById(target.getId()).orElseThrow().getVoteCount());
        assertEquals(3, voteRows(target.getId()));
        assertTrue(feedback.findById(source.getId()).isEmpty());
        assertEquals(0, voteRows(source.getId()));
        verify(notifications).sendLocalized(eq(a.getId()), eq(NotificationType.SYSTEM), eq("notif.feedback.merged.title"),
                isNull(), eq("Hedef oneri"), any());
    }

    @Test
    void feedbackMergeGuards() throws Exception {
        User a = user("Koruma A", Role.USER);
        Feedback pub = fb(a, "Acik oneri", true, 1);
        Feedback priv = fb(a, "Gizli oneri", false, 0);
        String url = "/api/admin/support/feedback/merge";
        String ok = ",\"reason\":\"yeterince uzun\"}";
        assertEquals("FEEDBACK_MERGE_SAME", code(run(post(url).contentType("application/json")
                .content("{\"sourceId\":" + pub.getId() + ",\"targetId\":" + pub.getId() + ok))));
        assertEquals("FEEDBACK_MERGE_TARGET_NOT_PUBLIC", code(run(post(url).contentType("application/json")
                .content("{\"sourceId\":" + pub.getId() + ",\"targetId\":" + priv.getId() + ok))));
        assertEquals("FEEDBACK_NOT_FOUND", code(run(post(url).contentType("application/json")
                .content("{\"sourceId\":" + pub.getId() + ",\"targetId\":987654321" + ok))));
        assertEquals(400, run(post(url).contentType("application/json")
                .content("{\"sourceId\":" + pub.getId() + ",\"targetId\":" + priv.getId() + ",\"reason\":\"kisa\"}"))
                .getResponse().getStatus());
        assertTrue(feedback.findById(pub.getId()).isPresent(), "hatali birlestirme kaynagi silmez");
        // oyu olmayan kaynak, herkese acik olmayan hedefle birlestirilebilir
        Feedback quiet = fb(a, "Oysuz oneri", false, 0);
        json(run(post(url).contentType("application/json")
                .content("{\"sourceId\":" + quiet.getId() + ",\"targetId\":" + priv.getId() + ok)), 200);
        assertTrue(feedback.findById(quiet.getId()).isEmpty());
    }

    // ---- SSS siralama ----

    private FaqItem faqItem(String lang, String cat, String q, int order) {
        FaqItem f = new FaqItem();
        f.setLang(lang);
        f.setCategory(cat);
        f.setQuestion(q);
        f.setAnswer("cevap " + q);
        f.setSortOrder(order);
        return faq.save(f);
    }

    @Test
    void faqOrderAssignsPositionsAndRejectsMixedOrDuplicateOrUnknown() throws Exception {
        String cat = "SIRA" + tag();
        FaqItem a = faqItem("tr", cat, "A sorusu", 0);
        FaqItem b = faqItem("tr", cat, "B sorusu", 0);
        FaqItem c = faqItem("tr", cat, "C sorusu", 0);
        FaqItem other = faqItem("tr", cat + "X", "Baska kategori", 0);
        FaqItem otherLang = faqItem("en", cat, "Other language", 0);

        JsonNode res = json(run(put("/api/admin/faq/order").contentType("application/json")
                .content("{\"ids\":[" + c.getId() + "," + a.getId() + "," + b.getId() + "]}")), 200);
        assertEquals(c.getId(), res.get(0).get("id").asLong());
        assertEquals(10, faq.findById(c.getId()).orElseThrow().getSortOrder());
        assertEquals(20, faq.findById(a.getId()).orElseThrow().getSortOrder());
        assertEquals(30, faq.findById(b.getId()).orElseThrow().getSortOrder());

        assertEquals("FAQ_ORDER_INVALID", code(run(put("/api/admin/faq/order").contentType("application/json")
                .content("{\"ids\":[" + a.getId() + "," + other.getId() + "]}"))));
        assertEquals("FAQ_ORDER_INVALID", code(run(put("/api/admin/faq/order").contentType("application/json")
                .content("{\"ids\":[" + a.getId() + "," + otherLang.getId() + "]}"))));
        assertEquals("FAQ_ORDER_INVALID", code(run(put("/api/admin/faq/order").contentType("application/json")
                .content("{\"ids\":[" + a.getId() + "," + a.getId() + "]}"))));
        assertEquals("FAQ_NOT_FOUND", code(run(put("/api/admin/faq/order").contentType("application/json")
                .content("{\"ids\":[" + a.getId() + ",987654321]}"))));
        assertEquals(400, run(put("/api/admin/faq/order").contentType("application/json").content("{\"ids\":[]}"))
                .getResponse().getStatus());
        assertEquals(20, faq.findById(a.getId()).orElseThrow().getSortOrder(), "hatali istek sirayi bozmaz");
    }

    // ---- CSV ----

    @Test
    void ticketCsvEscapesFormulasExcludesNotesAndFilters() throws Exception {
        User owner = user("Csv Musteri", Role.USER);
        SupportTicket t = ticket(owner, "=cmd|' /C calc'!A0", SupportTicket.Status.ANSWERED);
        t.setPriority(SupportTicket.Priority.HIGH);
        tickets.save(t);
        json(run(post("/api/admin/support/tickets/" + t.getId() + "/notes").contentType("application/json")
                .content("{\"text\":\"" + SECRET + "CSV\"}")), 201);
        SupportTicket other = ticket(owner, "Baska talep", SupportTicket.Status.OPEN);

        String all = csv(run(get("/api/admin/support/tickets/export.csv")));
        assertTrue(all.startsWith("﻿id,durum,kategori,oncelik"));
        assertTrue(all.contains("'=cmd|' /C calc'!A0"), "formul oneki kacirildi: " + all);
        assertFalse(all.contains(SECRET), "ic notlar disa aktarilmaz");
        assertFalse(all.contains("Musteri mesaji"), "mesaj govdeleri disa aktarilmaz");
        assertTrue(all.contains("Baska talep"));

        String high = csv(run(get("/api/admin/support/tickets/export.csv").param("priority", "HIGH")
                .param("status", "ANSWERED")));
        assertTrue(high.contains("calc"));
        assertFalse(high.contains("Baska talep"));
        String none = csv(run(get("/api/admin/support/tickets/export.csv").param("from", "2999-01-01")));
        assertEquals(1, none.split("\r\n").length);
        assertNotNull(other.getId());
    }

    @Test
    void feedbackCsvEscapesFormulasAndFilters() throws Exception {
        User a = user("Csv Geri", Role.USER);
        Feedback f = fb(a, "@SUM(A1)", true, 3);
        Feedback g = fb(a, "Normal konu", false, 0);
        g.setStatus(Feedback.Status.DONE);
        feedback.save(g);

        String all = csv(run(get("/api/admin/support/feedback/export.csv")));
        assertTrue(all.startsWith("﻿id,kategori,durum,konu"));
        assertTrue(all.contains("'@SUM(A1)"), "formul oneki kacirildi");
        String done = csv(run(get("/api/admin/support/feedback/export.csv").param("status", "DONE")));
        assertTrue(done.contains("Normal konu"));
        assertFalse(done.contains("SUM(A1)"));
        assertNotNull(f.getId());
    }
}
