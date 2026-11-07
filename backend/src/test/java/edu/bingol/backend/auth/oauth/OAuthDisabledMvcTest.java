package edu.bingol.backend.auth.oauth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import com.fasterxml.jackson.databind.ObjectMapper;
import edu.bingol.backend.common.RateLimiter;
import java.nio.charset.StandardCharsets;
import java.util.List;
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

/** Varsayilan (bayrak KAPALI): tum OAuth uclari 404 OAUTH_DISABLED; yapilandirma olmadan guvenle dagitilir. */
@SpringBootTest
class OAuthDisabledMvcTest {

    private static final ObjectMapper OM = new ObjectMapper();

    @Autowired WebApplicationContext ctx;
    @MockitoBean RateLimiter limiter;
    @MockitoBean StringRedisTemplate redis;
    MockMvc mvc;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        when(redis.opsForValue()).thenReturn(org.mockito.Mockito.mock(ValueOperations.class));
        mvc = MockMvcBuilders.webAppContextSetup(ctx).apply(springSecurity()).build();
    }

    private void expectDisabled(MockHttpServletRequestBuilder b, boolean authenticated) throws Exception {
        if (authenticated) {
            b = b.with(authentication(new UsernamePasswordAuthenticationToken(1L, null,
                    List.of(new SimpleGrantedAuthority("ROLE_USER")))));
        }
        MockHttpServletResponse r = mvc.perform(b).andReturn().getResponse();
        assertEquals(404, r.getStatus(), r.getContentAsString());
        assertEquals("OAUTH_DISABLED", OM.readTree(r.getContentAsString(StandardCharsets.UTF_8)).get("code").asText());
    }

    @Test
    void everyOauthEndpointIs404WhenTheFlagIsOff() throws Exception {
        expectDisabled(post("/api/auth/oauth/google").contentType("application/json").content("{\"idToken\":\"x\"}"), false);
        expectDisabled(post("/api/auth/oauth/apple").contentType("application/json")
                .content("{\"identityToken\":\"x\",\"nonce\":\"n\"}"), false);
        expectDisabled(post("/api/auth/oauth/link").contentType("application/json")
                .content("{\"provider\":\"GOOGLE\",\"token\":\"x\",\"password\":\"p\"}"), true);
        expectDisabled(delete("/api/auth/oauth/link/google"), true);
        expectDisabled(get("/api/auth/oauth/identities"), true);
    }
}
