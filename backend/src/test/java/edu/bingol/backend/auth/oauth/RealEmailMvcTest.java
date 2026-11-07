package edu.bingol.backend.auth.oauth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import edu.bingol.backend.auth.ProfileIncompleteWriteFilter;
import edu.bingol.backend.auth.realemail.RealEmailRequiredWriteFilter;
import edu.bingol.backend.auth.token.RefreshTokenService;
import edu.bingol.backend.auth.token.SessionService;
import edu.bingol.backend.auth.token.VerificationService;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
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

/**
 * HTTP sozlesmesi (H2): Apple gizli e-posta ile YENI hesap kapida (403 REAL_EMAIL_REQUIRED), giris/profil yanitinda
 * emailNeedsReal + realEmailRequired, serbest uclar (e-posta akisi, profil), dogrulamadan sonra kapi acilir; mevcut
 * (eski) role hesap kilitlenmez; Google hesabi etkilenmez.
 */
@SpringBootTest(properties = {
        "jwt.access-ttl-minutes=15",
        "spring.messages.basename=i18n/messages,i18n/auth,i18n/profile,i18n/ops",
        "app.auth.oauth.enabled=true",
        "app.auth.oauth.google-client-ids=" + OAuthTestSupport.GOOGLE_AUD,
        "app.auth.oauth.apple-client-ids=" + OAuthTestSupport.APPLE_AUD})
class RealEmailMvcTest {

    private static final ObjectMapper OM = new ObjectMapper();

    @Autowired WebApplicationContext ctx;
    @Autowired UserRepository users;
    @Autowired AuthIdentityRepository identities;
    @Autowired ProfileIncompleteWriteFilter profileGate;
    @Autowired RealEmailRequiredWriteFilter realEmailGate;
    @MockitoBean RateLimiter limiter;
    @MockitoBean StringRedisTemplate redis;
    @MockitoBean VerificationService verification;
    @MockitoBean RefreshTokenService refresh;
    @MockitoBean SessionService sessions;
    @MockitoBean OAuthKeyProvider keys;

    final OAuthTestSupport t = new OAuthTestSupport();
    ValueOperations<String, String> ops;
    MockMvc mvc;
    String tag;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        ops = org.mockito.Mockito.mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(ops);
        when(refresh.issue(anyLong(), anyString())).thenReturn("refresh-token");
        when(refresh.issue(anyLong(), anyString(), anyLong(), any())).thenReturn("refresh-token");
        when(keys.key(any(), eq(OAuthTestSupport.KID))).thenReturn(t.pair.getPublic());
        mvc = MockMvcBuilders.webAppContextSetup(ctx).apply(springSecurity())
                .addFilters(profileGate, realEmailGate).build();
        tag = UUID.randomUUID().toString().substring(0, 8);
    }

    private static JsonNode json(MockHttpServletResponse r) throws Exception {
        return OM.readTree(r.getContentAsString(StandardCharsets.UTF_8));
    }

    private MockHttpServletResponse asUser(Long uid, MockHttpServletRequestBuilder b) throws Exception {
        var token = new UsernamePasswordAuthenticationToken(uid, null, List.of(new SimpleGrantedAuthority("ROLE_USER")));
        return mvc.perform(b.with(authentication(token))).andReturn().getResponse();
    }

    private MockHttpServletResponse appleLogin(String sub, String email) throws Exception {
        String body = "{\"identityToken\":\"" + t.sign(t.appleClaims(sub, email, "n-" + sub)) + "\",\"nonce\":\"n-" + sub + "\"}";
        return mvc.perform(post("/api/auth/oauth/apple").contentType("application/json").content(body)
                .header("Accept-Language", "en")).andReturn().getResponse();
    }

    private Long completeProfile(String email) {
        User u = users.findByEmail(email).orElseThrow();
        u.setProfileCompletedAt(Instant.now()); // yalniz gercek e-posta kapisini ayri sinamak icin
        users.save(u);
        return u.getId();
    }

    // ------------------------------------------------------------------ yeni role hesap: kapi

    @Test
    void newAppleRelayAccountIsGatedUntilRealEmailIsVerified() throws Exception {
        String relay = "r" + tag + "@privaterelay.appleid.com";
        MockHttpServletResponse login = appleLogin("ap-" + tag, relay);
        assertEquals(200, login.getStatus(), login.getContentAsString());
        assertTrue(json(login).get("emailNeedsReal").asBoolean());
        assertTrue(json(login).get("realEmailRequired").asBoolean());
        Long uid = completeProfile(relay);

        MockHttpServletResponse me = asUser(uid, get("/api/users/me"));
        assertEquals(200, me.getStatus(), me.getContentAsString());
        assertTrue(json(me).get("emailNeedsReal").asBoolean());
        assertTrue(json(me).get("realEmailRequired").asBoolean());

        // etkilesim kapali, mesaj istek dilinde
        MockHttpServletResponse blocked = asUser(uid, post("/api/posts").contentType("application/json").content("{}"));
        assertEquals(403, blocked.getStatus(), blocked.getContentAsString());
        assertEquals("REAL_EMAIL_REQUIRED", json(blocked).get("code").asText());
        MockHttpServletResponse tr = asUser(uid, post("/api/posts").header("Accept-Language", "tr")
                .contentType("application/json").content("{}"));
        assertTrue(json(tr).get("message").asText().contains("e-posta"), json(tr).toString());

        // kod gonder: serbest uc, kod role adresine DEGIL yeni adrese
        String real = "gercek." + tag + "@gmail.com";
        MockHttpServletResponse start = asUser(uid, post("/api/users/me/email/start").contentType("application/json")
                .content("{\"email\":\"" + real + "\"}"));
        assertEquals(200, start.getStatus(), start.getContentAsString());
        assertTrue(json(start).get("sent").asBoolean());
        assertTrue(json(start).get("emailMasked").asText().startsWith("g***@gmail.com"));
        org.mockito.Mockito.verify(verification).issueEmailChange(eq(uid + ":" + real), eq(real), any());
        org.mockito.Mockito.verify(verification, org.mockito.Mockito.never())
                .issueEmailChange(anyString(), eq(relay), any());
        org.mockito.Mockito.verify(ops).set(eq("rem:" + uid), eq(real), any(java.time.Duration.class));

        // yanlis kod
        when(ops.get("rem:" + uid)).thenReturn(real);
        when(verification.verifyEmailChange(eq(uid + ":" + real), eq("111111"), any())).thenReturn(false);
        when(verification.verifyEmailChange(eq(uid + ":" + real), eq("123456"), any())).thenReturn(true);
        MockHttpServletResponse bad = asUser(uid, post("/api/users/me/email/verify").contentType("application/json")
                .content("{\"code\":\"111111\"}"));
        assertEquals(400, bad.getStatus());
        assertEquals("INVALID_CODE", json(bad).get("code").asText());
        MockHttpServletResponse malformed = asUser(uid, post("/api/users/me/email/verify")
                .contentType("application/json").content("{\"code\":\"12ab\"}"));
        assertEquals(400, malformed.getStatus());

        // dogru kod: hesabin tek e-postasi gercek adres, kapi acilir
        MockHttpServletResponse ok = asUser(uid, post("/api/users/me/email/verify").contentType("application/json")
                .content("{\"code\":\"123456\"}"));
        assertEquals(200, ok.getStatus(), ok.getContentAsString());
        assertEquals(real, json(ok).get("email").asText());
        assertFalse(json(ok).get("emailNeedsReal").asBoolean());

        User u = users.findById(uid).orElseThrow();
        assertEquals(real, u.getEmail());
        assertTrue(u.isEmailVerified());
        assertFalse(u.isEmailRelay());
        assertFalse(u.isRealEmailRequired());
        var apple = identities.findByUserIdAndProvider(uid, OAuthProvider.APPLE).orElseThrow();
        assertEquals(null, apple.getEmail(), "eski role adresi saklanmaz");
        assertFalse(apple.isEmailIsPrivate());

        MockHttpServletResponse after = asUser(uid, post("/api/posts").contentType("application/json").content("{}"));
        assertNotEquals("REAL_EMAIL_REQUIRED", json(after).has("code") ? json(after).get("code").asText() : "");
        MockHttpServletResponse me2 = asUser(uid, get("/api/users/me"));
        assertFalse(json(me2).get("emailNeedsReal").asBoolean());
        assertEquals(real, json(me2).get("email").asText());

        // Apple tekrar girdi (role adresi yine gelir): hesap e-postasi ve kimlik e-postasi role adresine DONMEZ
        MockHttpServletResponse relogin = appleLogin("ap-" + tag, relay);
        assertEquals(200, relogin.getStatus(), relogin.getContentAsString());
        assertFalse(json(relogin).get("emailNeedsReal").asBoolean());
        assertEquals(real, users.findById(uid).orElseThrow().getEmail());
        assertEquals(null, identities.findByUserIdAndProvider(uid, OAuthProvider.APPLE).orElseThrow().getEmail());
    }

    @Test
    void relayAddressAndBadInputAreRejectedAtTheEndpoint() throws Exception {
        String relay = "q" + tag + "@privaterelay.appleid.com";
        appleLogin("ap2-" + tag, relay);
        Long uid = completeProfile(relay);

        MockHttpServletResponse r = asUser(uid, post("/api/users/me/email/start").contentType("application/json")
                .content("{\"email\":\"baska@privaterelay.appleid.com\"}"));
        assertEquals(400, r.getStatus());
        assertEquals("EMAIL_RELAY_NOT_ALLOWED", json(r).get("code").asText());
        MockHttpServletResponse alias = asUser(uid, post("/api/users/me/email/start").contentType("application/json")
                .content("{\"email\":\"ali+1@gmail.com\"}"));
        assertEquals("EMAIL_ALIAS_NOT_ALLOWED", json(alias).get("code").asText());
        MockHttpServletResponse empty = asUser(uid, post("/api/users/me/email/start").contentType("application/json")
                .content("{\"email\":\"\"}"));
        assertEquals(400, empty.getStatus());
    }

    // ------------------------------------------------------------------ mevcut hesaplar

    @Test
    void legacyRelayAccountIsFlaggedButNotLockedAndGoogleAccountIsUnaffected() throws Exception {
        // gate'ten ONCE acilmis role hesap: migration yalniz email_relay isaretler, real_email_required false kalir
        User legacy = new User();
        legacy.setEmail("eski" + tag + "@privaterelay.appleid.com");
        legacy.setPasswordHash(User.NO_PASSWORD_PREFIX + "x");
        legacy.setDisplayName("Eski Kisi");
        legacy.setEmailVerified(true);
        legacy.setEmailRelay(true);
        legacy = users.save(legacy);

        MockHttpServletResponse me = asUser(legacy.getId(), get("/api/users/me"));
        assertTrue(json(me).get("emailNeedsReal").asBoolean(), "uygulama yumusak adimi gosterir");
        assertFalse(json(me).get("realEmailRequired").asBoolean(), "ama kilitlenmez");
        MockHttpServletResponse write = asUser(legacy.getId(), post("/api/posts").contentType("application/json").content("{}"));
        String code = json(write).has("code") ? json(write).get("code").asText() : "";
        assertNotEquals("REAL_EMAIL_REQUIRED", code);

        String body = "{\"idToken\":\"" + t.sign(t.googleClaims("g-" + tag, "g." + tag + "@gmail.com")) + "\"}";
        MockHttpServletResponse g = mvc.perform(post("/api/auth/oauth/google").contentType("application/json").content(body))
                .andReturn().getResponse();
        assertEquals(200, g.getStatus(), g.getContentAsString());
        assertFalse(json(g).get("emailNeedsReal").asBoolean());
        assertFalse(json(g).get("realEmailRequired").asBoolean());
    }
}
