package edu.bingol.backend.admin.users.extras;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.startsWith;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import edu.bingol.backend.admin.AdminReasonFilter;
import edu.bingol.backend.auth.token.SessionService;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.moderation.UserModerationService;
import edu.bingol.backend.notification.Device;
import edu.bingol.backend.notification.DeviceRepository;
import edu.bingol.backend.notification.Notification;
import edu.bingol.backend.notification.NotificationRepository;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
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

/** P09: kullanici derin yonetimi uclari (H2 + tam baglam; Redis'e dokunan servisler taklit). */
@SpringBootTest(properties = "app.admin.require-reason=true")
class AdminUserExtrasMvcTest {

    private static final ObjectMapper OM = new ObjectMapper();
    private static final long ADMIN_ID = 990009L;
    private static final String LONG_REASON = "KVKK basvurusu uzerine dis aktarma yapildi";

    @Autowired WebApplicationContext ctx;
    @Autowired UserRepository users;
    @Autowired DeviceRepository devices;
    @Autowired NotificationRepository notifs;
    @MockitoBean RateLimiter limiter;
    @MockitoBean SessionService sessionService;
    @MockitoBean UserModerationService moderation;
    @MockitoBean NotificationService notificationService;
    @MockitoBean AdminUserSessionService sessionView;
    MockMvc mvc;

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.webAppContextSetup(ctx).addFilters(ctx.getBean(AdminReasonFilter.class))
                .apply(springSecurity()).build();
    }

    private MockHttpServletResponse call(MockHttpServletRequestBuilder b) throws Exception {
        var admin = new UsernamePasswordAuthenticationToken(ADMIN_ID, null, List.of(new SimpleGrantedAuthority("ROLE_ADMIN")));
        return mvc.perform(b.with(authentication(admin))).andReturn().getResponse();
    }

    private static JsonNode json(MockHttpServletResponse r) throws Exception {
        return OM.readTree(r.getContentAsString(StandardCharsets.UTF_8));
    }

    private User user(String name, Role role, UserStatus status, String faculty) {
        User u = new User();
        u.setEmail(name.toLowerCase().replaceAll("[^a-z]+", ".") + "." + UUID.randomUUID().toString().substring(0, 8) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName(name);
        u.setEmailVerified(true);
        u.setRole(role);
        u.setStatus(status);
        u.setFaculty(faculty);
        return users.save(u);
    }

    // ---------- sebep zorunlulugu ----------

    @Test
    void writesRequireAReasonAndExportRequiresTwentyChars() throws Exception {
        User u = user("Sebep Kullanici", Role.USER, UserStatus.ACTIVE, null);
        String base = "/api/admin/users/" + u.getId();

        List<MockHttpServletRequestBuilder> noReason = List.of(
                patch(base + "/profile").contentType("application/json").content("{\"clearBio\":true}"),
                delete(base + "/push-devices/1"),
                delete(base + "/sessions/aaaaaaaaaaaaaaaa"),
                post(base + "/export").header("X-Admin-Confirm", u.getId()),
                post("/api/admin/users/bulk").contentType("application/json")
                        .content("{\"action\":\"REVOKE_SESSIONS\",\"ids\":[" + u.getId() + "]}"));
        for (MockHttpServletRequestBuilder b : noReason) {
            MockHttpServletResponse r = call(b);
            assertEquals(400, r.getStatus(), b + " " + r.getContentAsString());
            assertEquals("REASON_REQUIRED", json(r).get("code").asText(), b.toString());
        }
        // disa aktarma: 5-19 karakter yetmez (>= 20)
        MockHttpServletResponse shortR = call(post(base + "/export").header("X-Admin-Reason", "on iki karakter")
                .header("X-Admin-Confirm", u.getId()));
        assertEquals(400, shortR.getStatus());
        assertEquals("REASON_REQUIRED", json(shortR).get("code").asText());
        verify(limiter, never()).check(startsWith("admexp:"), anyInt(), any());
    }

    // ---------- profil mudahalesi ----------

    @Test
    void profileInterventionClearsBioAndDoesNotApplyProfanityFilter() throws Exception {
        User u = user("Profil Hedef", Role.USER, UserStatus.ACTIVE, null);
        u.setBio("uygunsuz biyografi");
        users.save(u);

        MockHttpServletResponse r = call(patch("/api/admin/users/" + u.getId() + "/profile")
                .contentType("application/json")
                .content("{\"clearBio\":true,\"displayName\":\"Düzeltilmiş Ad\",\"reason\":\"kurallara aykırı\"}"));

        assertEquals(200, r.getStatus(), r.getContentAsString());
        assertTrue(json(r).get("bioCleared").asBoolean());
        assertTrue(json(r).get("displayNameChanged").asBoolean());
        assertFalse(json(r).get("avatarCleared").asBoolean());
        User after = users.findById(u.getId()).orElseThrow();
        assertNull(after.getBio());
        assertEquals("Düzeltilmiş Ad", after.getDisplayName());
        verify(notificationService).sendLocalized(u.getId(), NotificationType.SYSTEM, "notif.profile.moderated.title",
                "notif.profile.moderated.body", null, null);

        MockHttpServletResponse empty = call(patch("/api/admin/users/" + u.getId() + "/profile")
                .header("X-Admin-Reason", "yeterli sebep").contentType("application/json").content("{}"));
        assertEquals(400, empty.getStatus());
        assertEquals("PROFILE_PATCH_EMPTY", json(empty).get("code").asText());
    }

    // ---------- FCM cihazlari ----------

    @Test
    void pushDevicesAreMaskedAndDeletable() throws Exception {
        User u = user("Cihaz Sahibi", Role.USER, UserStatus.ACTIVE, null);
        Device d = new Device();
        d.setUserId(u.getId());
        d.setFcmToken("fcm-token-" + UUID.randomUUID() + "-SECRETTAIL");
        d.setPlatform("ANDROID");
        d.setAppVersion("2.0.1");
        devices.save(d);
        String base = "/api/admin/users/" + u.getId() + "/push-devices";

        MockHttpServletResponse list = call(get(base));
        assertEquals(200, list.getStatus(), list.getContentAsString());
        JsonNode row = json(list).get(0);
        assertEquals("ETTAIL", row.get("tokenTail").asText());
        assertFalse(list.getContentAsString().contains("fcm-token-"));
        assertEquals("2.0.1", row.get("appVersion").asText());

        assertEquals(204, call(delete(base + "/" + d.getId()).header("X-Admin-Reason", "cihaz kaydi temizligi")).getStatus());
        assertTrue(devices.findById(d.getId()).isEmpty());
        MockHttpServletResponse again = call(delete(base + "/" + d.getId()).header("X-Admin-Reason", "cihaz kaydi temizligi"));
        assertEquals(404, again.getStatus());
        assertEquals("PUSH_DEVICE_NOT_FOUND", json(again).get("code").asText());
    }

    // ---------- bildirim gecmisi ----------

    @Test
    void notificationHistoryIsPagedAndFilterable() throws Exception {
        User u = user("Bildirim Sahibi", Role.USER, UserStatus.ACTIVE, null);
        for (int i = 0; i < 3; i++) {
            Notification n = new Notification();
            n.setUserId(u.getId());
            n.setType(i == 0 ? NotificationType.SYSTEM : NotificationType.NEWS);
            n.setTitle("Baslik " + i);
            n.setBody("Govde " + i);
            if (i == 2) {
                n.setReadAt(Instant.now());
            }
            notifs.save(n);
        }
        String base = "/api/admin/users/" + u.getId() + "/notifications";

        JsonNode all = json(call(get(base).param("size", "2")));
        assertEquals(3, all.get("totalItems").asInt());
        assertEquals(2, all.get("totalPages").asInt());
        assertEquals(2, all.get("items").size());
        assertEquals("Baslik 2", all.get("items").get(0).get("title").asText()); // en yeni once
        assertTrue(all.get("items").get(0).get("read").asBoolean());

        assertEquals(2, json(call(get(base).param("unread", "true"))).get("totalItems").asInt());
        assertEquals(1, json(call(get(base).param("type", "system"))).get("totalItems").asInt());
        assertEquals(400, call(get(base).param("type", "BOGUS")).getStatus());
        assertEquals(404, call(get("/api/admin/users/987654321/notifications")).getStatus());
    }

    // ---------- tek oturum (taklit servis) ----------

    @Test
    void sessionEndpointsDelegateToTheService() throws Exception {
        User u = user("Oturum Sahibi", Role.USER, UserStatus.ACTIVE, null);
        when(sessionView.list(u.getId())).thenReturn(new UserExtrasDtos.SessionList(0, List.of()));

        assertEquals(200, call(get("/api/admin/users/" + u.getId() + "/sessions")).getStatus());
        assertEquals(204, call(delete("/api/admin/users/" + u.getId() + "/sessions/aaaaaaaaaaaaaaaa")
                .header("X-Admin-Reason", "supheli oturum")).getStatus());
        verify(sessionView).revoke(u.getId(), "aaaaaaaaaaaaaaaa");
    }

    // ---------- KVKK dis aktarma ----------

    @Test
    void exportNeedsSecondConfirmationAndIsDownloadable() throws Exception {
        User u = user("Export Hedef", Role.USER, UserStatus.ACTIVE, null);
        String url = "/api/admin/users/" + u.getId() + "/export";

        MockHttpServletResponse noConfirm = call(post(url).header("X-Admin-Reason", LONG_REASON));
        assertEquals(400, noConfirm.getStatus());
        assertEquals("EXPORT_CONFIRM_MISMATCH", json(noConfirm).get("code").asText());
        MockHttpServletResponse wrong = call(post(url).header("X-Admin-Reason", LONG_REASON).header("X-Admin-Confirm", "1"));
        assertEquals("EXPORT_CONFIRM_MISMATCH", json(wrong).get("code").asText());
        verify(limiter, never()).check(startsWith("admexp:"), anyInt(), any());

        MockHttpServletResponse ok = call(post(url).header("X-Admin-Reason", LONG_REASON)
                .header("X-Admin-Confirm", String.valueOf(u.getId())));
        assertEquals(200, ok.getStatus(), ok.getContentAsString());
        assertTrue(ok.getHeader("Content-Disposition").contains("user-" + u.getId() + "-data.json"));
        assertEquals("no-store", ok.getHeader("Cache-Control"));
        assertEquals(u.getId(), json(ok).get("subjectUserId").asLong());
        assertTrue(json(ok).has("exportedAt"));
        verify(limiter).check("admexp:" + u.getId(), 1, Duration.ofDays(1));
        // kullaniciya bildirim GITMEZ
        verify(notificationService, never()).send(anyLong(), any(), anyString(), any(), any());
    }

    // ---------- toplu islem ----------

    @Test
    void bulkReportsPartialSuccessAndProtectsAdmins() throws Exception {
        User a = user("Toplu A", Role.USER, UserStatus.ACTIVE, null);
        User adm = user("Toplu Yonetici", Role.ADMIN, UserStatus.ACTIVE, null);

        MockHttpServletResponse r = call(post("/api/admin/users/bulk").contentType("application/json")
                .content("{\"action\":\"REVOKE_SESSIONS\",\"reason\":\"toplu temizlik\",\"ids\":["
                        + a.getId() + "," + adm.getId() + ",987654321," + ADMIN_ID + "]}"));

        assertEquals(200, r.getStatus(), r.getContentAsString());
        JsonNode j = json(r);
        assertEquals(4, j.get("requested").asInt());
        assertEquals(1, j.get("done").asInt());
        assertEquals(2, j.get("skipped").asInt()); // yonetici hedef + yonetici kendisi
        assertEquals(1, j.get("failed").asInt()); // olmayan kimlik
        verify(sessionService).revokeAll(a.getId());
        verify(sessionService, never()).revokeAll(adm.getId());

        MockHttpServletResponse bad = call(post("/api/admin/users/bulk").contentType("application/json")
                .content("{\"action\":\"NUKE\",\"reason\":\"toplu temizlik\",\"ids\":[1]}"));
        assertEquals(400, bad.getStatus());
        MockHttpServletResponse emptyIds = call(post("/api/admin/users/bulk").contentType("application/json")
                .content("{\"action\":\"SUSPEND\",\"reason\":\"toplu temizlik\",\"ids\":[]}"));
        assertEquals(400, emptyIds.getStatus());
    }

    // ---------- liste suzgecleri + CSV ----------

    @Test
    void listFiltersByFacultyDatesAndSort() throws Exception {
        String fac = "P09 Fakultesi " + UUID.randomUUID().toString().substring(0, 6);
        User a = user("Suzgec A", Role.USER, UserStatus.ACTIVE, fac);
        User b = user("Suzgec B", Role.USER, UserStatus.SUSPENDED, fac);
        a.setLastSeenAt(Instant.now().minus(Duration.ofDays(40)));
        users.save(a);
        String today = java.time.LocalDate.now(java.time.ZoneId.of("Europe/Istanbul")).toString();
        String tomorrow = java.time.LocalDate.now(java.time.ZoneId.of("Europe/Istanbul")).plusDays(1).toString();

        assertEquals(2, json(call(get("/api/admin/users").param("faculty", fac))).get("totalItems").asInt());
        assertEquals(1, json(call(get("/api/admin/users").param("faculty", fac).param("status", "SUSPENDED")))
                .get("totalItems").asInt());
        // kayit tarihi araligi (bugun dahil / gelecek haric)
        assertEquals(2, json(call(get("/api/admin/users").param("faculty", fac).param("createdFrom", today)
                .param("createdTo", today))).get("totalItems").asInt());
        assertEquals(0, json(call(get("/api/admin/users").param("faculty", fac).param("createdFrom", tomorrow)))
                .get("totalItems").asInt());
        // son gorulme: yalniz a (40 gun once) ve b hic gorulmedi (NULL) -> aralikta yalniz a
        String from = java.time.LocalDate.now().minusDays(60).toString();
        String to = java.time.LocalDate.now().minusDays(30).toString();
        JsonNode seen = json(call(get("/api/admin/users").param("faculty", fac).param("seenFrom", from).param("seenTo", to)));
        assertEquals(1, seen.get("totalItems").asInt());
        assertEquals(a.getId(), seen.get("items").get(0).get("id").asLong());
        // ters aralik ve gecersiz tarih / siralama: 400
        assertEquals(400, call(get("/api/admin/users").param("createdFrom", tomorrow).param("createdTo", today)).getStatus());
        assertEquals(400, call(get("/api/admin/users").param("createdFrom", "dun")).getStatus());
        assertEquals(400, call(get("/api/admin/users").param("sort", "password_hash,asc")).getStatus());
        // beyaz listeye eklenen alan
        JsonNode sorted = json(call(get("/api/admin/users").param("faculty", fac).param("sort", "faculty,asc")));
        assertEquals(2, sorted.get("items").size());
    }

    @Test
    void csvHonorsFiltersEscapesFormulasAndKeepsFullEmail() throws Exception {
        String fac = "P09 CSV " + UUID.randomUUID().toString().substring(0, 6);
        User a = user("=HYPERLINK(\"http://x\")", Role.USER, UserStatus.ACTIVE, fac);
        user("Baska Fakulte", Role.USER, UserStatus.ACTIVE, "Baska " + fac);

        MockHttpServletResponse r = call(get("/api/admin/users/export.csv").param("faculty", fac));

        assertEquals(200, r.getStatus());
        String csv = r.getContentAsString(StandardCharsets.UTF_8);
        assertTrue(csv.startsWith("﻿id,email,"));
        assertTrue(csv.contains(a.getEmail()), "e-posta TAM olmali");
        assertTrue(csv.contains("'=HYPERLINK") || csv.contains("\"'=HYPERLINK"), csv);
        assertFalse(csv.contains(",=HYPERLINK"));
        assertEquals(2, csv.trim().split("\r\n").length); // baslik + tek satir (suzgec calisti)
        // ters tarih araligi yanit yazilmadan 400
        assertEquals(400, call(get("/api/admin/users/export.csv").param("createdFrom", "2026-10-02")
                .param("createdTo", "2026-10-01")).getStatus());
    }
}
