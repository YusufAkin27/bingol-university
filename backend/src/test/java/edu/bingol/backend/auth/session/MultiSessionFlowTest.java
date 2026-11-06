package edu.bingol.backend.auth.session;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.reset;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import edu.bingol.backend.accessban.ClientContext;
import edu.bingol.backend.auth.AuthService;
import edu.bingol.backend.auth.dto.TokenResponse;
import edu.bingol.backend.auth.jwt.JwtAuthFilter;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.notification.Device;
import edu.bingol.backend.notification.DeviceRepository;
import edu.bingol.backend.notification.Notification;
import edu.bingol.backend.notification.NotificationRepository;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Base64;
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
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

/**
 * Cok oturum + Cihazlarim (H2 + tam baglam, Redis sahte): iki giris iki oturum olusturur (birbirini kapatmaz), yeni
 * cihaz diger oturumlari uyarir (uygulama ici bildirim satiri), uclar yalniz kendi oturumlarini listeler/kapatir, tek
 * cihazdan cikis yalniz o cihazin push kaydini siler. Baglam ayari ErrorEnvelopeMvcTest ile birebir ayni (onbellekteki
 * Spring baglami paylasilir: ek bellek maliyeti yok). Test ortaminda i18n paketleri yuklu degil: bildirim basligi
 * anahtarin kendisidir.
 */
@SpringBootTest(properties = {"jwt.access-ttl-minutes=15", "jwt.refresh-ttl-days=30", "app.redis.breaker-threshold=1"})
class MultiSessionFlowTest {

    private static final ObjectMapper OM = new ObjectMapper();
    private static final String PW = "Kx7-mQ2vLp9z";
    private static final String ALERT_TITLE = "notif.session.newdevice.title";

    @Autowired WebApplicationContext ctx;
    @Autowired UserRepository users;
    @Autowired AuthService auth;
    @Autowired PasswordEncoder encoder;
    @Autowired UserSessionService sessions;
    @Autowired UserSessionRepository sessionRepo;
    @Autowired DeviceRepository devices;
    @Autowired NotificationRepository notifRepo;
    @MockitoBean RateLimiter limiter;
    @MockitoBean StringRedisTemplate redis;
    MockMvc mvc;
    ValueOperations<String, String> ops;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        ops = org.mockito.Mockito.mock(ValueOperations.class);
        SetOperations<String, String> setOps = org.mockito.Mockito.mock(SetOperations.class);
        reset(redis);
        when(redis.opsForValue()).thenReturn(ops);
        when(redis.opsForSet()).thenReturn(setOps);
        when(ops.setIfAbsent(anyString(), anyString(), any(Duration.class))).thenReturn(true);
        mvc = MockMvcBuilders.webAppContextSetup(ctx).apply(springSecurity()).build();
    }

    private User account() {
        User u = new User();
        u.setEmail("cok.oturum." + UUID.randomUUID().toString().substring(0, 8) + "@bingol.edu.tr");
        u.setPasswordHash(encoder.encode(PW));
        u.setDisplayName("Cok Oturum");
        u.setEmailVerified(true);
        u.setRole(Role.USER);
        u.setStatus(UserStatus.ACTIVE);
        return users.save(u);
    }

    private static ClientContext phone(String deviceHash, String name) {
        return new ClientContext("203.0.113.9", deviceHash, "ANDROID", "2.2.0", name);
    }

    private static String hash(char c) {
        return String.valueOf(c).repeat(64);
    }

    private TokenResponse login(User u, ClientContext c) {
        return auth.login(u.getEmail(), PW, "mobile", c);
    }

    /** Access JWT'nin `sid` talebi (imza/sure denetimi olmadan yuk okunur). */
    private static String sidOf(TokenResponse t) throws Exception {
        String payload = t.accessToken().split("\\.")[1];
        JsonNode j = OM.readTree(Base64.getUrlDecoder().decode(payload));
        return j.hasNonNull("sid") ? j.get("sid").asText() : null;
    }

    /** Kullaniciya yazilmis "yeni cihaz" uyari bildirimleri (veri alaninda oturum kimligi tasir). */
    private List<Notification> alerts(User u) {
        return notifRepo.findTop500ByUserIdOrderByIdDesc(u.getId()).stream()
                .filter(n -> n.getType() == NotificationType.SYSTEM && ALERT_TITLE.equals(n.getTitle())).toList();
    }

    private MvcResult as(User u, String sid, org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder b)
            throws Exception {
        var token = new UsernamePasswordAuthenticationToken(u.getId(), null, List.of(new SimpleGrantedAuthority("ROLE_USER")));
        if (sid != null) {
            b.requestAttr(JwtAuthFilter.SESSION_ID_ATTR, sid);
        }
        return mvc.perform(b.with(authentication(token))).andReturn();
    }

    private static JsonNode json(MockHttpServletResponse r) throws Exception {
        return OM.readTree(r.getContentAsString(StandardCharsets.UTF_8));
    }

    @Test
    void secondMobileLoginDoesNotCloseTheFirstAndBothAreListed() throws Exception {
        User u = account();

        TokenResponse first = login(u, phone(hash('a'), "Pixel 8"));
        TokenResponse second = login(u, phone(hash('b'), "iPhone 15"));

        List<UserSession> open = sessions.active(u.getId());
        assertEquals(2, open.size());
        assertEquals(java.util.Set.of("iPhone 15", "Pixel 8"),
                open.stream().map(UserSession::getDeviceName).collect(java.util.stream.Collectors.toSet()));
        // her access token kendi oturum kimligini tasir
        assertNotNull(sidOf(first));
        assertNotNull(sidOf(second));
        assertFalse(sidOf(first).equals(sidOf(second)));
        assertEquals("203.0.*.*", open.get(0).getIpMasked(), "ham IP degil, maskeli");
    }

    @Test
    void newDeviceLoginNotifiesTheOthersButFirstLoginAndKnownDeviceDoNot() throws Exception {
        User u = account();

        login(u, phone(hash('a'), "Pixel 8"));
        assertEquals(0, alerts(u).size(), "ilk giris: baska oturum yok");

        String sidB = sidOf(login(u, phone(hash('b'), "iPhone 15")));
        assertEquals(1, alerts(u).size());
        assertTrue(alerts(u).get(0).getData().contains(sidB), "bildirim yeni oturumu isaret eder");
        assertTrue(alerts(u).get(0).getData().contains("devices"), "Cihazlarim'a yonlendirir");

        login(u, phone(hash('b'), "iPhone 15")); // ayni cihaz yeniden girdi: bilinen cihaz
        assertEquals(1, alerts(u).size());
    }

    @Test
    void webClientWithoutDeviceIdIsRecognisedByNameAndMaskedIp() {
        User u = account();
        login(u, phone(hash('a'), "Pixel 8"));
        ClientContext chrome = new ClientContext("198.51.100.4", null, "WEB", null, "Chrome / Windows");

        auth.login(u.getEmail(), PW, "web", chrome);
        assertEquals(1, alerts(u).size());

        auth.login(u.getEmail(), PW, "web", chrome); // ayni tarayici + ayni agdan yeniden giris: bilinen
        assertEquals(1, alerts(u).size());

        auth.login(u.getEmail(), PW, "web", new ClientContext("198.51.100.4", null, "WEB", null, "Firefox / Linux"));
        assertEquals(2, alerts(u).size(), "baska tarayici yeni sayilir");
    }

    @Test
    void sameDeviceDedupeWindowSuppressesASecondAlert() {
        User u = account();
        login(u, phone(hash('a'), "Pixel 8"));
        when(ops.setIfAbsent(anyString(), anyString(), any(Duration.class))).thenReturn(false); // 10 dk icinde ikinci

        login(u, phone(hash('c'), "Tablet"));

        assertEquals(0, alerts(u).size());
    }

    @Test
    void listMarksTheCallersSessionAsCurrentAndHidesOtherUsersSessions() throws Exception {
        User u = account();
        User other = account();
        String sidA = sidOf(login(u, phone(hash('a'), "Pixel 8")));
        login(u, phone(hash('b'), "iPhone 15"));
        login(other, phone(hash('d'), "Baska Kisi"));

        JsonNode body = json(as(u, sidA, MockMvcRequestBuilders.get("/api/auth/sessions")).getResponse());

        assertEquals(2, body.size());
        assertTrue(body.get(0).get("current").asBoolean(), "bu cihaz basta");
        assertEquals(sidA, body.get(0).get("id").asText());
        assertEquals("Pixel 8", body.get(0).get("deviceName").asText());
        assertEquals("ANDROID", body.get(0).get("platform").asText());
        assertFalse(body.get(1).get("current").asBoolean());
        assertFalse(body.toString().contains("Baska Kisi"));
        assertFalse(body.toString().contains("203.0.113.9"), "ham IP sizmaz");
    }

    @Test
    void deleteClosesOnlyThatSessionAndOnlyItsPushDevice() throws Exception {
        User u = account();
        String sidA = sidOf(login(u, phone(hash('a'), "Pixel 8")));
        String sidB = sidOf(login(u, phone(hash('b'), "iPhone 15")));
        Device da = device(u, "tok-a-" + UUID.randomUUID(), sidA);
        Device db = device(u, "tok-b-" + UUID.randomUUID(), sidB);

        MvcResult res = as(u, sidA, MockMvcRequestBuilders.delete("/api/auth/sessions/" + sidB));

        assertEquals(204, res.getResponse().getStatus());
        verify(ops).set(eq(JwtAuthFilter.SESSION_REVOKED_KEY_PREFIX + sidB), anyString(), any(Duration.class));
        assertEquals(List.of(sidA), sessions.active(u.getId()).stream().map(UserSession::getSid).toList());
        assertNotNull(sessionRepo.findById(sidB).orElseThrow().getRevokedAt());
        // push: yalniz kapatilan oturumdan kaydolmus cihaz silinir, diger cihaz bildirim almaya devam eder
        assertTrue(devices.findById(da.getId()).isPresent());
        assertFalse(devices.findById(db.getId()).isPresent());
    }

    @Test
    void deleteOfSomeoneElsesOrUnknownSessionIs404WithoutRevealingExistence() throws Exception {
        User u = account();
        User other = account();
        String sidOther = sidOf(login(other, phone(hash('d'), "Baska")));
        login(u, phone(hash('a'), "Pixel 8"));

        MvcResult stolen = as(u, null, MockMvcRequestBuilders.delete("/api/auth/sessions/" + sidOther));
        MvcResult junk = as(u, null, MockMvcRequestBuilders.delete("/api/auth/sessions/not-a-sid"));

        assertEquals(404, stolen.getResponse().getStatus());
        assertEquals("SESSION_NOT_FOUND", json(stolen.getResponse()).get("code").asText());
        assertEquals(404, junk.getResponse().getStatus());
        verify(ops, never()).set(org.mockito.ArgumentMatchers.startsWith(JwtAuthFilter.SESSION_REVOKED_KEY_PREFIX),
                anyString(), any(Duration.class));
        assertEquals(1, sessions.active(other.getId()).size(), "baskasinin oturumu acik kalir");
    }

    @Test
    void anonymousCannotListOrDelete() throws Exception {
        assertEquals(401, mvc.perform(MockMvcRequestBuilders.get("/api/auth/sessions")).andReturn().getResponse().getStatus());
        assertEquals(401, mvc.perform(MockMvcRequestBuilders.delete("/api/auth/sessions/abc")).andReturn().getResponse().getStatus());
    }

    @Test
    void logoutAllEventClosesEveryRecordOfTheUserButNotOthers() {
        User u = account();
        User other = account();
        login(u, phone(hash('a'), "Pixel 8"));
        login(u, phone(hash('b'), "iPhone 15"));
        login(other, phone(hash('d'), "Baska"));

        sessions.onSessionsRevoked(new edu.bingol.backend.auth.token.SessionsRevokedEvent(u.getId()));

        assertEquals(0, sessions.active(u.getId()).size());
        assertEquals(1, sessions.active(other.getId()).size());
    }

    @Test
    void refreshKeepsTheSidAndAdoptsLegacyChains() throws Exception {
        User u = account();
        String sid = sidOf(login(u, phone(hash('a'), "Pixel 8")));
        UserSession before = sessionRepo.findById(sid).orElseThrow();

        String same = sessions.refreshed(u.getId(), sid, "mobile", before.getAuthTimeMs(), phone(hash('a'), "Pixel 8"));
        String adopted = sessions.refreshed(u.getId(), null, "mobile", 0L, phone(hash('e'), "Eski Telefon"));

        assertEquals(sid, same);
        assertNotNull(adopted);
        assertFalse(adopted.equals(sid));
        assertEquals(2, sessions.active(u.getId()).size());
        assertTrue(sessionRepo.findById(sid).orElseThrow().getLastUsedAt().compareTo(before.getLastUsedAt()) >= 0);
    }

    private Device device(User u, String token, String sid) {
        Device d = new Device();
        d.setUserId(u.getId());
        d.setFcmToken(token);
        d.setPlatform("ANDROID");
        d.setSessionId(sid);
        return devices.save(d);
    }
}
