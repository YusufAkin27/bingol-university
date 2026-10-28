package edu.bingol.backend.event.admin;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.event.EventRsvp;
import edu.bingol.backend.event.EventRsvpRepository;
import edu.bingol.backend.event.UserEvent;
import edu.bingol.backend.event.UserEventRepository;
import edu.bingol.backend.event.admission.EventAdmission;
import edu.bingol.backend.event.admission.EventAdmissionRepository;
import edu.bingol.backend.event.admission.EventApplication;
import edu.bingol.backend.event.admission.EventApplicationRepository;
import edu.bingol.backend.event.chat.EventChatService;
import edu.bingol.backend.event.extras.EventFeedback;
import edu.bingol.backend.messaging.room.RoomConversations;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
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
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

/** P07 HTTP sozlesmesi: yetki, yonlendirme (export.csv /{id} ile karismaz), anonimlik, Basic auth korumasi, toplu islem. */
@SpringBootTest
class EventAdminOpsControllerTest {

    private static final ObjectMapper OM = new ObjectMapper();

    @Autowired WebApplicationContext ctx;
    @Autowired UserEventRepository events;
    @Autowired UserRepository users;
    @Autowired EventRsvpRepository rsvps;
    @Autowired EventAdmissionRepository admissions;
    @Autowired EventApplicationRepository applications;
    @Autowired AdminFeedbackLookupRepository feedbackRepo;

    /** Testlerde Redis yok: hiz siniri sahte. */
    @MockitoBean RateLimiter limiter;
    @MockitoBean NotificationService notifications;
    @MockitoBean RoomConversations rooms;
    @MockitoBean EventChatService chat;
    MockMvc mvc;

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.webAppContextSetup(ctx).apply(springSecurity()).build();
    }

    private static UsernamePasswordAuthenticationToken admin() {
        return new UsernamePasswordAuthenticationToken(990001L, null, List.of(new SimpleGrantedAuthority("ROLE_ADMIN")));
    }

    /** Basic auth yoneticisi: principal Long degil (kullanici kaydi yok). */
    private static UsernamePasswordAuthenticationToken basicAdmin() {
        return new UsernamePasswordAuthenticationToken("admin", null, List.of(new SimpleGrantedAuthority("ROLE_ADMIN")));
    }

    private static UsernamePasswordAuthenticationToken plainUser() {
        return new UsernamePasswordAuthenticationToken(990002L, null, List.of(new SimpleGrantedAuthority("ROLE_USER")));
    }

    private MockHttpServletResponse call(MockHttpServletRequestBuilder b) throws Exception {
        return mvc.perform(b.with(authentication(admin()))).andReturn().getResponse();
    }

    private User user(String name) {
        User u = new User();
        u.setEmail("h" + UUID.randomUUID().toString().substring(0, 8) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName(name);
        u.setEmailVerified(true);
        return users.saveAndFlush(u);
    }

    private UserEvent event(User owner, Integer capacity, boolean approval) {
        UserEvent e = new UserEvent();
        e.setTitle("Http etkinlik " + UUID.randomUUID().toString().substring(0, 6));
        e.setStartsAt(Instant.now().minus(Duration.ofMinutes(5)));
        e.setEndsAt(Instant.now().plus(Duration.ofHours(2)));
        e.setCreatedBy(owner.getId());
        e.setStatus(UserEvent.Status.ACTIVE);
        e.setCapacity(capacity);
        UserEvent saved = events.saveAndFlush(e);
        if (approval) {
            EventAdmission cfg = new EventAdmission(saved.getId());
            cfg.setMode(EventAdmission.Mode.APPROVAL);
            admissions.saveAndFlush(cfg);
        }
        return saved;
    }

    private static final List<String[]> WRITES = List.of(
            new String[] {"POST", "/applications/1/accept"}, new String[] {"POST", "/applications/1/reject"},
            new String[] {"PUT", "/attendance/1"}, new String[] {"POST", "/certificates/1/revoke"},
            new String[] {"POST", "/certificates/1/restore"}, new String[] {"DELETE", "/feedback/1"},
            new String[] {"DELETE", "/announcements/1"}, new String[] {"DELETE", "/organizers/1"});
    private static final List<String> READS = List.of("/applications", "/attendance", "/certificates", "/feedback",
            "/announcements", "/organizers", "/attendance.csv", "/applications.csv");

    private static MockHttpServletRequestBuilder req(String method, String path) {
        return switch (method) {
            case "POST" -> post(path).contentType("application/json").content("{\"reason\":\"deneme sebebi\"}");
            case "PUT" -> put(path).contentType("application/json").content("{\"present\":true,\"reason\":\"deneme sebebi\"}");
            default -> delete(path).header("X-Admin-Reason", "deneme sebebi");
        };
    }

    @Test
    void everyNewEndpointRejectsAnonymousAndPlainUsers() throws Exception {
        for (String r : READS) {
            String path = "/api/admin/events/1" + r;
            assertEquals(401, mvc.perform(get(path)).andReturn().getResponse().getStatus(), path);
            assertEquals(403, mvc.perform(get(path).with(authentication(plainUser()))).andReturn().getResponse().getStatus(), path);
        }
        for (String path : List.of("/api/admin/events/export.csv")) {
            assertEquals(401, mvc.perform(get(path)).andReturn().getResponse().getStatus(), path);
            assertEquals(403, mvc.perform(get(path).with(authentication(plainUser()))).andReturn().getResponse().getStatus(), path);
        }
        for (String[] w : WRITES) {
            String path = "/api/admin/events/1" + w[1];
            assertEquals(401, mvc.perform(req(w[0], path)).andReturn().getResponse().getStatus(), w[0] + " " + path);
            assertEquals(403, mvc.perform(req(w[0], path).with(authentication(plainUser()))).andReturn().getResponse().getStatus(),
                    w[0] + " " + path);
        }
        assertEquals(401, mvc.perform(post("/api/admin/events/bulk").contentType("application/json")
                .content("{\"action\":\"HIDE\",\"ids\":[1],\"reason\":\"deneme sebebi\"}")).andReturn().getResponse().getStatus());
        assertEquals(403, mvc.perform(post("/api/admin/events/bulk").with(authentication(plainUser()))
                .contentType("application/json").content("{\"action\":\"HIDE\",\"ids\":[1],\"reason\":\"deneme sebebi\"}"))
                .andReturn().getResponse().getStatus());
    }

    @Test
    void unknownEventIs404WithJsonErrorEvenOnCsv() throws Exception {
        for (String r : READS) {
            MockHttpServletResponse res = call(get("/api/admin/events/987654321" + r));
            assertEquals(404, res.getStatus(), r);
            assertTrue(res.getContentType() == null || res.getContentType().contains("json"), r + " -> " + res.getContentType());
        }
    }

    @Test
    void applicationsEndpointReturnsMaskedRowsAndSummary() throws Exception {
        User owner = user("Sahip");
        User a = user("Ayse");
        UserEvent e = event(owner, 3, true);
        applications.saveAndFlush(new EventApplication(e.getId(), a.getId()));

        MockHttpServletResponse res = call(get("/api/admin/events/" + e.getId() + "/applications?status=PENDING"));
        assertEquals(200, res.getStatus(), res.getContentAsString());
        JsonNode j = OM.readTree(res.getContentAsString());
        assertEquals(1, j.get("items").size());
        assertTrue(j.get("items").get(0).get("emailMasked").asText().contains("***"));
        assertFalse(res.getContentAsString().contains(a.getEmail()), "tam e-posta donmemeli");
        assertEquals(3, j.get("summary").get("capacity").asInt());
        assertEquals("APPROVAL", j.get("summary").get("mode").asText());

        // zorla kabul (JWT yonetici): 200 + yeni durum
        MockHttpServletResponse acc = call(post("/api/admin/events/" + e.getId() + "/applications/" + a.getId() + "/accept")
                .contentType("application/json").content("{\"reason\":\"yonetici karari\"}"));
        assertEquals(200, acc.getStatus(), acc.getContentAsString());
        assertEquals("ACCEPTED", OM.readTree(acc.getContentAsString()).get("status").asText());
        assertEquals(1, OM.readTree(acc.getContentAsString()).get("summary").get("goingCount").asInt());
    }

    @Test
    void forcedAcceptOnFullEventIs409AndBasicAdminCannotWrite() throws Exception {
        User owner = user("Sahip");
        User a = user("Ayse");
        User b = user("Berk");
        UserEvent e = event(owner, 1, true);
        applications.saveAndFlush(new EventApplication(e.getId(), a.getId()));
        applications.saveAndFlush(new EventApplication(e.getId(), b.getId()));
        String base = "/api/admin/events/" + e.getId() + "/applications/";
        assertEquals(200, call(post(base + a.getId() + "/accept").contentType("application/json").content("{}")).getStatus());
        MockHttpServletResponse full = call(post(base + b.getId() + "/accept").contentType("application/json").content("{}"));
        assertEquals(409, full.getStatus());
        assertEquals("EVENT_FULL", OM.readTree(full.getContentAsString()).get("code").asText());

        MockHttpServletResponse basic = mvc.perform(post(base + b.getId() + "/reject").with(authentication(basicAdmin()))
                .contentType("application/json").content("{}")).andReturn().getResponse();
        assertEquals(403, basic.getStatus());
        assertEquals("EVENT_ADMIN_ACCOUNT_REQUIRED", OM.readTree(basic.getContentAsString()).get("code").asText());
        // Basic auth yonetici OKUYABILIR
        assertEquals(200, mvc.perform(get("/api/admin/events/" + e.getId() + "/applications").with(authentication(basicAdmin())))
                .andReturn().getResponse().getStatus());
    }

    @Test
    void feedbackJsonNeverContainsAuthorIdentity() throws Exception {
        User owner = user("Sahip");
        User writer = user("Yazan");
        UserEvent e = event(owner, null, false);
        EventFeedback f = new EventFeedback();
        f.setEventId(e.getId());
        f.setUserId(writer.getId());
        f.setRating((short) 5);
        f.setComment("Super");
        feedbackRepo.saveAndFlush(f);

        MockHttpServletResponse res = call(get("/api/admin/events/" + e.getId() + "/feedback"));
        assertEquals(200, res.getStatus());
        String body = res.getContentAsString();
        assertTrue(body.contains("\"comment\":\"Super\""), body);
        assertFalse(body.contains("userId"), body);
        assertFalse(body.contains(writer.getEmail()), body);
        assertFalse(body.contains("Yazan"), body);

        assertEquals(204, call(delete("/api/admin/events/" + e.getId() + "/feedback/" + f.getId())
                .header("X-Admin-Reason", "uygunsuz yorum")).getStatus());
        assertEquals(404, call(delete("/api/admin/events/" + e.getId() + "/feedback/" + f.getId())).getStatus());
    }

    @Test
    void csvRoutesAreNotCapturedByIdPathAndAreMaskedBomFiles() throws Exception {
        User owner = user("Sahip");
        User guest = user("Misafir");
        UserEvent e = event(owner, null, false);
        rsvps.saveAndFlush(new EventRsvp(e.getId(), guest.getId(), EventRsvp.Status.GOING));

        MockHttpServletResponse att = call(get("/api/admin/events/" + e.getId() + "/attendance.csv"));
        assertEquals(200, att.getStatus());
        assertTrue(att.getContentType().startsWith("text/csv"));
        assertTrue(att.getHeader("Content-Disposition").contains("event-" + e.getId() + "-attendance.csv"));
        String attBody = att.getContentAsString(StandardCharsets.UTF_8);
        assertTrue(attBody.startsWith("﻿userId,name,emailMasked"), attBody);
        assertFalse(attBody.contains(guest.getEmail()));

        MockHttpServletResponse all = call(get("/api/admin/events/export.csv?status=ACTIVE"));
        assertEquals(200, all.getStatus(), all.getContentAsString());
        assertTrue(all.getContentType().startsWith("text/csv"));
        String allBody = all.getContentAsString(StandardCharsets.UTF_8);
        assertTrue(allBody.startsWith("﻿id,title,status"), allBody);
        assertTrue(allBody.contains(e.getTitle()));
        assertFalse(allBody.contains(owner.getEmail()));
        // /{id} yolu etkilenmez
        assertEquals(200, call(get("/api/admin/events/" + e.getId())).getStatus());
    }

    @Test
    void bulkEndpointReportsPartialSuccessAndEnforcesLimit() throws Exception {
        User owner = user("Sahip");
        UserEvent a = event(owner, null, false);
        String ok = "{\"action\":\"HIDE\",\"ids\":[" + a.getId() + ",987654321],\"reason\":\"toplu inceleme\"}";
        MockHttpServletResponse res = call(post("/api/admin/events/bulk").contentType("application/json").content(ok));
        assertEquals(200, res.getStatus(), res.getContentAsString());
        JsonNode j = OM.readTree(res.getContentAsString());
        assertEquals(2, j.get("requested").asInt());
        assertEquals(1, j.get("done").asInt());
        assertEquals(1, j.get("failed").asInt());
        assertEquals("EVENT_NOT_FOUND", j.get("items").get(1).get("error").asText());
        assertEquals(UserEvent.Status.HIDDEN, events.findById(a.getId()).orElseThrow().getStatus());

        StringBuilder ids = new StringBuilder();
        for (int i = 0; i < 101; i++) {
            ids.append(i == 0 ? "" : ",").append(900_000_000L + i);
        }
        MockHttpServletResponse big = call(post("/api/admin/events/bulk").contentType("application/json")
                .content("{\"action\":\"CANCEL\",\"ids\":[" + ids + "],\"reason\":\"toplu inceleme\"}"));
        assertEquals(400, big.getStatus());
        assertEquals("EVENT_BULK_LIMIT", OM.readTree(big.getContentAsString()).get("code").asText());
        assertEquals(400, call(post("/api/admin/events/bulk").contentType("application/json")
                .content("{\"action\":\"BOGUS\",\"ids\":[1],\"reason\":\"x\"}")).getStatus());
        assertEquals(400, call(post("/api/admin/events/bulk").contentType("application/json")
                .content("{\"action\":\"HIDE\",\"ids\":[],\"reason\":\"toplu inceleme\"}")).getStatus());
    }

    @Test
    void ownerRemovalIs409AndOrganizersListIsMasked() throws Exception {
        User owner = user("Sahip");
        UserEvent e = event(owner, null, false);
        MockHttpServletResponse list = call(get("/api/admin/events/" + e.getId() + "/organizers"));
        assertEquals(200, list.getStatus());
        assertEquals("OWNER", OM.readTree(list.getContentAsString()).get(0).get("role").asText());
        assertFalse(list.getContentAsString().contains(owner.getEmail()));
        MockHttpServletResponse del = call(delete("/api/admin/events/" + e.getId() + "/organizers/" + owner.getId())
                .header("X-Admin-Reason", "deneme sebebi"));
        assertEquals(409, del.getStatus());
        assertEquals("EVENT_OWNER_PROTECTED", OM.readTree(del.getContentAsString()).get("code").asText());
    }
}
