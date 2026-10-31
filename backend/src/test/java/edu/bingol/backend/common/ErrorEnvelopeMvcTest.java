package edu.bingol.backend.common;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import edu.bingol.backend.auth.jwt.JwtService;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import java.nio.charset.StandardCharsets;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.redis.RedisConnectionFailureException;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

/**
 * T-003 + T-004 (gercek guvenlik zinciri, H2): hata zarfi her durumda {code,message}, bozuk Bearer'a Basic penceresi
 * yok, Redis kesilince kimlikli istek 503 + Retry-After ama herkese acik uclar 200.
 */
// Test application.properties jwt.access-ttl-minutes tanimlamaz (0 = aninda dolan token): acikca verilir
@SpringBootTest(properties = {"jwt.access-ttl-minutes=15", "jwt.refresh-ttl-days=30"})
class ErrorEnvelopeMvcTest {

    @Autowired WebApplicationContext ctx;
    @Autowired JwtService jwt;
    @Autowired RedisBreaker breaker;
    @MockitoBean RateLimiter limiter;
    @MockitoBean StringRedisTemplate redis;
    MockMvc mvc;
    @SuppressWarnings("unchecked")
    ValueOperations<String, String> ops = org.mockito.Mockito.mock(ValueOperations.class);

    @BeforeEach
    void setUp() {
        when(redis.opsForValue()).thenReturn(ops);
        mvc = MockMvcBuilders.webAppContextSetup(ctx).apply(springSecurity()).build();
    }

    private String json(MockHttpServletResponse r) throws Exception {
        return r.getContentAsString(StandardCharsets.UTF_8);
    }

    private static UsernamePasswordAuthenticationToken asUser() {
        return new UsernamePasswordAuthenticationToken(42L, null, List.of(new SimpleGrantedAuthority("ROLE_USER")));
    }

    @Test
    void malformedBearerOnAnAdminPathIs401WithEnvelopeAndNoBasicChallenge() throws Exception {
        MockHttpServletResponse r = mvc.perform(get("/api/admin/users")
                .header("Authorization", "Bearer eyJhbGciOiJIUzI1NiJ9.bozuk.imza")).andReturn().getResponse();

        assertEquals(401, r.getStatus());
        assertNull(r.getHeader("WWW-Authenticate"));
        assertTrue(json(r).contains("\"code\":\"UNAUTHORIZED\""), json(r));
        assertTrue(r.getHeaders("Vary").contains("Accept-Language"), "Vary: " + r.getHeaders("Vary"));
        assertNotNull(r.getHeader("Content-Language"));
    }

    @Test
    void headerlessCurlStyleAdminRequestStillGetsTheBasicChallengeWhenBasicIsEnabled() throws Exception {
        MockHttpServletResponse r = mvc.perform(get("/api/admin/users")).andReturn().getResponse();

        assertEquals(401, r.getStatus());
        assertEquals("Basic realm=\"admin\"", r.getHeader("WWW-Authenticate"));
        assertTrue(json(r).contains("\"code\":\"UNAUTHORIZED\""));
    }

    @Test
    void wrongBasicCredentialsAlsoGetTheEnvelope() throws Exception {
        MockHttpServletResponse r = mvc.perform(get("/api/admin/users")
                .header("Authorization", "Basic YWRtaW46eWFubGlz")).andReturn().getResponse();

        assertEquals(401, r.getStatus());
        assertTrue(json(r).contains("\"code\":\"UNAUTHORIZED\""), json(r));
        assertNull(r.getHeader("WWW-Authenticate"));
    }

    @Test
    void wrongMethodUnknownPathAndWrongMediaTypeAllGetTheEnvelope() throws Exception {
        MockHttpServletResponse m405 = mvc.perform(delete("/api/news").with(authentication(asUser()))).andReturn().getResponse();
        assertEquals(405, m405.getStatus());
        assertTrue(json(m405).contains("\"code\":\"METHOD_NOT_ALLOWED\""), json(m405));
        assertNotNull(m405.getHeader("Allow"));

        MockHttpServletResponse m404 = mvc.perform(get("/api/yok-boyle-bir-yol").with(authentication(asUser()))).andReturn().getResponse();
        assertEquals(404, m404.getStatus());
        assertTrue(json(m404).contains("\"code\":\"NOT_FOUND\""), json(m404));

        MockHttpServletResponse m415 = mvc.perform(post("/api/auth/login").contentType("text/plain").content("x")).andReturn().getResponse();
        assertEquals(415, m415.getStatus());
        assertTrue(json(m415).contains("\"code\":\"UNSUPPORTED_MEDIA_TYPE\""), json(m415));
        assertTrue(m415.getHeaders("Vary").contains("Accept-Language"), "Vary: " + m415.getHeaders("Vary"));
    }

    @Test
    void redisOutageGives503OnAuthenticatedEndpointsButPublicEndpointsKeepWorking() throws Exception {
        when(ops.multiGet(anyList())).thenThrow(new RedisConnectionFailureException("down"));
        User u = new User();
        u.setId(42L);
        u.setEmail("ogr@bingol.edu.tr");
        u.setRole(Role.USER);
        String bearer = "Bearer " + jwt.createAccessToken(u);

        MockHttpServletResponse me = mvc.perform(get("/api/auth/me").header("Authorization", bearer)).andReturn().getResponse();
        assertEquals(503, me.getStatus(), json(me));
        assertTrue(json(me).contains("\"code\":\"REDIS_UNAVAILABLE\""), json(me));
        assertNotNull(me.getHeader("Retry-After"));
        assertTrue(breaker.isOpen());

        // devre acikken: ayni token'la herkese acik uc (haber listesi) Redis'siz 200 doner
        MockHttpServletResponse news = mvc.perform(get("/api/news").header("Authorization", bearer)).andReturn().getResponse();
        assertEquals(200, news.getStatus(), json(news));
    }
}
