package edu.bingol.backend.notification.admin;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import edu.bingol.backend.admin.AdminReasonFilter;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.notification.Device;
import edu.bingol.backend.notification.DeviceRepository;
import edu.bingol.backend.notification.Notification;
import edu.bingol.backend.notification.NotificationRepository;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.notification.campaign.PushCampaign;
import edu.bingol.backend.notification.campaign.PushCampaignRepository;
import edu.bingol.backend.notification.fcm.PushMessage;
import edu.bingol.backend.notification.outbox.PushOutbox;
import edu.bingol.backend.notification.outbox.PushOutboxRepository;
import edu.bingol.backend.notification.outbox.PushOutboxService;
import edu.bingol.backend.notification.outbox.PushOutboxStatus;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
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
 * Yonetici push altyapisi HTTP sozlesmesi (P14, H2): yalniz ADMIN, yuk/ham token/tam kimlik ASLA donmez, retry/cancel durum
 * kurallari, toplu kismi basari, cihaz ozeti, kampanya hata gruplari, bildirim istatistikleri.
 */
@SpringBootTest
class PushOpsControllerTest {

    private static final ObjectMapper OM = new ObjectMapper();
    private static final String SECRET_TITLE = "GIZLI-BASLIK-ZXQ";
    private static final String SECRET_BODY = "GIZLI-GOVDE-ZXQ";

    @Autowired WebApplicationContext ctx;
    @Autowired PushOutboxRepository outbox;
    @Autowired PushOutboxService outboxService;
    @Autowired DeviceRepository devices;
    @Autowired UserRepository users;
    @Autowired NotificationRepository notifications;
    @Autowired PushCampaignRepository campaigns;
    @MockitoBean RateLimiter limiter;
    MockMvc mvc;

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.webAppContextSetup(ctx).addFilters(ctx.getBean(AdminReasonFilter.class))
                .apply(springSecurity()).build();
        outbox.deleteAll();
        devices.deleteAll();
        notifications.deleteAll();
    }

    private static UsernamePasswordAuthenticationToken admin() {
        return new UsernamePasswordAuthenticationToken(990201L, null, List.of(new SimpleGrantedAuthority("ROLE_ADMIN")));
    }

    private static UsernamePasswordAuthenticationToken plainUser() {
        return new UsernamePasswordAuthenticationToken(990202L, null, List.of(new SimpleGrantedAuthority("ROLE_USER")));
    }

    private MvcResult asAdmin(MockHttpServletRequestBuilder b) throws Exception {
        return mvc.perform(b.with(authentication(admin())).header("X-Admin-Reason", "deneme sebebi")).andReturn();
    }

    private static JsonNode json(MvcResult r, int status) throws Exception {
        MockHttpServletResponse res = r.getResponse();
        assertEquals(status, res.getStatus(), res.getContentAsString());
        String body = res.getContentAsString();
        return body.isEmpty() ? null : OM.readTree(body);
    }

    private User user() {
        User u = new User();
        u.setEmail("p14." + UUID.randomUUID().toString().substring(0, 8) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName("Push Test");
        u.setEmailVerified(true);
        return users.save(u);
    }

    private Device device(String platform, String version, Instant lastSeen) {
        Device d = new Device();
        d.setUserId(user().getId());
        d.setFcmToken("tok-" + UUID.randomUUID());
        d.setPlatform(platform);
        d.setAppVersion(version);
        d.setLastSeenAt(lastSeen);
        return devices.save(d);
    }

    private PushOutbox row(Device d, PushOutboxStatus status, Long campaignId, String errorCode) {
        PushMessage m = new PushMessage(SECRET_TITLE, SECRET_BODY, Map.of("campaignId", String.valueOf(campaignId)),
                null, null, null, "ANNOUNCEMENT", null, false);
        PushOutbox o = new PushOutbox();
        o.setUserId(d.getUserId());
        o.setDeviceId(d.getId());
        o.setFcmTokenHash(edu.bingol.backend.common.Hashing.sha256(d.getFcmToken()));
        o.setPayloadJson("{\"title\":\"" + SECRET_TITLE + "\",\"body\":\"" + SECRET_BODY + "\"}");
        o.setStatus(status);
        o.setMsgType(m.category());
        o.setCampaignId(campaignId);
        o.setErrorCode(errorCode);
        o.setAttempts(status == PushOutboxStatus.DEAD ? 6 : 0);
        o.setLastError(errorCode == null ? null : "hata: " + errorCode);
        return outbox.save(o);
    }

    // ---- yetki ----

    @Test
    void onlyAdminMayCallAndAnonymousIsRejected() throws Exception {
        for (String url : List.of("/api/admin/push/outbox", "/api/admin/push/outbox/1", "/api/admin/push/devices/summary",
                "/api/admin/push/campaigns/1/failures", "/api/admin/notifications/stats")) {
            assertEquals(401, mvc.perform(get(url)).andReturn().getResponse().getStatus(), url);
            assertEquals(403, mvc.perform(get(url).with(authentication(plainUser()))).andReturn().getResponse().getStatus(), url);
        }
        assertEquals(403, mvc.perform(post("/api/admin/push/outbox/1/retry").with(authentication(plainUser())))
                .andReturn().getResponse().getStatus());
        assertEquals(403, mvc.perform(post("/api/admin/push/outbox/bulk").with(authentication(plainUser()))
                .contentType("application/json").content("{\"action\":\"RETRY\",\"ids\":[1]}"))
                .andReturn().getResponse().getStatus());
    }

    // ---- maskeleme / yuk ----

    @Test
    void listAndDetailNeverExposePayloadTokenOrFullIdentity() throws Exception {
        Device d = device("ANDROID", "1.0.0", Instant.now());
        PushOutbox o = row(d, PushOutboxStatus.DEAD, 7L, "UNREGISTERED");
        String fullHash = o.getFcmTokenHash();

        MvcResult list = asAdmin(get("/api/admin/push/outbox"));
        String listBody = list.getResponse().getContentAsString();
        JsonNode j = json(list, 200);
        assertEquals(1, j.get("totalItems").asInt());
        JsonNode item = j.get("items").get(0);
        assertEquals("DEAD", item.get("status").asText());
        assertEquals("UNREGISTERED", item.get("errorCode").asText());
        assertEquals("ANNOUNCEMENT", item.get("type").asText());
        assertEquals(7, item.get("campaignId").asInt());
        assertEquals(fullHash.substring(0, 8) + "...", item.get("targetRef").asText());
        assertFalse(item.get("userRef").asText().equals(String.valueOf(d.getUserId())), "kullanici kimligi maskeli olmali");
        assertTrue(item.get("userRef").asText().contains("***"));

        MvcResult detail = asAdmin(get("/api/admin/push/outbox/" + o.getId()));
        String detailBody = detail.getResponse().getContentAsString();
        JsonNode dj = json(detail, 200);
        assertEquals(6, dj.get("maxAttempts").asInt());
        assertEquals(6, dj.get("attempts").asInt());
        assertNotNull(dj.get("lastError"));
        assertTrue(dj.get("canRetry").asBoolean());
        assertFalse(dj.get("canCancel").asBoolean());

        for (String body : List.of(listBody, detailBody)) {
            assertFalse(body.contains(SECRET_TITLE), "yuk basligi donmemeli");
            assertFalse(body.contains(SECRET_BODY), "yuk govdesi donmemeli");
            assertFalse(body.contains("payload"), "yuk alani donmemeli");
            assertFalse(body.contains(d.getFcmToken()), "ham token donmemeli");
            assertFalse(body.contains(fullHash), "tam token ozeti donmemeli");
            assertFalse(body.contains("\"userId\""), "ham kullanici kimligi alani donmemeli");
        }
    }

    @Test
    void listFiltersByStatusTypeCampaignAndPaginates() throws Exception {
        Device d = device("IOS", "1.0.0", Instant.now());
        for (int i = 0; i < 5; i++) {
            row(d, PushOutboxStatus.DEAD, 1L, "UNREGISTERED");
        }
        row(d, PushOutboxStatus.PENDING, 2L, null);
        row(d, PushOutboxStatus.SENT, null, null);

        assertEquals(5, json(asAdmin(get("/api/admin/push/outbox").param("status", "dead")), 200).get("totalItems").asInt());
        assertEquals(1, json(asAdmin(get("/api/admin/push/outbox").param("campaignId", "2")), 200).get("totalItems").asInt());
        assertEquals(7, json(asAdmin(get("/api/admin/push/outbox").param("type", "announcement")), 200).get("totalItems").asInt());
        JsonNode page = json(asAdmin(get("/api/admin/push/outbox").param("size", "3").param("page", "1")), 200);
        assertEquals(3, page.get("items").size());
        assertEquals(3, page.get("totalPages").asInt());
        // bugunun tarih araligi hepsini, dunku aralik hicbirini getirir
        String today = java.time.LocalDate.now(java.time.ZoneId.of("Europe/Istanbul")).toString();
        assertEquals(7, json(asAdmin(get("/api/admin/push/outbox").param("from", today).param("to", today)), 200)
                .get("totalItems").asInt());
        String past = java.time.LocalDate.now(java.time.ZoneId.of("Europe/Istanbul")).minusDays(3).toString();
        assertEquals(0, json(asAdmin(get("/api/admin/push/outbox").param("from", past).param("to", past)), 200)
                .get("totalItems").asInt());
        assertEquals(400, asAdmin(get("/api/admin/push/outbox").param("status", "NOPE")).getResponse().getStatus());
        assertEquals(400, asAdmin(get("/api/admin/push/outbox").param("type", "NOPE")).getResponse().getStatus());
    }

    @Test
    void detailOfMissingRecordIs404() throws Exception {
        assertEquals("PUSHADMIN_OUTBOX_NOT_FOUND",
                json(asAdmin(get("/api/admin/push/outbox/987654321")), 404).get("code").asText());
    }

    // ---- retry / cancel kurallari ----

    @Test
    void retryRequeuesDeadFailedAndCancelledButNotSentPendingOrSending() throws Exception {
        Device d = device("ANDROID", "1.0.0", Instant.now());
        PushOutbox dead = row(d, PushOutboxStatus.DEAD, null, "UNREGISTERED");
        dead.setCreatedAt(Instant.now().minus(Duration.ofDays(2)));
        outbox.save(dead);
        PushOutbox cancelled = row(d, PushOutboxStatus.CANCELLED, null, "ADMIN_CANCELLED");
        PushOutbox sent = row(d, PushOutboxStatus.SENT, null, null);
        PushOutbox pending = row(d, PushOutboxStatus.PENDING, null, null);
        PushOutbox sending = row(d, PushOutboxStatus.SENDING, null, null);

        JsonNode ok = json(asAdmin(post("/api/admin/push/outbox/" + dead.getId() + "/retry")), 200);
        assertEquals("PENDING", ok.get("status").asText());
        PushOutbox again = outbox.findById(dead.getId()).orElseThrow();
        assertEquals(PushOutboxStatus.PENDING, again.getStatus());
        assertEquals(0, again.getAttempts());
        assertTrue(again.getCreatedAt().isAfter(Instant.now().minus(Duration.ofMinutes(1))), "omur yeniden baslar");
        assertEquals(PushOutboxStatus.PENDING, requeue(cancelled));

        for (PushOutbox bad : List.of(sent, pending, sending)) {
            JsonNode err = json(asAdmin(post("/api/admin/push/outbox/" + bad.getId() + "/retry")), 409);
            assertEquals("PUSHADMIN_STATE_CONFLICT", err.get("code").asText());
        }
        assertEquals("PUSHADMIN_OUTBOX_NOT_FOUND",
                json(asAdmin(post("/api/admin/push/outbox/987654321/retry")), 404).get("code").asText());
    }

    private PushOutboxStatus requeue(PushOutbox o) throws Exception {
        json(asAdmin(post("/api/admin/push/outbox/" + o.getId() + "/retry")), 200);
        return outbox.findById(o.getId()).orElseThrow().getStatus();
    }

    @Test
    void cancelOnlyUnsentPendingOrFailed() throws Exception {
        Device d = device("ANDROID", "1.0.0", Instant.now());
        PushOutbox pending = row(d, PushOutboxStatus.PENDING, null, null);
        PushOutbox failed = row(d, PushOutboxStatus.FAILED, null, "UNAVAILABLE");
        PushOutbox sending = row(d, PushOutboxStatus.SENDING, null, null);
        PushOutbox sent = row(d, PushOutboxStatus.SENT, null, null);
        PushOutbox dead = row(d, PushOutboxStatus.DEAD, null, "UNREGISTERED");

        assertEquals("CANCELLED",
                json(asAdmin(post("/api/admin/push/outbox/" + pending.getId() + "/cancel")), 200).get("status").asText());
        PushOutbox c = outbox.findById(pending.getId()).orElseThrow();
        assertEquals(PushOutboxStatus.CANCELLED, c.getStatus());
        assertEquals("ADMIN_CANCELLED", c.getErrorCode());
        json(asAdmin(post("/api/admin/push/outbox/" + failed.getId() + "/cancel")), 200);

        for (PushOutbox bad : List.of(sending, sent, dead)) {
            assertEquals("PUSHADMIN_STATE_CONFLICT",
                    json(asAdmin(post("/api/admin/push/outbox/" + bad.getId() + "/cancel")), 409).get("code").asText());
            assertEquals(bad.getStatus(), outbox.findById(bad.getId()).orElseThrow().getStatus(), "durum bozulmamali");
        }
        // iptal edilen ikinci kez iptal edilemez
        assertEquals(409, asAdmin(post("/api/admin/push/outbox/" + pending.getId() + "/cancel")).getResponse().getStatus());
    }

    @Test
    void bulkGivesPartialSuccessAndEnforcesLimits() throws Exception {
        Device d = device("ANDROID", "1.0.0", Instant.now());
        PushOutbox p1 = row(d, PushOutboxStatus.PENDING, null, null);
        PushOutbox p2 = row(d, PushOutboxStatus.PENDING, null, null);
        PushOutbox sent = row(d, PushOutboxStatus.SENT, null, null);

        String body = "{\"action\":\"CANCEL\",\"reason\":\"toplu deneme\",\"ids\":[" + p1.getId() + "," + p2.getId() + ","
                + p1.getId() + "," + sent.getId() + ",987654321]}";
        JsonNode res = json(asAdmin(post("/api/admin/push/outbox/bulk").contentType("application/json").content(body)), 200);
        assertEquals(4, res.get("requested").asInt(), "tekrarlanan kimlik bir sayilir");
        assertEquals(2, res.get("succeeded").asInt());
        assertEquals(2, res.get("failed").size());
        Map<Long, String> failures = new java.util.HashMap<>();
        res.get("failed").forEach(f -> failures.put(f.get("id").asLong(), f.get("code").asText()));
        assertEquals("INVALID_STATE", failures.get(sent.getId()));
        assertEquals("NOT_FOUND", failures.get(987654321L));
        assertEquals(PushOutboxStatus.CANCELLED, outbox.findById(p1.getId()).orElseThrow().getStatus());
        assertEquals(PushOutboxStatus.SENT, outbox.findById(sent.getId()).orElseThrow().getStatus());

        // toplu yeniden deneme: iptal edilenler geri gelir
        String retry = "{\"action\":\"RETRY\",\"reason\":\"toplu deneme\",\"ids\":[" + p1.getId() + "," + p2.getId() + "]}";
        JsonNode r2 = json(asAdmin(post("/api/admin/push/outbox/bulk").contentType("application/json").content(retry)), 200);
        assertEquals(2, r2.get("succeeded").asInt());
        assertEquals(PushOutboxStatus.PENDING, outbox.findById(p1.getId()).orElseThrow().getStatus());

        // sinirlar
        StringBuilder many = new StringBuilder("{\"action\":\"RETRY\",\"ids\":[");
        for (int i = 1; i <= 201; i++) {
            many.append(i).append(i < 201 ? "," : "");
        }
        many.append("]}");
        assertEquals("PUSHADMIN_BULK_INVALID",
                json(asAdmin(post("/api/admin/push/outbox/bulk").contentType("application/json").content(many.toString())), 400)
                        .get("code").asText());
        assertEquals(400, asAdmin(post("/api/admin/push/outbox/bulk").contentType("application/json")
                .content("{\"action\":\"RETRY\",\"ids\":[]}")).getResponse().getStatus());
        assertEquals(400, asAdmin(post("/api/admin/push/outbox/bulk").contentType("application/json")
                .content("{\"action\":\"EXPLODE\",\"ids\":[1]}")).getResponse().getStatus());
    }

    // ---- cihaz ozeti ----

    @Test
    void deviceSummaryHasOnlyAggregates() throws Exception {
        Instant now = Instant.now();
        device("ANDROID", "2.0.0", now);
        device("ANDROID", "2.0.0", now.minus(Duration.ofDays(3)));
        device("IOS", "2.1.0", now.minus(Duration.ofDays(40)));
        device("web", null, now.minus(Duration.ofDays(10)));
        device("WINDOWS", "1.0.0", now);

        MvcResult r = asAdmin(get("/api/admin/push/devices/summary"));
        String body = r.getResponse().getContentAsString();
        JsonNode j = json(r, 200);
        assertEquals(5, j.get("totalTokens").asInt());
        assertEquals(5, j.get("usersWithDevice").asInt());
        assertEquals(2, j.get("byPlatform").get("android").asInt());
        assertEquals(1, j.get("byPlatform").get("ios").asInt());
        assertEquals(1, j.get("byPlatform").get("web").asInt());
        assertEquals(1, j.get("byPlatform").get("other").asInt());
        assertEquals(3, j.get("activeLast7d").asInt());
        assertEquals(1, j.get("staleOver30d").asInt());
        JsonNode top = j.get("byAppVersion").get(0);
        assertEquals("2.0.0", top.get("version").asText());
        assertEquals(2, top.get("count").asInt());
        boolean hasUnknown = false;
        for (JsonNode v : j.get("byAppVersion")) {
            hasUnknown |= "unknown".equals(v.get("version").asText());
        }
        assertTrue(hasUnknown);
        assertFalse(body.contains("tok-"), "token donmemeli");
        assertFalse(body.contains("fcmToken"));
    }

    // ---- kampanya hatalari ----

    @Test
    void campaignFailuresGroupByErrorCodeWithoutRecipients() throws Exception {
        PushCampaign c = new PushCampaign();
        c.setCreatedBy(1L);
        c.setAudienceType(PushCampaign.AudienceType.ALL);
        c.setTitleTr("Baslik");
        c.setBodyTr("Govde");
        c.setScheduledAt(Instant.now());
        c = campaigns.save(c);
        Device d = device("ANDROID", "1.0.0", Instant.now());
        for (int i = 0; i < 3; i++) {
            row(d, PushOutboxStatus.DEAD, c.getId(), "UNREGISTERED");
        }
        row(d, PushOutboxStatus.DEAD, c.getId(), "INVALID_ARGUMENT");
        row(d, PushOutboxStatus.FAILED, c.getId(), "QUOTA_EXCEEDED");
        row(d, PushOutboxStatus.DEAD, c.getId(), null);
        row(d, PushOutboxStatus.SENT, c.getId(), null);
        row(d, PushOutboxStatus.DEAD, c.getId() + 1000, "UNREGISTERED"); // baska kampanya

        MvcResult r = asAdmin(get("/api/admin/push/campaigns/" + c.getId() + "/failures"));
        String body = r.getResponse().getContentAsString();
        JsonNode j = json(r, 200);
        assertTrue(j.get("linked").asBoolean());
        assertEquals(1, j.get("totals").get("SENT").asInt());
        assertEquals(5, j.get("totals").get("DEAD").asInt());
        assertEquals(1, j.get("totals").get("FAILED").asInt());
        JsonNode g0 = j.get("groups").get(0);
        assertEquals("UNREGISTERED", g0.get("errorCode").asText());
        assertEquals(3, g0.get("count").asInt());
        assertEquals("DEAD", g0.get("status").asText());
        boolean unknown = false;
        for (JsonNode g : j.get("groups")) {
            unknown |= "UNKNOWN".equals(g.get("errorCode").asText());
        }
        assertTrue(unknown, "kodu olmayan kayitlar UNKNOWN grubunda");
        assertEquals(4, j.get("groups").size());
        assertFalse(j.get("truncated").asBoolean());
        assertFalse(body.contains("userRef") || body.contains("targetRef") || body.contains("userId"), "alici kimligi yok");
        assertFalse(body.contains(SECRET_TITLE));

        // baglanmamis (surum oncesi) kampanya: bos ama 200
        PushCampaign old = new PushCampaign();
        old.setCreatedBy(1L);
        old.setAudienceType(PushCampaign.AudienceType.ALL);
        old.setTitleTr("Eski");
        old.setBodyTr("Eski");
        old.setScheduledAt(Instant.now());
        old = campaigns.save(old);
        JsonNode e = json(asAdmin(get("/api/admin/push/campaigns/" + old.getId() + "/failures")), 200);
        assertFalse(e.get("linked").asBoolean());
        assertEquals(0, e.get("groups").size());

        assertEquals("CAMPAIGN_NOT_FOUND",
                json(asAdmin(get("/api/admin/push/campaigns/987654321/failures")), 404).get("code").asText());
    }

    @Test
    void enqueueLinksCampaignAndTypeFromPayload() throws Exception {
        Device d = device("ANDROID", "1.0.0", Instant.now());
        PushMessage m = new PushMessage("T", "B", Map.of("campaignId", "55"), null, null, null, "EVENT", null, false);
        assertEquals(1, outboxService.enqueueDevices(List.of(d), m, null));
        PushOutbox o = outbox.findAll().get(0);
        assertEquals(55L, o.getCampaignId());
        assertEquals("EVENT", o.getMsgType());
        assertNull(o.getErrorCode());
    }

    // ---- bildirim kutusu istatistikleri ----

    @Test
    void notificationStatsCountsByDayAndType() throws Exception {
        User u = user();
        Instant now = Instant.now();
        notification(u, NotificationType.NEWS, now, now);
        notification(u, NotificationType.NEWS, now, null);
        notification(u, NotificationType.EVENT, now, null);
        notification(u, NotificationType.SYSTEM, now.minus(Duration.ofDays(40)), null); // pencere disi

        MvcResult r = asAdmin(get("/api/admin/notifications/stats"));
        JsonNode j = json(r, 200);
        assertEquals(14, j.get("days").asInt());
        assertEquals(14, j.get("series").size());
        assertEquals(3, j.get("created").asInt());
        assertEquals(1, j.get("read").asInt());
        assertEquals(1.0 / 3, j.get("readRate").asDouble(), 1e-9);
        assertEquals(4, j.get("totalRows").asInt());
        assertEquals(3, j.get("unreadRows").asInt());
        assertEquals("NEWS", j.get("byType").get(0).get("type").asText());
        assertEquals(2, j.get("byType").get(0).get("count").asInt());
        long inSeries = 0;
        for (JsonNode d : j.get("series")) {
            inSeries += d.get("created").asLong();
        }
        assertEquals(3, inSeries);

        assertEquals(7, json(asAdmin(get("/api/admin/notifications/stats").param("days", "7")), 200).get("series").size());
        assertEquals(30, json(asAdmin(get("/api/admin/notifications/stats").param("days", "999")), 200).get("days").asInt());
    }

    @Test
    void notificationStatsReadRateIsNullWhenNothingCreated() throws Exception {
        JsonNode j = json(asAdmin(get("/api/admin/notifications/stats")), 200);
        assertEquals(0, j.get("created").asInt());
        assertTrue(j.get("readRate").isNull());
    }

    private void notification(User u, NotificationType type, Instant createdAt, Instant readAt) {
        Notification n = new Notification();
        n.setUserId(u.getId());
        n.setType(type);
        n.setTitle("t");
        n.setCreatedAt(createdAt);
        n.setReadAt(readAt);
        notifications.save(n);
    }
}
