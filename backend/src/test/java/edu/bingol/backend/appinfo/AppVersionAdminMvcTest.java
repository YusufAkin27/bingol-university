package edu.bingol.backend.appinfo;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import edu.bingol.backend.admin.AdminReasonFilter;
import edu.bingol.backend.admin.rbac.AdminProfile;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.nio.charset.StandardCharsets;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

/**
 * UPDATEGATE (H2, tam baglam): surum dagilimi sayilari, zorlama ucunun gerekce/izin/denetim sozlesmesi ve
 * zorlamadan sonra herkese acik surum kontrolunun ANINDA yeni sonucu vermesi.
 */
@SpringBootTest(properties = "app.admin.require-reason=true")
class AppVersionAdminMvcTest {

    private static final ObjectMapper OM = new ObjectMapper();

    @Autowired WebApplicationContext ctx;
    @Autowired UserRepository users;
    @Autowired AppSettingRepository settings;
    @Autowired JdbcTemplate jdbc;
    @MockitoBean RateLimiter limiter;
    @MockitoBean StringRedisTemplate redis;
    MockMvc mvc;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        ValueOperations<String, String> ops = org.mockito.Mockito.mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(ops);
        mvc = MockMvcBuilders.webAppContextSetup(ctx).addFilters(ctx.getBean(AdminReasonFilter.class))
                .apply(springSecurity()).build();
        seed("min_version_android", "1.0.0");
        seed("latest_version_android", "2.0.4");
        seed("store_url_android", "");
        seed("store_package_android", "tr.com.bukampus.app");
        seed("min_version_ios", "1.0.0");
        seed("latest_version_ios", "1.0.0");
        seed("store_url_ios", "");
        seed("apple_app_id_ios", "");
        seed("update_message_tr", "");
        seed("update_message_en", "Please update to continue.");
        seed("update_message_ar", "");
    }

    private void seed(String key, String value) {
        AppSetting s = settings.findById(key).orElseGet(() -> {
            AppSetting n = new AppSetting();
            n.setKey(key);
            return n;
        });
        s.setValue(value);
        settings.save(s);
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

    private void device(long userId, String hash, String platform, String version, String ip, Instant seen) {
        jdbc.update("INSERT INTO user_device_log (user_id, device_hash, platform, app_version, ip, ip_family, "
                        + "first_seen_at, last_seen_at, last_event, seen_count) VALUES (?,?,?,?,?,4,?,?,'REQUEST',1)",
                userId, hash, platform, version, ip, Timestamp.from(seen), Timestamp.from(seen));
    }

    private static long count(JsonNode d, String platform, String version) {
        for (JsonNode r : d.get("distribution")) {
            String v = r.get("version").isNull() ? null : r.get("version").asText();
            if (r.get("platform").asText().equals(platform) && java.util.Objects.equals(v, version)) {
                return r.get("devices").asLong();
            }
        }
        return 0;
    }

    private static JsonNode platform(JsonNode d, String p) {
        for (JsonNode n : d.get("platforms")) {
            if (n.get("platform").asText().equals(p)) {
                return n;
            }
        }
        throw new AssertionError(p);
    }

    @Test
    void distributionCountsLatestRowPerDeviceWithinWindowAndFlagsBelowMin() throws Exception {
        User viewer = admin("dagilim", AdminProfile.VIEWER);
        JsonNode before = json(as(viewer, get("/api/admin/app-versions")));
        Instant now = Instant.now();
        // cihaz A: eski IP'de 7.7.1, yeni IP'de 7.7.3 -> yalniz 7.7.3 sayilir; cihaz B: 7.7.1 (yapi ekli); cihaz C: pencere disi
        device(910001, "devA", "ANDROID", "7.7.1", "10.9.0.1", now.minus(10, ChronoUnit.DAYS));
        device(910001, "devA", "ANDROID", "7.7.3", "10.9.0.2", now.minus(1, ChronoUnit.DAYS));
        device(910002, "devB", "ANDROID", "7.7.1+7701", "10.9.0.3", now.minus(2, ChronoUnit.DAYS));
        device(910003, "devC", "ANDROID", "7.7.1", "10.9.0.4", now.minus(45, ChronoUnit.DAYS));
        device(910004, "devD", "IOS", "7.7.1", "10.9.0.5", now.minus(3, ChronoUnit.DAYS));
        device(910005, "devE", "ANDROID", null, "10.9.0.6", now.minus(3, ChronoUnit.DAYS));
        device(910006, "devF", "WEB", "7.7.1", "10.9.0.7", now.minus(3, ChronoUnit.DAYS));

        MockHttpServletResponse res = as(viewer, get("/api/admin/app-versions"));
        assertEquals(200, res.getStatus(), res.getContentAsString());
        JsonNode d = json(res);
        assertEquals("USER_DEVICE_LOG", d.get("source").asText());
        assertEquals(30, d.get("windowDays").asInt());
        assertFalse(d.get("sourceNote").asText().isBlank());
        assertEquals(1, count(d, "android", "7.7.3") - count(before, "android", "7.7.3"));
        assertEquals(1, count(d, "android", "7.7.1") - count(before, "android", "7.7.1"), "yapi eki atilir, pencere disi yok");
        assertEquals(1, count(d, "ios", "7.7.1") - count(before, "ios", "7.7.1"));
        assertEquals(1, count(d, "android", null) - count(before, "android", null), "surumsuz = bilinmiyor");
        assertEquals(0, count(d, "web", "7.7.1"), "yalniz android/ios");

        // min 8.0.0 olunca 7.7.x cihazlar 'altinda'
        long beforeBelow = platform(before, "android").get("belowMin").asLong();
        assertEquals(beforeBelow, platform(d, "android").get("belowMin").asLong(), "min 1.0.0: kimse altinda degil");
        seed("min_version_android", "8.0.0");
        seed("latest_version_android", "8.0.0");
        JsonNode d2 = json(as(viewer, get("/api/admin/app-versions")));
        JsonNode android = platform(d2, "android");
        assertEquals("FORCE", android.get("state").asText());
        assertTrue(android.get("belowMin").asLong() >= 2, android.toString());
        assertEquals(android.get("total").asLong() - android.get("unknownVersion").asLong(), android.get("belowMin").asLong());
        assertTrue(d2.get("belowMin").asLong() >= android.get("belowMin").asLong());
    }

    @Test
    void enforceNeedsWritePermissionAndReason() throws Exception {
        String body = "{\"platform\":\"android\",\"version\":\"2.0.5\",\"mode\":\"FORCE\"}";
        // izin: VIEWER okur, yazamaz
        User viewer = admin("viewer", AdminProfile.VIEWER);
        MockHttpServletResponse denied = as(viewer, post("/api/admin/app-versions/enforce")
                .contentType("application/json").content(body));
        assertEquals(403, denied.getStatus(), denied.getContentAsString());
        assertEquals("ADMIN_PERMISSION_DENIED", json(denied).get("code").asText());
        // gerekce
        User full = admin("full", AdminProfile.FULL);
        MockHttpServletResponse noReason = as(full, post("/api/admin/app-versions/enforce")
                .contentType("application/json").content(body));
        assertEquals(400, noReason.getStatus());
        assertEquals("REASON_REQUIRED", json(noReason).get("code").asText());
        assertEquals("2.0.4", settings.findById("latest_version_android").orElseThrow().getValue(), "uygulanmadi");
    }

    @Test
    void forceTakesEffectImmediatelyOnPublicVersionCheckInRequestLanguage() throws Exception {
        // once: 2.0.4 zorunlu degil (onbellegi isit)
        MockHttpServletResponse warm = mvc.perform(get("/api/app/version?platform=android&version=2.0.4")).andReturn().getResponse();
        assertEquals(200, warm.getStatus(), warm.getContentAsString());
        assertFalse(json(warm).get("updateRequired").asBoolean());

        User full = admin("full2", AdminProfile.FULL);
        MockHttpServletResponse r = as(full, post("/api/admin/app-versions/enforce").contentType("application/json")
                .content("{\"platform\":\"android\",\"version\":\"2.0.5\",\"mode\":\"FORCE\",\"reason\":\"kritik hata duzeltmesi\"}"));
        assertEquals(200, r.getStatus(), r.getContentAsString());
        JsonNode j = json(r);
        assertEquals("FORCE", j.get("state").asText());
        assertEquals("2.0.5", j.get("minVersion").asText());
        assertEquals("2.0.4", j.get("previousLatest").asText());
        assertEquals("USER_DEVICE_LOG", j.get("source").asText());
        assertNotNull(j.get("affectedDevices"));

        JsonNode v = json(mvc.perform(get("/api/app/version?platform=android&version=2.0.4").header("Accept-Language", "en"))
                .andReturn().getResponse());
        assertTrue(v.get("updateRequired").asBoolean(), "onbellek gecersiz: ANINDA");
        assertEquals("2.0.5", v.get("latestVersion").asText());
        assertEquals("Please update to continue.", v.get("message").asText());
        assertEquals("https://play.google.com/store/apps/details?id=tr.com.bukampus.app", v.get("storeUrl").asText());
        assertEquals("market://details?id=tr.com.bukampus.app", v.get("marketUrl").asText());

        // yayindakinden dusuk zorunlu surum: 400 + istek dilinde mesaj
        MockHttpServletResponse low = as(full, post("/api/admin/app-versions/enforce").header("Accept-Language", "en")
                .contentType("application/json")
                .content("{\"platform\":\"android\",\"version\":\"2.0.1\",\"mode\":\"FORCE\",\"reason\":\"yanlis surum denemesi\"}"));
        assertEquals(400, low.getStatus());
        assertEquals("VERSION_BELOW_LATEST", json(low).get("code").asText());
        assertFalse(json(low).get("message").asText().isBlank());

        // kapat
        MockHttpServletResponse off = as(full, post("/api/admin/app-versions/enforce").contentType("application/json")
                .content("{\"platform\":\"android\",\"mode\":\"OFF\",\"reason\":\"zorunluluk kaldirildi\"}"));
        assertEquals(200, off.getStatus(), off.getContentAsString());
        assertFalse(json(mvc.perform(get("/api/app/version?platform=android&version=2.0.4")).andReturn().getResponse())
                .get("updateRequired").asBoolean());
    }

    @Test
    void invalidModeAndPlatformRejected() throws Exception {
        User full = admin("full3", AdminProfile.FULL);
        MockHttpServletResponse bad = as(full, post("/api/admin/app-versions/enforce").contentType("application/json")
                .content("{\"platform\":\"android\",\"version\":\"2.0.5\",\"mode\":\"NUKE\",\"reason\":\"gecersiz kip\"}"));
        assertEquals(400, bad.getStatus());
        MockHttpServletResponse web = as(full, post("/api/admin/app-versions/enforce").contentType("application/json")
                .content("{\"platform\":\"web\",\"version\":\"2.0.5\",\"mode\":\"FORCE\",\"reason\":\"gecersiz platform\"}"));
        assertEquals(400, web.getStatus());
        assertEquals("INVALID_VERSION", json(web).get("code").asText());
    }
}
