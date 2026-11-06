package edu.bingol.backend.auth.oauth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import edu.bingol.backend.auth.ProfileIncompleteWriteFilter;
import edu.bingol.backend.auth.token.RefreshTokenService;
import edu.bingol.backend.auth.token.SessionService;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
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
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

/**
 * HTTP sozlesmesi (H2): Google/Apple giris sekilleri, 409 OAUTH_LINK_REQUIRED govdesi, sunucu tarafi PROFILE_INCOMPLETE
 * kapisi (onboarding sonrasi acilir), baglama/kaldirma/liste, kullanici adi musaitligi. Saglayici anahtarlari YEREL.
 */
@SpringBootTest(properties = {
        "jwt.access-ttl-minutes=15", // test application.properties asil dosyanin yerine gecer: sure varsayilani 0 olurdu
        "spring.messages.basename=i18n/messages,i18n/auth,i18n/profile,i18n/ops", // cok dilli metin dogrulamasi
        "app.auth.oauth.enabled=true",
        "app.auth.oauth.google-client-ids=" + OAuthTestSupport.GOOGLE_AUD,
        "app.auth.oauth.apple-client-ids=" + OAuthTestSupport.APPLE_AUD})
class OAuthMvcTest {

    private static final ObjectMapper OM = new ObjectMapper();

    @Autowired WebApplicationContext ctx;
    @Autowired UserRepository users;
    @Autowired PasswordEncoder encoder;
    @Autowired ProfileIncompleteWriteFilter profileGate;
    @MockitoBean RateLimiter limiter;
    @MockitoBean StringRedisTemplate redis;
    @MockitoBean RefreshTokenService refresh;
    @MockitoBean SessionService sessions;
    @MockitoBean OAuthKeyProvider keys;

    final OAuthTestSupport t = new OAuthTestSupport();
    MockMvc mvc;
    String tag;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        ValueOperations<String, String> ops = org.mockito.Mockito.mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(ops);
        when(refresh.issue(anyLong(), anyString())).thenReturn("refresh-token");
        // cok oturum (V1460): giris bir oturum kimligi (sid) uretir, refresh 4 argumanli issue ile yazilir
        when(refresh.issue(anyLong(), anyString(), anyLong(), any())).thenReturn("refresh-token");
        when(keys.key(any(), eq(OAuthTestSupport.KID))).thenReturn(t.pair.getPublic());
        // MockMvc'ye HER servlet suzgeci otomatik girmez: profil kapisini guvenlik zincirinden SONRA ekle
        mvc = MockMvcBuilders.webAppContextSetup(ctx).apply(springSecurity()).addFilters(profileGate).build();
        tag = UUID.randomUUID().toString().substring(0, 8);
    }

    private static JsonNode json(MockHttpServletResponse r) throws Exception {
        return OM.readTree(r.getContentAsString(StandardCharsets.UTF_8));
    }

    private MockHttpServletResponse asUser(Long uid, MockHttpServletRequestBuilder b) throws Exception {
        var token = new UsernamePasswordAuthenticationToken(uid, null, List.of(new SimpleGrantedAuthority("ROLE_USER")));
        return mvc.perform(b.with(authentication(token))).andReturn().getResponse();
    }

    private MockHttpServletResponse googleLogin(String sub, String email, String lang) throws Exception {
        String body = "{\"idToken\":\"" + t.sign(t.googleClaims(sub, email)) + "\",\"deviceName\":\"Pixel\"}";
        return mvc.perform(post("/api/auth/oauth/google").contentType("application/json").content(body)
                .header("Accept-Language", lang)).andReturn().getResponse();
    }

    private static final String OB = "{\"firstName\":\"Ayşe\",\"lastName\":\"Yılmaz\",\"username\":\"%s\","
            + "\"facultyId\":\"muhendislik\",\"departmentId\":\"bilgisayar-muhendisligi\",\"classYear\":\"Y2\","
            + "\"acceptTerms\":true}";

    // ------------------------------------------------------------------ giris sekilleri

    @Test
    void newGoogleUserGets200WithTokensProfileCompletedFalseAndIsNewUserTrue() throws Exception {
        MockHttpServletResponse r = googleLogin("m-" + tag, "yeni." + tag + "@gmail.com", "tr");

        assertEquals(200, r.getStatus(), r.getContentAsString());
        JsonNode j = json(r);
        assertTrue(j.get("accessToken").asText().length() > 20);
        assertEquals("refresh-token", j.get("refreshToken").asText());
        assertEquals("Bearer", j.get("tokenType").asText());
        assertTrue(j.get("expiresInSeconds").asLong() > 0);
        assertFalse(j.get("profileCompleted").asBoolean());
        assertTrue(j.get("isNewUser").asBoolean());
        assertFalse(j.has("emailVerified"), "OAuth hesabi dogrulanmis acilir: ertelenmis isareti yok");

        MockHttpServletResponse again = googleLogin("m-" + tag, "yeni." + tag + "@gmail.com", "tr");
        assertEquals(200, again.getStatus());
        assertFalse(json(again).get("isNewUser").asBoolean());
        assertFalse(json(again).get("profileCompleted").asBoolean());
    }

    @Test
    void appleLoginRequiresTheNonceAndStoresTheClientName() throws Exception {
        String relay = "r" + tag + "@privaterelay.appleid.com";
        String token = t.sign(t.appleClaims("ap-" + tag, relay, "ham-nonce"));
        String ok = "{\"identityToken\":\"" + token + "\",\"nonce\":\"ham-nonce\",\"firstName\":\"Mehmet\",\"lastName\":\"Demir\"}";

        MockHttpServletResponse r = mvc.perform(post("/api/auth/oauth/apple").contentType("application/json").content(ok))
                .andReturn().getResponse();
        assertEquals(200, r.getStatus(), r.getContentAsString());
        assertTrue(json(r).get("isNewUser").asBoolean());
        assertEquals("Mehmet Demir", users.findByEmail(relay).orElseThrow().getDisplayName());

        String bad = "{\"identityToken\":\"" + token + "\",\"nonce\":\"baska-nonce\"}";
        MockHttpServletResponse b = mvc.perform(post("/api/auth/oauth/apple").contentType("application/json").content(bad))
                .andReturn().getResponse();
        assertEquals(400, b.getStatus());
        assertEquals("OAUTH_TOKEN_INVALID", json(b).get("code").asText());

        MockHttpServletResponse missing = mvc.perform(post("/api/auth/oauth/apple").contentType("application/json")
                .content("{\"identityToken\":\"" + token + "\"}")).andReturn().getResponse();
        assertEquals(400, missing.getStatus()); // nonce zorunlu (dogrulama hatasi)
    }

    @Test
    void invalidTokensAndUnverifiedEmailMapToDocumentedErrors() throws Exception {
        MockHttpServletResponse r = mvc.perform(post("/api/auth/oauth/google").contentType("application/json")
                .content("{\"idToken\":\"sahte.token.degeri\"}")).andReturn().getResponse();
        assertEquals(400, r.getStatus());
        assertEquals("OAUTH_TOKEN_INVALID", json(r).get("code").asText());

        var claims = t.googleClaims("u-" + tag, "dogrulanmamis." + tag + "@gmail.com");
        claims.put("email_verified", false);
        MockHttpServletResponse u = mvc.perform(post("/api/auth/oauth/google").contentType("application/json")
                .content("{\"idToken\":\"" + t.sign(claims) + "\"}")).andReturn().getResponse();
        assertEquals(403, u.getStatus());
        assertEquals("OAUTH_EMAIL_UNVERIFIED", json(u).get("code").asText());
        assertTrue(users.findByEmail("dogrulanmamis." + tag + "@gmail.com").isEmpty());
    }

    @Test
    void emailCollisionReturns409WithProviderAndMaskedEmailInTheRequestLanguage() throws Exception {
        User existing = new User();
        existing.setEmail("mevcut." + tag + "@gmail.com");
        existing.setPasswordHash(encoder.encode("Kx7-mQ2vLp9z"));
        existing.setDisplayName("Mevcut");
        existing.setEmailVerified(true);
        users.save(existing);

        MockHttpServletResponse r = googleLogin("c-" + tag, existing.getEmail(), "en");

        assertEquals(409, r.getStatus(), r.getContentAsString());
        JsonNode j = json(r);
        assertEquals("OAUTH_LINK_REQUIRED", j.get("code").asText());
        assertEquals("GOOGLE", j.get("provider").asText());
        assertTrue(j.get("emailMasked").asText().startsWith("m***@gmail.com"), j.toString());
        assertTrue(j.get("message").asText().startsWith("An account with this email already exists"), j.toString());
        assertEquals(1, users.findAll().stream().filter(x -> existing.getEmail().equals(x.getEmail())).count());
    }

    // ------------------------------------------------------------------ sunucu tarafi kapi

    @Test
    void incompleteProfileIsBlockedServerSideUntilOnboardingThenOpens() throws Exception {
        MockHttpServletResponse login = googleLogin("g-" + tag, "kapi." + tag + "@gmail.com", "tr");
        Long uid = users.findByEmail("kapi." + tag + "@gmail.com").orElseThrow().getId();
        assertFalse(json(login).get("profileCompleted").asBoolean());

        // okuma serbest, /users/me profileCompleted=false + authProviders
        MockHttpServletResponse me = asUser(uid, get("/api/users/me"));
        assertEquals(200, me.getStatus(), me.getContentAsString());
        assertFalse(json(me).get("profileCompleted").asBoolean());
        assertEquals("GOOGLE", json(me).get("authProviders").get(0).asText());
        assertFalse(json(me).has("username"));

        // etkilesim/yazma kapali: 403 PROFILE_INCOMPLETE (istemci yonlendirmesinden bagimsiz)
        for (MockHttpServletRequestBuilder b : List.of(
                post("/api/posts").contentType("application/json").content("{}"),
                post("/api/conversations").contentType("application/json").content("{}"),
                put("/api/users/me/username").contentType("application/json").content("{\"username\":\"abc.def\"}"),
                org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch("/api/users/me")
                        .contentType("application/json").content("{\"bio\":\"x\"}"))) {
            MockHttpServletResponse r = asUser(uid, b);
            assertEquals(403, r.getStatus(), r.getContentAsString());
            assertEquals("PROFILE_INCOMPLETE", json(r).get("code").asText());
        }

        // onboarding'in kendisi serbest; kullanici adi musaitligi (GET) serbest
        MockHttpServletResponse avail = asUser(uid, get("/api/users/username-available").param("u", "ayse." + tag));
        assertEquals(200, avail.getStatus());
        assertTrue(json(avail).get("available").asBoolean());

        MockHttpServletResponse done = asUser(uid, put("/api/users/me/onboarding").contentType("application/json")
                .content(String.format(OB, "ayse." + tag)));
        assertEquals(200, done.getStatus(), done.getContentAsString());
        assertTrue(json(done).get("profileCompleted").asBoolean());
        assertEquals("ayse." + tag, json(done).get("user").get("username").asText());
        assertEquals("Ayşe Yılmaz", json(done).get("user").get("displayName").asText());

        // kapi acildi: ayni yazma artik PROFILE_INCOMPLETE DEGIL
        MockHttpServletResponse after = asUser(uid, post("/api/conversations").contentType("application/json").content("{}"));
        assertNotEquals("PROFILE_INCOMPLETE", after.getStatus() == 403 ? json(after).get("code").asText() : "");

        // tekrar cagri idempotent: 200 ve ayni kullanici adi
        MockHttpServletResponse again = asUser(uid, put("/api/users/me/onboarding").contentType("application/json")
                .content(String.format(OB, "baska." + tag)));
        assertEquals(200, again.getStatus());
        assertEquals("ayse." + tag, json(again).get("user").get("username").asText());

        // aramada ve baskasinin profilinde artik gorunur sayilir (tamamlandi)
        assertTrue(users.findById(uid).orElseThrow().isProfileCompleted());
    }

    @Test
    void usernameTakenIs409AndAvailabilityReportsTakenInvalidAndReserved() throws Exception {
        googleLogin("t1-" + tag, "bir." + tag + "@gmail.com", "tr");
        googleLogin("t2-" + tag, "iki." + tag + "@gmail.com", "tr");
        Long a = users.findByEmail("bir." + tag + "@gmail.com").orElseThrow().getId();
        Long b = users.findByEmail("iki." + tag + "@gmail.com").orElseThrow().getId();

        assertEquals(200, asUser(a, put("/api/users/me/onboarding").contentType("application/json")
                .content(String.format(OB, "ortak." + tag))).getStatus());

        MockHttpServletResponse taken = asUser(b, put("/api/users/me/onboarding").contentType("application/json")
                .content(String.format(OB, "ORTAK." + tag)));
        assertEquals(409, taken.getStatus(), taken.getContentAsString());
        assertEquals("USERNAME_TAKEN", json(taken).get("code").asText());
        assertEquals("username", json(taken).get("field").asText());

        JsonNode t1 = json(asUser(b, get("/api/users/username-available").param("u", "ortak." + tag)));
        assertFalse(t1.get("available").asBoolean());
        assertEquals("TAKEN", t1.get("reason").asText());
        assertEquals("INVALID", json(asUser(b, get("/api/users/username-available").param("u", "a!"))).get("reason").asText());
        assertEquals("RESERVED", json(asUser(b, get("/api/users/username-available").param("u", "admin"))).get("reason").asText());
        assertNull(json(asUser(b, get("/api/users/username-available").param("u", "bos." + tag))).get("reason"));

        MockHttpServletResponse bad = asUser(b, put("/api/users/me/onboarding").contentType("application/json")
                .content(String.format(OB, "a")));
        assertEquals(422, bad.getStatus(), bad.getContentAsString());
        assertEquals("USERNAME_INVALID", json(bad).get("code").asText());
    }

    // ------------------------------------------------------------------ baglama / kaldirma / liste

    @Test
    void linkListAndUnlinkEndpoints() throws Exception {
        User me = new User();
        me.setEmail("baglan." + tag + "@bingol.edu.tr");
        me.setPasswordHash(encoder.encode("Kx7-mQ2vLp9z"));
        me.setDisplayName("Baglayan");
        me.setEmailVerified(true);
        me = users.save(me);
        String token = t.sign(t.googleClaims("lk-" + tag, "baska." + tag + "@gmail.com"));

        MockHttpServletResponse wrong = asUser(me.getId(), post("/api/auth/oauth/link").contentType("application/json")
                .content("{\"provider\":\"GOOGLE\",\"token\":\"" + token + "\",\"password\":\"yanlis\"}"));
        assertEquals(403, wrong.getStatus());
        assertEquals("WRONG_PASSWORD", json(wrong).get("code").asText());

        MockHttpServletResponse ok = asUser(me.getId(), post("/api/auth/oauth/link").contentType("application/json")
                .content("{\"provider\":\"google\",\"token\":\"" + token + "\",\"password\":\"Kx7-mQ2vLp9z\"}"));
        assertEquals(200, ok.getStatus(), ok.getContentAsString());
        assertTrue(json(ok).get("linked").asBoolean());

        JsonNode list = json(asUser(me.getId(), get("/api/auth/oauth/identities")));
        assertEquals(1, list.size());
        assertEquals("GOOGLE", list.get(0).get("provider").asText());

        // artik Google ile giris bu hesaba gider
        MockHttpServletResponse login = googleLogin("lk-" + tag, "baska." + tag + "@gmail.com", "tr");
        assertEquals(200, login.getStatus());
        assertFalse(json(login).get("isNewUser").asBoolean());
        assertTrue(json(login).get("profileCompleted").asBoolean(), "mevcut kullanici tamamlanmis sayilir");

        assertEquals(200, asUser(me.getId(), delete("/api/auth/oauth/link/google")).getStatus());
        assertEquals(0, json(asUser(me.getId(), get("/api/auth/oauth/identities"))).size());
        assertEquals(404, asUser(me.getId(), delete("/api/auth/oauth/link/google")).getStatus());
    }

    @Test
    void linkEndpointsRequireAnAuthenticatedSession() throws Exception {
        assertEquals(401, mvc.perform(post("/api/auth/oauth/link").contentType("application/json")
                .content("{\"provider\":\"GOOGLE\",\"token\":\"x\",\"password\":\"y\"}")).andReturn().getResponse().getStatus());
        assertEquals(401, mvc.perform(get("/api/auth/oauth/identities")).andReturn().getResponse().getStatus());
        assertEquals(401, mvc.perform(delete("/api/auth/oauth/link/google")).andReturn().getResponse().getStatus());
        assertEquals(401, mvc.perform(get("/api/users/username-available").param("u", "abc")).andReturn().getResponse().getStatus());
    }

    @Test
    void lastLoginMethodCannotBeUnlinkedOverHttp() throws Exception {
        googleLogin("son-" + tag, "son." + tag + "@gmail.com", "tr");
        Long uid = users.findByEmail("son." + tag + "@gmail.com").orElseThrow().getId();

        MockHttpServletResponse r = asUser(uid, delete("/api/auth/oauth/link/google"));
        assertEquals(409, r.getStatus());
        assertEquals("OAUTH_LAST_LOGIN_METHOD", json(r).get("code").asText());
    }
}
