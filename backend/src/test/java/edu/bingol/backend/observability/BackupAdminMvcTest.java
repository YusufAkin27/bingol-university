package edu.bingol.backend.observability;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import edu.bingol.backend.admin.rbac.AdminProfile;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

/** GET /api/admin/system/backup: yetki (system.read), yanit biçimi, eski dosya uyumu; /overview bozulmaz. */
@SpringBootTest(properties = "app.observability.backup-status-file=target/backup-admin-mvc/last-success.json")
class BackupAdminMvcTest {

    private static final ObjectMapper OM = new ObjectMapper();
    private static final Path STATUS = Path.of("target", "backup-admin-mvc", "last-success.json");

    @Autowired WebApplicationContext ctx;
    @Autowired UserRepository users;
    @MockitoBean RateLimiter limiter;
    @MockitoBean StringRedisTemplate redis;
    MockMvc mvc;

    @BeforeEach
    void setUp() throws Exception {
        mvc = MockMvcBuilders.webAppContextSetup(ctx).apply(springSecurity()).build();
        Files.createDirectories(STATUS.getParent());
        Files.deleteIfExists(STATUS);
        Files.deleteIfExists(STATUS.resolveSibling("last-failure.json"));
    }

    private User admin(AdminProfile profile) {
        User u = new User();
        u.setEmail("bk." + UUID.randomUUID().toString().substring(0, 8) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName("bk");
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
    void fullAndViewerReadSupportAndEditorAreDenied() throws Exception {
        for (AdminProfile p : AdminProfile.values()) {
            boolean allowed = p == AdminProfile.FULL || p == AdminProfile.VIEWER;
            int status = as(admin(p), get("/api/admin/system/backup")).getStatus();
            assertThat(status).as(p.name()).isEqualTo(allowed ? 200 : 403);
        }
    }

    @Test
    void writeVerbsDoNotExist() throws Exception {
        MockHttpServletResponse r = as(admin(AdminProfile.FULL), post("/api/admin/system/backup"));
        assertThat(r.getStatus()).isIn(404, 405);
    }

    @Test
    void returnsContractShapeFromStatusFile() throws Exception {
        Files.writeString(STATUS, "{\"lastSuccessAt\":\"2026-11-01T10:05:09Z\",\"file\":\"20261101T130500\","
                + "\"local\":{\"count\":3,\"bytes\":1500000,\"oldestAt\":\"2026-11-01T08:05:00Z\"},"
                + "\"remote\":{\"configured\":true,\"kind\":\"drive\",\"name\":\"gdrive\","
                + "\"lastSuccessAt\":\"2026-11-01T00:40:12Z\",\"lastVerifiedAt\":\"2026-11-01T00:40:30Z\","
                + "\"lastError\":null,\"bytes\":7340032,\"count\":6},"
                + "\"schedule\":{\"cron\":\"5 * * * *\",\"verifyCron\":\"30 4 * * 0\"},"
                + "\"retention\":{\"localDaily\":3,\"localWeekly\":0,\"localMonthly\":0,"
                + "\"remoteDaily\":7,\"remoteWeekly\":4,\"remoteMonthly\":6}}");
        JsonNode j = json(as(admin(AdminProfile.VIEWER), get("/api/admin/system/backup")));
        assertThat(j.fieldNames()).toIterable().contains("local", "remote", "lastSuccessAt", "lastStatus", "schedule", "retention");
        assertThat(j.get("lastSuccessAt").asText()).isEqualTo("2026-11-01T10:05:09Z");
        assertThat(j.get("lastStatus").asText()).isEqualTo("OK");
        assertThat(j.at("/local/count").asLong()).isEqualTo(3);
        assertThat(j.at("/local/oldestAt").asText()).isEqualTo("2026-11-01T08:05:00Z");
        assertThat(j.at("/remote/configured").asBoolean()).isTrue();
        assertThat(j.at("/remote/kind").asText()).isEqualTo("drive");
        assertThat(j.at("/remote/name").asText()).isEqualTo("gdrive");
        assertThat(j.at("/remote/lastVerifiedAt").asText()).isEqualTo("2026-11-01T00:40:30Z");
        assertThat(j.at("/remote/lastError").isNull()).isTrue();
        assertThat(j.at("/remote/bytes").asLong()).isEqualTo(7340032L);
        assertThat(j.at("/retention/remoteMonthly").asInt()).isEqualTo(6);
        assertThat(j.at("/schedule/cron").asText()).isEqualTo("5 * * * *");
        assertThat(j.at("/schedule/verifyCron").asText()).isEqualTo("30 4 * * 0");
    }

    @Test
    void legacyFileAndMissingFileGiveNullsAndNotConfigured() throws Exception {
        Files.writeString(STATUS, "{\"lastSuccessAt\":\"2026-10-28T10:52:20Z\",\"sizeBytes\":485280}");
        JsonNode legacy = json(as(admin(AdminProfile.FULL), get("/api/admin/system/backup")));
        assertThat(legacy.at("/remote/configured").asBoolean()).isFalse();
        assertThat(legacy.at("/remote/name").isNull()).isTrue();
        assertThat(legacy.at("/local/count").isNull()).isTrue();
        assertThat(legacy.at("/retention/localDaily").isNull()).isTrue();
        assertThat(legacy.get("lastSuccessAt").asText()).isEqualTo("2026-10-28T10:52:20Z");

        Files.delete(STATUS);
        MockHttpServletResponse missing = as(admin(AdminProfile.FULL), get("/api/admin/system/backup"));
        assertThat(missing.getStatus()).isEqualTo(200);
        JsonNode m = json(missing);
        assertThat(m.get("lastSuccessAt").isNull()).isTrue();
        assertThat(m.get("lastStatus").isNull()).isTrue();
        assertThat(m.at("/remote/configured").asBoolean()).isFalse();
    }

    @Test
    void corruptOrHostileStatusFilesNeverBreakTheEndpointNor500() throws Exception {
        for (String body : new String[] {"{not json", "[]", "null", "{\"remote\":\"x\",\"local\":5}", "\u0000\u0001garbage",
                "{\"lastSuccessAt\":{\"a\":1},\"remote\":{\"configured\":true,\"name\":\"../../etc\",\"lastError\":\"\\u0007bad\"}}"}) {
            Files.writeString(STATUS, body);
            MockHttpServletResponse r = as(admin(AdminProfile.FULL), get("/api/admin/system/backup"));
            assertThat(r.getStatus()).as(body).isEqualTo(200);
            JsonNode j = json(r);
            assertThat(j.has("remote")).as(body).isTrue();
            assertThat(j.at("/remote/name").isNull() || !j.at("/remote/name").asText().contains("/")).as(body).isTrue();
            assertThat(as(admin(AdminProfile.FULL), get("/api/admin/system/overview")).getStatus()).as(body).isEqualTo(200);
        }
    }

    @Test
    void remoteBackupFreshnessIsAnIndicatorWarnAfter30AndCritAfter36Hours() throws Exception {
        String ok = java.time.Instant.now().minus(java.time.Duration.ofHours(2)).toString();
        String warn = java.time.Instant.now().minus(java.time.Duration.ofHours(31)).toString();
        String crit = java.time.Instant.now().minus(java.time.Duration.ofHours(40)).toString();
        String head = "{\"lastSuccessAt\":\"" + java.time.Instant.now() + "\",\"remote\":{\"configured\":true,\"kind\":\"drive\",\"name\":\"gdrive\"";
        Files.writeString(STATUS, head + ",\"lastSuccessAt\":\"" + ok + "\"}}");
        assertThat(remoteIndicator().get("status").asText()).isEqualTo("OK");
        Files.writeString(STATUS, head + ",\"lastSuccessAt\":\"" + warn + "\"}}");
        assertThat(remoteIndicator().get("status").asText()).isEqualTo("WARN");
        Files.writeString(STATUS, head + ",\"lastSuccessAt\":\"" + crit + "\"}}");
        JsonNode c = remoteIndicator();
        assertThat(c.get("status").asText()).isEqualTo("CRIT");
        assertThat(c.at("/threshold/crit").asInt()).isEqualTo(36);
        // hic basarili yukleme yok + hata kaydi: CRIT; hata yok: UNKNOWN (henuz calismadi)
        Files.writeString(STATUS, head + ",\"lastSuccessAt\":null,\"lastError\":\"rclone.conf icinde yok\"}}");
        assertThat(remoteIndicator().get("status").asText()).isEqualTo("CRIT");
        Files.writeString(STATUS, head + ",\"lastSuccessAt\":null}}");
        assertThat(remoteIndicator().get("status").asText()).isEqualTo("UNKNOWN");
        // yapilandirilmamis: uyari uretmez
        Files.writeString(STATUS, "{\"lastSuccessAt\":\"" + java.time.Instant.now() + "\",\"remote\":{\"configured\":false}}");
        assertThat(remoteIndicator().get("status").asText()).isEqualTo("UNKNOWN");
    }

    private JsonNode remoteIndicator() throws Exception {
        MockHttpServletResponse r = as(admin(AdminProfile.FULL), get("/api/admin/system/overview"));
        assertThat(r.getStatus()).isEqualTo(200);
        return json(r).at("/indicators/backup.remote");
    }

    @Test
    void overviewKeepsReportingBackupAgeIndicator() throws Exception {
        Files.writeString(STATUS, "{\"lastSuccessAt\":\"" + java.time.Instant.now() + "\",\"remote\":{\"configured\":false}}");
        MockHttpServletResponse r = as(admin(AdminProfile.FULL), get("/api/admin/system/overview"));
        assertThat(r.getStatus()).isEqualTo(200);
        JsonNode ind = json(r).at("/indicators/backup.age");
        assertThat(ind.isMissingNode()).isFalse();
        assertThat(ind.get("status").asText()).isEqualTo("OK");
    }
}
