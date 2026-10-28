package edu.bingol.backend.admin.rbac;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.httpBasic;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

/** Izin matrisi HTTP sozlesmesi (P16, H2): 403 ADMIN_PERMISSION_DENIED, profil atama, iki kisi onayi, Basic auth FULL. */
@SpringBootTest(properties = "app.admin.emails=pinli.rbac@bingol.edu.tr")
class RbacMvcTest {

    private static final ObjectMapper OM = new ObjectMapper();

    @Autowired WebApplicationContext ctx;
    @Autowired UserRepository users;
    @MockitoBean RateLimiter limiter;
    @MockitoBean StringRedisTemplate redis;
    MockMvc mvc;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        ValueOperations<String, String> ops = org.mockito.Mockito.mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(ops);
        mvc = MockMvcBuilders.webAppContextSetup(ctx).apply(springSecurity()).build();
    }

    private User admin(String name, AdminProfile profile) {
        User u = new User();
        u.setEmail(name + "." + UUID.randomUUID().toString().substring(0, 8) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName(name);
        u.setEmailVerified(true);
        u.setRole(Role.ADMIN);
        u.setStatus(UserStatus.ACTIVE);
        u.setAdminProfile(profile);
        return users.save(u);
    }

    private MockHttpServletResponse as(User u, MockHttpServletRequestBuilder b) throws Exception {
        var token = new UsernamePasswordAuthenticationToken(u.getId(), null, List.of(new SimpleGrantedAuthority("ROLE_ADMIN")));
        return mvc.perform(b.with(authentication(token))).andReturn().getResponse();
    }

    private static JsonNode json(MockHttpServletResponse r) throws Exception {
        return OM.readTree(r.getContentAsString(StandardCharsets.UTF_8));
    }

    @Test
    void deniedRequestGets403WithLocalizedCodeAndRequiredPermission() throws Exception {
        User viewer = admin("viewer", AdminProfile.VIEWER);

        MockHttpServletResponse r = as(viewer, post("/api/admin/support/tickets/1/notes")
                .contentType("application/json").content("{\"body\":\"x\"}"));

        assertEquals(403, r.getStatus(), r.getContentAsString());
        JsonNode j = json(r);
        assertEquals("ADMIN_PERMISSION_DENIED", j.get("code").asText());
        assertTrue(j.get("message").asText().contains("support.write"), j.toString());

    }

    @Test
    void chatContentIsDeniedWithoutChatRead() throws Exception {
        for (AdminProfile p : List.of(AdminProfile.SUPPORT, AdminProfile.EDITOR, AdminProfile.VIEWER)) {
            User u = admin("chat" + p, p);
            for (String path : List.of("/api/admin/chat-messages", "/api/admin/users/1/conversations",
                    "/api/admin/conversations/1/export")) {
                MockHttpServletResponse r = as(u, get(path));
                assertEquals(403, r.getStatus(), p + " " + path);
                assertEquals("ADMIN_PERMISSION_DENIED", json(r).get("code").asText());
            }
        }
        // MODERATOR yetkili: izin katmanini gecer (403 DEGIL)
        MockHttpServletResponse ok = as(admin("mod", AdminProfile.MODERATOR), get("/api/admin/chat-messages"));
        assertNotEquals(403, ok.getStatus());
    }

    @Test
    void rbacManagementIsFullOnlyButMeAndMatrixAreOpen() throws Exception {
        User viewer = admin("v", AdminProfile.VIEWER);
        assertEquals(403, as(viewer, get("/api/admin/rbac/admins")).getStatus());
        assertEquals(403, as(viewer, get("/api/admin/rbac/changes")).getStatus());
        assertEquals(403, as(viewer, put("/api/admin/rbac/users/1/profile").contentType("application/json")
                .content("{\"profile\":\"EDITOR\",\"reason\":\"deneme sebebi\"}")).getStatus());

        MockHttpServletResponse me = as(viewer, get("/api/admin/rbac/me"));
        assertEquals(200, me.getStatus());
        assertEquals("VIEWER", json(me).get("profile").asText());
        assertFalse(json(me).get("permissions").toString().contains("users.role"));

        MockHttpServletResponse matrix = as(viewer, get("/api/admin/rbac/matrix"));
        assertEquals(200, matrix.getStatus());
        assertEquals(5, json(matrix).get("profiles").size());

        assertEquals(200, as(admin("f", AdminProfile.FULL), get("/api/admin/rbac/admins")).getStatus());
    }

    @Test
    void basicAuthAdminIsFull() throws Exception {
        MockHttpServletResponse r = mvc.perform(get("/api/admin/rbac/me").with(httpBasic("admin", "test-admin-pw")))
                .andReturn().getResponse();
        assertEquals(200, r.getStatus(), r.getContentAsString());
        assertEquals("FULL", json(r).get("profile").asText());
    }

    @Test
    void directAssignmentChangesProfileAndTargetResolvesNewProfile() throws Exception {
        User full = admin("full", AdminProfile.FULL);
        User target = admin("hedef", AdminProfile.VIEWER);

        MockHttpServletResponse r = as(full, put("/api/admin/rbac/users/" + target.getId() + "/profile")
                .contentType("application/json").content("{\"profile\":\"EDITOR\",\"reason\":\"gorev degisikligi\"}"));

        assertEquals(204, r.getStatus(), r.getContentAsString());
        assertEquals(AdminProfile.EDITOR, users.findById(target.getId()).orElseThrow().getAdminProfile());
        assertEquals("EDITOR", json(as(target, get("/api/admin/rbac/me"))).get("profile").asText());
    }

    @Test
    void ruleViolationsReturn409() throws Exception {
        User full = admin("full2", AdminProfile.FULL);
        User target = admin("hedef2", AdminProfile.VIEWER);
        String body = "{\"profile\":\"%s\",\"reason\":\"deneme sebebi\"}";

        // FULL yapmak onay ister
        MockHttpServletResponse needsApproval = as(full, put("/api/admin/rbac/users/" + target.getId() + "/profile")
                .contentType("application/json").content(body.formatted("FULL")));
        assertEquals(409, needsApproval.getStatus());
        assertEquals("RBAC_APPROVAL_REQUIRED", json(needsApproval).get("code").asText());

        // kendi profili
        MockHttpServletResponse self = as(full, put("/api/admin/rbac/users/" + full.getId() + "/profile")
                .contentType("application/json").content(body.formatted("VIEWER")));
        assertEquals("RBAC_SELF_CHANGE", json(self).get("code").asText());

        // sabitli (ADMIN_EMAILS) hesap
        User pinned = admin("pinli.rbac", AdminProfile.FULL);
        pinned.setEmail("pinli.rbac@bingol.edu.tr");
        users.save(pinned);
        MockHttpServletResponse pin = as(full, put("/api/admin/rbac/users/" + pinned.getId() + "/profile")
                .contentType("application/json").content(body.formatted("VIEWER")));
        assertEquals("ADMIN_EMAIL_PINNED", json(pin).get("code").asText());

        // kisa sebep -> dogrulama hatasi
        MockHttpServletResponse bad = as(full, put("/api/admin/rbac/users/" + target.getId() + "/profile")
                .contentType("application/json").content("{\"profile\":\"EDITOR\",\"reason\":\"x\"}"));
        assertEquals(400, bad.getStatus());
    }

    @Test
    void twoPersonApprovalFlowOverHttp() throws Exception {
        User a = admin("a", AdminProfile.FULL);
        User b = admin("b", AdminProfile.FULL);
        User target = admin("t", AdminProfile.VIEWER);

        MockHttpServletResponse created = as(a, post("/api/admin/rbac/changes").contentType("application/json")
                .content("{\"userId\":" + target.getId() + ",\"profile\":\"FULL\",\"reason\":\"ikinci FULL gerekli\"}"));
        assertEquals(201, created.getStatus(), created.getContentAsString());
        long id = json(created).get("id").asLong();
        assertEquals("PENDING", json(created).get("status").asText());

        // oneren onaylayamaz
        MockHttpServletResponse own = as(a, post("/api/admin/rbac/changes/" + id + "/approve"));
        assertEquals(409, own.getStatus());
        assertEquals("RBAC_SAME_APPROVER", json(own).get("code").asText());
        assertEquals(AdminProfile.VIEWER, users.findById(target.getId()).orElseThrow().getAdminProfile());

        // yetkisiz profil onaylayamaz
        MockHttpServletResponse denied = as(admin("viewer", AdminProfile.VIEWER), post("/api/admin/rbac/changes/" + id + "/approve"));
        assertEquals(403, denied.getStatus());

        // bekleyenler listesinde
        MockHttpServletResponse list = as(b, get("/api/admin/rbac/changes?status=PENDING"));
        assertEquals(200, list.getStatus());
        assertTrue(list.getContentAsString().contains("\"id\":" + id));

        // ikinci FULL onaylar
        MockHttpServletResponse ok = as(b, post("/api/admin/rbac/changes/" + id + "/approve")
                .contentType("application/json").content("{\"note\":\"onayladim\"}"));
        assertEquals(200, ok.getStatus(), ok.getContentAsString());
        assertEquals("APPROVED", json(ok).get("status").asText());
        assertEquals(AdminProfile.FULL, users.findById(target.getId()).orElseThrow().getAdminProfile());

        // tekrar karar verilemez
        assertEquals("RBAC_CHANGE_DECIDED", json(as(b, post("/api/admin/rbac/changes/" + id + "/reject"))).get("code").asText());
    }

    @Test
    void maskedProfilesSeeMaskedEmailInUserList() throws Exception {
        User row = admin("maskehedef", AdminProfile.VIEWER);
        String email = row.getEmail();
        String masked = PermissionAwareMasking.maskEmail(email);
        assertNotEquals(email, masked);

        for (AdminProfile p : List.of(AdminProfile.SUPPORT, AdminProfile.VIEWER)) {
            User viewer = admin("maske" + p, p);
            MockHttpServletResponse list = as(viewer, get("/api/admin/users?q=maskehedef"));
            assertEquals(200, list.getStatus(), list.getContentAsString());
            assertTrue(list.getContentAsString().contains(masked), p + " " + list.getContentAsString());
            assertFalse(list.getContentAsString().contains(email), p + " e-posta sizdi");
        }
        for (AdminProfile p : List.of(AdminProfile.MODERATOR, AdminProfile.FULL)) {
            User viewer = admin("acik" + p, p);
            assertTrue(as(viewer, get("/api/admin/users?q=maskehedef")).getContentAsString().contains(email), p.name());
        }
    }

    @Test
    void roleChangeStartsNewAdminAsViewer() throws Exception {
        // AdminUserService.changeRole: USER -> ADMIN en dar profille baslar
        User plain = new User();
        plain.setEmail("duz." + UUID.randomUUID().toString().substring(0, 8) + "@bingol.edu.tr");
        plain.setPasswordHash("x");
        plain.setDisplayName("Duz");
        plain.setEmailVerified(true);
        plain = users.save(plain);

        MockHttpServletResponse r = as(admin("fullrole", AdminProfile.FULL), org.springframework.test.web.servlet.request
                .MockMvcRequestBuilders.patch("/api/admin/users/" + plain.getId() + "/role")
                .contentType("application/json").content("{\"role\":\"ADMIN\"}"));

        assertEquals(204, r.getStatus(), r.getContentAsString());
        User after = users.findById(plain.getId()).orElseThrow();
        assertEquals(Role.ADMIN, after.getRole());
        assertEquals(AdminProfile.VIEWER, after.getAdminProfile());
    }
}
