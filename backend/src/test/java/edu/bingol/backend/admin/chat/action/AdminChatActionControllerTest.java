package edu.bingol.backend.admin.chat.action;

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
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.messaging.Conversation;
import edu.bingol.backend.messaging.ConversationMember;
import edu.bingol.backend.messaging.ConversationMemberRepository;
import edu.bingol.backend.messaging.ConversationRepository;
import edu.bingol.backend.messaging.Message;
import edu.bingol.backend.messaging.MessageRepository;
import edu.bingol.backend.messaging.dto.MessagingDtos;
import edu.bingol.backend.messaging.ws.ChatEventBus;
import edu.bingol.backend.notification.NotificationService;
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
 * Yonetici sohbet mudahalesi HTTP sozlesmesi (P08, H2): yalniz ADMIN (diger 403, giris yok 401), gizle/geri goster
 * (entity eslemesi + kullanici yer tutucusu), sohbet kapatma, birebirde uye cikarma reddi, ust veri, disa aktarma ikinci onayi.
 * PostgreSQL'e ozel / H2'de tablosu olmayan yollar (kalici silme, denetim tablosu) servis testlerindedir.
 */
@SpringBootTest
class AdminChatActionControllerTest {

    private static final ObjectMapper OM = new ObjectMapper();
    private static final long ADMIN_ID = 990101L;
    private static final String REASON = "kural ihlali nedeniyle";
    private static final String LONG_REASON = "mahkeme karari geregi yasal talep dosyasi 2026/15";

    @Autowired WebApplicationContext ctx;
    @Autowired UserRepository users;
    @Autowired ConversationRepository convs;
    @Autowired ConversationMemberRepository members;
    @Autowired MessageRepository messages;
    @MockitoBean RateLimiter limiter;
    @MockitoBean ChatEventBus bus;
    @MockitoBean NotificationService notifications;
    MockMvc mvc;

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.webAppContextSetup(ctx).addFilters(ctx.getBean(AdminReasonFilter.class))
                .apply(springSecurity()).build();
    }

    private static UsernamePasswordAuthenticationToken admin() {
        return new UsernamePasswordAuthenticationToken(ADMIN_ID, null, List.of(new SimpleGrantedAuthority("ROLE_ADMIN")));
    }

    private static UsernamePasswordAuthenticationToken plainUser() {
        return new UsernamePasswordAuthenticationToken(990102L, null, List.of(new SimpleGrantedAuthority("ROLE_USER")));
    }

    private MvcResult asAdmin(MockHttpServletRequestBuilder b) throws Exception {
        return mvc.perform(b.with(authentication(admin())).header("X-Admin-Reason", REASON)).andReturn();
    }

    private static JsonNode json(MvcResult r, int status) throws Exception {
        MockHttpServletResponse res = r.getResponse();
        assertEquals(status, res.getStatus(), res.getContentAsString());
        String body = res.getContentAsString();
        return body.isEmpty() ? null : OM.readTree(body);
    }

    private User user(String name) {
        User u = new User();
        u.setEmail(name.toLowerCase() + "." + UUID.randomUUID().toString().substring(0, 8) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName(name);
        u.setEmailVerified(true);
        return users.save(u);
    }

    private Conversation conversation(Conversation.Type type, User... who) {
        Conversation c = new Conversation();
        c.setType(type);
        c.setCreatedBy(who[0].getId());
        if (type == Conversation.Type.GROUP) {
            c.setTitle("Test grubu");
        } else {
            c.setDirectKey(Conversation.directKey(who[0].getId(), who[1].getId()));
        }
        c = convs.save(c);
        for (User u : who) {
            members.save(ConversationMember.of(c.getId(), u.getId(), ConversationMember.Role.MEMBER));
        }
        return c;
    }

    private Message message(Conversation c, User sender) {
        Message m = new Message();
        m.setConversationId(c.getId());
        m.setSenderId(sender.getId());
        m.setClientId(UUID.randomUUID().toString());
        m.setBodyCiphertext(new byte[] {1, 2, 3});
        m.setBodyNonce(new byte[] {4, 5, 6});
        m.setKeyVersion(1);
        return messages.save(m);
    }

    // ---- yetki ----

    @Test
    void onlyAdminsMayIntervene() throws Exception {
        List<MockHttpServletRequestBuilder> all = List.of(post("/api/admin/messages/1/hide"),
                post("/api/admin/messages/1/unhide"), delete("/api/admin/messages/1"),
                post("/api/admin/messages/bulk-hide").contentType("application/json").content("{\"ids\":[1]}"),
                post("/api/admin/conversations/1/close"), post("/api/admin/conversations/1/reopen"),
                delete("/api/admin/conversations/1/members/2"), get("/api/admin/conversations/1"),
                get("/api/admin/conversations/1/export"));
        for (MockHttpServletRequestBuilder b : all) {
            assertEquals(403, mvc.perform(b.with(authentication(plainUser()))).andReturn().getResponse().getStatus());
        }
        assertEquals(401, mvc.perform(post("/api/admin/messages/1/hide")).andReturn().getResponse().getStatus());
        assertEquals(401, mvc.perform(get("/api/admin/conversations/1")).andReturn().getResponse().getStatus());
    }

    // ---- mesaj ----

    @Test
    void hideThenUnhideRoundTripShowsAdminPlaceholderToUsers() throws Exception {
        User a = user("Ayse");
        User b = user("Berk");
        Conversation c = conversation(Conversation.Type.DIRECT, a, b);
        Message m = message(c, a);

        JsonNode hidden = json(asAdmin(post("/api/admin/messages/" + m.getId() + "/hide")), 200);
        assertEquals("HIDDEN", hidden.get("state").asText());
        Message after = messages.findById(m.getId()).orElseThrow();
        assertTrue(after.isAdminRemoved());
        assertTrue(after.isHidden());
        assertNotNull(after.getBodyCiphertext()); // icerik silinmez
        assertEquals(MessagingDtos.ADMIN_REMOVED_TEXT, MessagingDtos.MessageView.of(after).text());
        assertEquals("MESSAGE_ALREADY_HIDDEN",
                json(asAdmin(post("/api/admin/messages/" + m.getId() + "/hide")), 409).get("code").asText());

        JsonNode visible = json(asAdmin(post("/api/admin/messages/" + m.getId() + "/unhide")), 200);
        assertEquals("VISIBLE", visible.get("state").asText());
        Message restored = messages.findById(m.getId()).orElseThrow();
        assertFalse(restored.isHidden());
        assertNull(restored.getAdminHiddenAt());
    }

    @Test
    void hideBodyReasonIsAcceptedInsteadOfHeader() throws Exception {
        User a = user("Ceren");
        User b = user("Deniz");
        Message m = message(conversation(Conversation.Type.DIRECT, a, b), a);

        MvcResult r = mvc.perform(post("/api/admin/messages/" + m.getId() + "/hide").with(authentication(admin()))
                .contentType("application/json").content("{\"reason\":\"" + REASON + "\"}")).andReturn();

        assertEquals("HIDDEN", json(r, 200).get("state").asText());
    }

    @Test
    void bulkHideReturnsPartialResult() throws Exception {
        User a = user("Ece");
        User b = user("Fatih");
        Message m = message(conversation(Conversation.Type.DIRECT, a, b), a);

        MvcResult r = mvc.perform(post("/api/admin/messages/bulk-hide").with(authentication(admin()))
                .contentType("application/json").content("{\"ids\":[" + m.getId() + ",987654321],\"reason\":\"" + REASON + "\"}"))
                .andReturn();

        JsonNode out = json(r, 200);
        assertEquals(2, out.get("requested").asInt());
        assertEquals(1, out.get("done").asInt());
        assertEquals("MESSAGE_NOT_FOUND", out.get("items").get(1).get("error").asText());
    }

    // ---- sohbet ----

    @Test
    void closeSetsClosedFlagAndReopenClearsIt() throws Exception {
        User a = user("Gul");
        User b = user("Hakan");
        Conversation c = conversation(Conversation.Type.GROUP, a, b);

        JsonNode closed = json(asAdmin(post("/api/admin/conversations/" + c.getId() + "/close")), 200);
        assertTrue(closed.get("closed").asBoolean());
        Conversation after = convs.findById(c.getId()).orElseThrow();
        assertTrue(after.isClosed());
        assertEquals(Long.valueOf(ADMIN_ID), after.getClosedBy());
        assertEquals(REASON, after.getClosedReason());
        assertEquals("CONVERSATION_ALREADY_CLOSED",
                json(asAdmin(post("/api/admin/conversations/" + c.getId() + "/close")), 409).get("code").asText());

        json(asAdmin(post("/api/admin/conversations/" + c.getId() + "/reopen")), 200);
        assertFalse(convs.findById(c.getId()).orElseThrow().isClosed());
    }

    @Test
    void removeMemberFromGroupWorksButDirectIsRefused() throws Exception {
        User a = user("Ilke");
        User b = user("Jale");
        User d = user("Kaan");
        Conversation group = conversation(Conversation.Type.GROUP, a, b, d);
        Conversation direct = conversation(Conversation.Type.DIRECT, a, b);

        assertEquals("NOT_A_GROUP", json(asAdmin(delete("/api/admin/conversations/" + direct.getId() + "/members/" + b.getId())),
                400).get("code").asText());
        json(asAdmin(delete("/api/admin/conversations/" + group.getId() + "/members/" + d.getId())), 200);

        assertNotNull(members.findByConversationIdAndUserId(group.getId(), d.getId()).orElseThrow().getLeftAt());
        assertNull(members.findByConversationIdAndUserId(group.getId(), b.getId()).orElseThrow().getLeftAt());
    }

    @Test
    void metaHasMembersWithMaskedEmailAndNoContent() throws Exception {
        User a = user("Lale");
        User b = user("Mert");
        Conversation c = conversation(Conversation.Type.DIRECT, a, b);
        message(c, a);

        JsonNode meta = json(mvc.perform(get("/api/admin/conversations/" + c.getId()).with(authentication(admin())))
                .andReturn(), 200);

        assertEquals("DIRECT", meta.get("kind").asText());
        assertEquals(1, meta.get("messageCount").asLong());
        assertEquals(2, meta.get("members").size());
        assertTrue(meta.get("members").get(0).get("email").asText().matches("^.\\*\\*\\*@bingol\\.edu\\.tr$"));
        assertFalse(meta.toString().contains("text"));
        assertEquals("CONVERSATION_NOT_FOUND", json(mvc.perform(get("/api/admin/conversations/987654321")
                .with(authentication(admin()))).andReturn(), 404).get("code").asText());
    }

    // ---- disa aktarma ----

    @Test
    void exportNeedsSecondConfirmationAndLongReason() throws Exception {
        User a = user("Nur");
        User b = user("Okan");
        Conversation c = conversation(Conversation.Type.DIRECT, a, b);
        String url = "/api/admin/conversations/" + c.getId() + "/export";

        // sebep kisa (AdminReasonRequired min=20 uygulanmaz: testte require-reason kapali; servis yine reddeder)
        MvcResult shortReason = mvc.perform(get(url).with(authentication(admin())).header("X-Admin-Reason", "kisa sebep")
                .header("X-Admin-Confirm", String.valueOf(c.getId()))).andReturn();
        assertEquals("REASON_REQUIRED", json(shortReason, 400).get("code").asText());

        MvcResult noConfirm = mvc.perform(get(url).with(authentication(admin())).header("X-Admin-Reason", LONG_REASON))
                .andReturn();
        assertEquals("EXPORT_CONFIRM_REQUIRED", json(noConfirm, 400).get("code").asText());

        MvcResult wrongConfirm = mvc.perform(get(url).with(authentication(admin())).header("X-Admin-Reason", LONG_REASON)
                .header("X-Admin-Confirm", "1" + c.getId())).andReturn();
        assertEquals("EXPORT_CONFIRM_REQUIRED", json(wrongConfirm, 400).get("code").asText());
    }
}
