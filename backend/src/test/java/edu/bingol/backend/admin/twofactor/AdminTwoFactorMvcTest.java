package edu.bingol.backend.admin.twofactor;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
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
import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.admin.rbac.AdminProfile;
import edu.bingol.backend.auth.twofactor.TwoFactorDevice;
import edu.bingol.backend.auth.twofactor.TwoFactorDeviceRepository;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.redis.core.SetOperations;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

/** Yonetici 2FA uclari (H2 + tam baglam): ozet, liste, kullanici DTO'su/suzgeci, kurtarma kapatmasi, RBAC, denetim. */
@SpringBootTest(properties = "app.admin.require-reason=true")
class AdminTwoFactorMvcTest {

    private static final ObjectMapper OM = new ObjectMapper();

    @Autowired WebApplicationContext ctx;
    @Autowired UserRepository users;
    @Autowired TwoFactorDeviceRepository devices;
    @Autowired org.springframework.jdbc.core.JdbcTemplate jdbc;
    @MockitoBean RateLimiter limiter;
    @MockitoBean NotificationService notifications;
    @MockitoBean StringRedisTemplate redis;
    MockMvc mvc;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        ValueOperations<String, String> ops = org.mockito.Mockito.mock(ValueOperations.class);
        SetOperations<String, String> setOps = org.mockito.Mockito.mock(SetOperations.class);
        when(redis.opsForValue()).thenReturn(ops);
        when(redis.opsForSet()).thenReturn(setOps);
        mvc = MockMvcBuilders.webAppContextSetup(ctx).addFilters(ctx.getBean(AdminReasonFilter.class))
                .apply(springSecurity()).build();
    }

    private User account(String name, Role role, AdminProfile profile, boolean twoFactor) {
        User u = new User();
        u.setEmail(name.toLowerCase(java.util.Locale.ROOT).replaceAll("[^a-z]+", ".") + "."
                + UUID.randomUUID().toString().substring(0, 8) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName(name);
        u.setEmailVerified(true);
        u.setRole(role);
        u.setAdminProfile(profile);
        u.setStatus(UserStatus.ACTIVE);
        u.setTwoFactorEnabled(twoFactor);
        u.setTwoFactorEnabledAt(twoFactor ? Instant.now() : null);
        return users.save(u);
    }

    private User admin(String name, AdminProfile profile) {
        return account(name, Role.ADMIN, profile, false);
    }

    private TwoFactorDevice trusted(User u, int n) {
        TwoFactorDevice d = new TwoFactorDevice();
        d.setUserId(u.getId());
        d.setDeviceHash(String.format("%064d", n) + "");
        d.setLabel("ANDROID 2.0.5");
        return devices.save(d);
    }

    private MvcResult as(User u, MockHttpServletRequestBuilder b) throws Exception {
        var token = new UsernamePasswordAuthenticationToken(u.getId(), null, List.of(new SimpleGrantedAuthority("ROLE_ADMIN")));
        return mvc.perform(b.with(authentication(token))).andReturn();
    }

    private static JsonNode json(MockHttpServletResponse r) throws Exception {
        return OM.readTree(r.getContentAsString(StandardCharsets.UTF_8));
    }

    // ------------------------------------------------------------------ ozet / liste

    @Test
    void summaryCountsEnabledUsersRecentEnablementsAndTrustedDevices() throws Exception {
        User full = admin("full.ozet", AdminProfile.FULL);
        JsonNode before = json(as(full, get("/api/admin/two-factor/summary")).getResponse());
        assertTrue(before.has("enabledCount") && before.has("totalActiveUsers") && before.has("enabledPercent")
                && before.has("enabledLast7Days") && before.has("trustedDeviceTotal"), before.toString());

        User a = account("Acik Bir", Role.USER, null, true);
        User b = account("Acik Iki", Role.USER, null, true);
        b.setTwoFactorEnabledAt(Instant.now().minusSeconds(30L * 24 * 3600)); // 30 gun once
        users.save(b);
        account("Kapali Uc", Role.USER, null, false);
        trusted(a, 1);
        trusted(a, 2);
        trusted(b, 3);

        JsonNode after = json(as(full, get("/api/admin/two-factor/summary")).getResponse());

        assertEquals(before.get("enabledCount").asLong() + 2, after.get("enabledCount").asLong());
        assertEquals(before.get("enabledLast7Days").asLong() + 1, after.get("enabledLast7Days").asLong());
        assertEquals(before.get("trustedDeviceTotal").asLong() + 3, after.get("trustedDeviceTotal").asLong());
        assertEquals(before.get("totalActiveUsers").asLong() + 3, after.get("totalActiveUsers").asLong());
        double pct = after.get("enabledPercent").asDouble();
        assertTrue(pct > 0 && pct <= 100, "oran " + pct);
    }

    @Test
    void userListShowsOnlyTwoFactorUsersWithDeviceCountsPagedAndMaskedForViewers() throws Exception {
        User full = admin("full.liste", AdminProfile.FULL);
        User viewer = admin("viewer.liste", AdminProfile.VIEWER);
        User on = account("Zeytin Listeli", Role.USER, null, true);
        account("Zeytin Kapali", Role.USER, null, false);
        trusted(on, 11);
        trusted(on, 12);

        JsonNode j = json(as(full, get("/api/admin/two-factor/users").param("q", "Zeytin")).getResponse());

        assertEquals(1, j.get("totalElements").asInt(), j.toString());
        assertEquals(1, j.get("totalPages").asInt());
        assertEquals(0, j.get("number").asInt());
        assertEquals(20, j.get("size").asInt());
        JsonNode row = j.get("content").get(0);
        assertEquals(on.getId(), row.get("userId").asLong());
        assertEquals("Zeytin Listeli", row.get("displayName").asText());
        assertEquals(on.getEmail(), row.get("email").asText());
        assertEquals("USER", row.get("role").asText());
        assertNotNull(row.get("enabledAt").asText());
        assertEquals(2, row.get("trustedDeviceCount").asInt());
        assertTrue(row.has("lastLoginAt"));

        // users.pii olmayan profil: e-posta maskeli (VIEWER)
        JsonNode masked = json(as(viewer, get("/api/admin/two-factor/users").param("q", "Zeytin")).getResponse());
        assertEquals(1, masked.get("totalElements").asInt(), masked.toString());
        String m = masked.get("content").get(0).get("email").asText();
        assertTrue(m.contains("***@bingol.edu.tr"), m);
        assertFalse(m.equals(on.getEmail()));

        // sayfalama: size=1
        account("Zeytin Ikinci", Role.USER, null, true);
        JsonNode paged = json(as(full, get("/api/admin/two-factor/users").param("q", "Zeytin").param("size", "1")).getResponse());
        assertEquals(2, paged.get("totalElements").asInt());
        assertEquals(2, paged.get("totalPages").asInt());
        assertEquals(1, paged.get("content").size());
    }

    // ------------------------------------------------------------------ kullanici DTO'su + suzgec

    @Test
    void userListCarriesTheFlagAndFiltersByTwoFactor() throws Exception {
        User full = admin("full.suzgec", AdminProfile.FULL);
        account("Kayin Acik", Role.USER, null, true);
        account("Kayin Kapali", Role.USER, null, false);

        JsonNode both = json(as(full, get("/api/admin/users").param("q", "Kayin")).getResponse());
        assertEquals(2, both.get("totalItems").asInt(), both.toString());
        for (JsonNode it : both.get("items")) {
            assertTrue(it.has("twoFactorEnabled"));
            assertEquals(it.get("displayName").asText().equals("Kayin Acik"), it.get("twoFactorEnabled").asBoolean());
        }
        JsonNode on = json(as(full, get("/api/admin/users").param("q", "Kayin").param("twoFactor", "true")).getResponse());
        assertEquals(1, on.get("totalItems").asInt());
        assertEquals("Kayin Acik", on.get("items").get(0).get("displayName").asText());
        JsonNode off = json(as(full, get("/api/admin/users").param("q", "Kayin").param("twoFactor", "false")).getResponse());
        assertEquals(1, off.get("totalItems").asInt());
        assertEquals("Kayin Kapali", off.get("items").get(0).get("displayName").asText());
    }

    // Kullanici ayrintisi (twoFactorEnabled/twoFactorTrustedDeviceCount/twoFactorEnabledAt) PostgreSQL'e ozel
    // `detail` sorgusundan gelir (H2'de calismaz); `scripts/smoke-two-factor.sh` dogrular. DTO maskeleme: AdminUserTwoFactorDtoTest.

    // ------------------------------------------------------------------ kurtarma kapatmasi

    @Test
    void disableNeedsAReasonThenTurnsOffWipesDevicesNotifiesAndIsAudited() throws Exception {
        User full = admin("full.kapat", AdminProfile.FULL);
        User target = account("Kurtarilan", Role.USER, null, true);
        trusted(target, 31);
        trusted(target, 32);
        String path = "/api/admin/users/" + target.getId() + "/two-factor/disable";

        MockHttpServletResponse noReason = as(full, post(path).contentType("application/json").content("{}")).getResponse();
        assertEquals(400, noReason.getStatus(), noReason.getContentAsString());
        assertEquals("REASON_REQUIRED", json(noReason).get("code").asText());
        assertTrue(users.findById(target.getId()).orElseThrow().isTwoFactorEnabled(), "gerekcesiz islem yapilmaz");
        MockHttpServletResponse shortReason = as(full, post(path).contentType("application/json")
                .content("{\"reason\":\"abc\"}")).getResponse();
        assertEquals(400, shortReason.getStatus());

        MvcResult ok = as(full, post(path).contentType("application/json")
                .content("{\"reason\":\"Telefon kayboldu, kimlik dogrulandi\"}"));

        assertEquals(204, ok.getResponse().getStatus(), ok.getResponse().getContentAsString());
        User after = users.findById(target.getId()).orElseThrow();
        assertFalse(after.isTwoFactorEnabled());
        assertNull(after.getTwoFactorEnabledAt());
        assertEquals(0, devices.findByUserIdOrderByLastUsedAtDesc(target.getId()).size());
        verify(notifications).sendLocalized(target.getId(), NotificationType.SYSTEM, "notif.twofactor.disabled.title",
                "notif.twofactor.disabled.body", null, java.util.Map.of("securityKind", "TWOFA_DISABLED"));
        // denetim baglami: hedef, gerekce, ozet (AuditInterceptor bunlari admin_audit'e yazar)
        AuditContext.Data audit = AuditContext.of(ok.getRequest());
        assertEquals("USER", audit.targetType());
        assertEquals(String.valueOf(target.getId()), audit.targetId());
        assertEquals("Telefon kayboldu, kimlik dogrulandi", audit.reason());
        assertTrue(audit.summary().contains("iki faktorlu"), audit.summary());
    }

    @Test
    void disableOnAnAccountWithoutTwoFactorOrUnknownIsRejected() throws Exception {
        User full = admin("full.red", AdminProfile.FULL);
        User plain = account("Zaten Kapali", Role.USER, null, false);

        MockHttpServletResponse r = as(full, post("/api/admin/users/" + plain.getId() + "/two-factor/disable")
                .header("X-Admin-Reason", "gerekce yeterli uzunlukta")).getResponse();
        assertEquals(409, r.getStatus(), r.getContentAsString());
        assertEquals("TWO_FACTOR_NOT_ENABLED", json(r).get("code").asText());

        MockHttpServletResponse nf = as(full, post("/api/admin/users/987654321/two-factor/disable")
                .header("X-Admin-Reason", "gerekce yeterli uzunlukta")).getResponse();
        assertEquals(404, nf.getStatus());
        assertEquals("USER_NOT_FOUND", json(nf).get("code").asText());
        verify(notifications, never()).sendLocalized(any(), any(), any(), any(), any(), any());
    }

    @Test
    void permissionsReadIsUsersReadDisableIsUsers2faForFullAndSupportOnly() throws Exception {
        User viewer = admin("viewer.izin", AdminProfile.VIEWER);
        User moderator = admin("mod.izin", AdminProfile.MODERATOR);
        User support = admin("destek.izin", AdminProfile.SUPPORT);
        User full = admin("full.izin", AdminProfile.FULL);
        User target = account("Izin Hedef", Role.USER, null, true);
        String disable = "/api/admin/users/" + target.getId() + "/two-factor/disable";
        String reason = "gerekce yeterli uzunlukta";

        // VIEWER okur (users.read) ama kapatamaz
        assertEquals(200, as(viewer, get("/api/admin/two-factor/summary")).getResponse().getStatus());
        assertEquals(200, as(viewer, get("/api/admin/two-factor/users")).getResponse().getStatus());
        MockHttpServletResponse denied = as(viewer, post(disable).header("X-Admin-Reason", reason)).getResponse();
        assertEquals(403, denied.getStatus());
        assertEquals("ADMIN_PERMISSION_DENIED", json(denied).get("code").asText());
        assertTrue(json(denied).get("message").asText().contains("users.2fa"), json(denied).toString());
        assertTrue(users.findById(target.getId()).orElseThrow().isTwoFactorEnabled());

        // MODERATOR users.write sahibi olsa da hesap kurtarma yapamaz (karar: yalniz FULL ve SUPPORT)
        MockHttpServletResponse mod = as(moderator, post(disable).header("X-Admin-Reason", reason)).getResponse();
        assertEquals(403, mod.getStatus(), mod.getContentAsString());
        assertEquals("ADMIN_PERMISSION_DENIED", json(mod).get("code").asText());
        assertTrue(users.findById(target.getId()).orElseThrow().isTwoFactorEnabled());

        // SUPPORT kapatabilir
        assertEquals(204, as(support, post(disable).header("X-Admin-Reason", reason)).getResponse().getStatus());
        assertFalse(users.findById(target.getId()).orElseThrow().isTwoFactorEnabled());

        // SUPPORT yonetici hesabina dokunamaz (hiyerarsi: yalniz FULL)
        User adminTarget = account("Viewer Hedef", Role.ADMIN, AdminProfile.VIEWER, true);
        MockHttpServletResponse hier = as(support, post("/api/admin/users/" + adminTarget.getId() + "/two-factor/disable")
                .header("X-Admin-Reason", reason)).getResponse();
        assertEquals(403, hier.getStatus(), hier.getContentAsString());
        assertEquals("ADMIN_TARGET_FORBIDDEN", json(hier).get("code").asText());
        assertTrue(users.findById(adminTarget.getId()).orElseThrow().isTwoFactorEnabled());

        // FULL, FULL olmayan bir yoneticinin 2FA'sini kapatabilir
        assertEquals(204, as(full, post("/api/admin/users/" + adminTarget.getId() + "/two-factor/disable")
                .header("X-Admin-Reason", reason)).getResponse().getStatus());
        assertFalse(users.findById(adminTarget.getId()).orElseThrow().isTwoFactorEnabled());
    }

    @Test
    void anAdminCannotDisableTheirOwnTwoFactorOrAnotherFullAdminsFromThePanel() throws Exception {
        User full = account("Full Kendi", Role.ADMIN, null, true);
        full.setAdminProfile(AdminProfile.FULL);
        users.save(full);
        User otherFull = account("Full Diger", Role.ADMIN, AdminProfile.FULL, true);
        String reason = "gerekce yeterli uzunlukta";

        MockHttpServletResponse self = as(full, post("/api/admin/users/" + full.getId() + "/two-factor/disable")
                .header("X-Admin-Reason", reason)).getResponse();
        assertEquals(403, self.getStatus(), self.getContentAsString());
        assertEquals("ADMIN_SELF_FORBIDDEN", json(self).get("code").asText());
        assertTrue(users.findById(full.getId()).orElseThrow().isTwoFactorEnabled());

        MockHttpServletResponse other = as(full, post("/api/admin/users/" + otherFull.getId() + "/two-factor/disable")
                .header("X-Admin-Reason", reason)).getResponse();
        assertEquals(403, other.getStatus(), other.getContentAsString());
        assertEquals("TWO_FACTOR_ADMIN_FORBIDDEN", json(other).get("code").asText());
        assertTrue(users.findById(otherFull.getId()).orElseThrow().isTwoFactorEnabled());
        verify(notifications, never()).sendLocalized(any(), any(), any(), any(), any(), any());
    }

    @Test
    void anAdminCloseOfTwoFactorEndsTheSessionsAndWritesTheMailNotice() throws Exception {
        User full = admin("full.oturum", AdminProfile.FULL);
        User target = account("Oturumlu Hedef", Role.USER, null, true);
        trusted(target, 51); // kurtarma kapatmasi: revokeAll olayi (ayri islem) ve reset ayni satirlarda kilitlenmemeli
        trusted(target, 52);
        long outbox = jdbc.queryForObject("SELECT count(*) FROM mail_outbox WHERE template = 'SECURITY_TWO_FACTOR_NOTICE'", Long.class);

        MockHttpServletResponse ok = as(full, post("/api/admin/users/" + target.getId() + "/two-factor/disable")
                .header("X-Admin-Reason", "gerekce yeterli uzunlukta")).getResponse();

        assertEquals(204, ok.getStatus(), ok.getContentAsString());
        // SessionService.revokeAll: sifre/oturum iptal isareti yazilir (kullanicinin tum access token'lari reddedilir)
        verify(redis.opsForValue()).set(org.mockito.ArgumentMatchers.eq("pwchg:" + target.getId()), any(String.class), any(java.time.Duration.class));
        assertEquals(outbox + 1, jdbc.queryForObject(
                "SELECT count(*) FROM mail_outbox WHERE template = 'SECURITY_TWO_FACTOR_NOTICE'", Long.class));
        assertEquals(0, devices.findByUserIdOrderByLastUsedAtDesc(target.getId()).size());
        assertFalse(users.findById(target.getId()).orElseThrow().isTwoFactorEnabled());
    }

    @Test
    void usersListKeepsWorkingWithoutTheTwoFactorParameter() throws Exception {
        User full = admin("full.eski", AdminProfile.FULL);
        MockHttpServletResponse r = as(full, get("/api/admin/users").param("size", "5")).getResponse();
        assertEquals(200, r.getStatus(), r.getContentAsString());
        assertTrue(json(r).get("items").size() >= 1);
    }
}
