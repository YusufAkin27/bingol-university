package edu.bingol.backend.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;

import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.messaging.room.RoomConversations;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.TreeSet;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.context.WebApplicationContext;
import org.springframework.web.servlet.mvc.method.RequestMappingInfo;
import org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerMapping;

/**
 * Guvenlik denetimi: her `/api/auth/*` ucu icin ANONIM erisim matrisi. Kimlik gerektirenler 401 donmeli;
 * herkese acik olanlar 401/403 DONMEMELI (bos govdeyle genelde 400). Yeni auth ucu siniflandirilmazsa test duser.
 */
@SpringBootTest
class SecurityConfigAuthMatrixTest {

    /** Anonim 401 beklenen (SecurityConfig: authenticated) uclar. */
    private static final Set<String> PROTECTED = Set.of(
            "GET /api/auth/me", "POST /api/auth/logout-all", "POST /api/auth/change-password",
            "GET /api/auth/verification/status", "POST /api/auth/verification/resend", "POST /api/auth/verification/verify");

    /** Anonim erisilebilen uclar. */
    private static final Set<String> PUBLIC = Set.of(
            "POST /api/auth/register", "POST /api/auth/resend-code", "POST /api/auth/forgot-password",
            "POST /api/auth/verify-reset-code", "POST /api/auth/reset-password", "POST /api/auth/verify-email",
            "POST /api/auth/login", "POST /api/auth/login/2fa", "POST /api/auth/login/2fa/resend", "POST /api/auth/refresh", "POST /api/auth/logout");

    @Autowired WebApplicationContext ctx;
    @Autowired @Qualifier("requestMappingHandlerMapping") RequestMappingHandlerMapping mapping;
    @MockitoBean RateLimiter limiter;
    @MockitoBean StringRedisTemplate redis;
    @MockitoBean RoomConversations rooms;
    MockMvc mvc;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        ValueOperations<String, String> ops = org.mockito.Mockito.mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(ops);
        mvc = MockMvcBuilders.webAppContextSetup(ctx).apply(springSecurity()).build();
    }

    /** Kayitli "/api/auth/..." uclari (2fa/oauth/sessions alt uclari haric): "METOT yol". */
    private Set<String> authEndpoints() {
        Set<String> out = new TreeSet<>();
        for (RequestMappingInfo info : mapping.getHandlerMethods().keySet()) {
            if (info.getPathPatternsCondition() == null) {
                continue;
            }
            for (String p : info.getPathPatternsCondition().getPatternValues()) {
                if (!p.startsWith("/api/auth/") || p.contains("{") || p.matches("/api/auth/(2fa|oauth|sessions).*")) {
                    continue;
                }
                for (RequestMethod m : info.getMethodsCondition().getMethods()) {
                    out.add(m + " " + p);
                }
            }
        }
        return out;
    }

    @Test
    void everyAuthEndpointIsClassified() {
        Set<String> all = new TreeSet<>(PROTECTED);
        all.addAll(PUBLIC);
        assertThat(authEndpoints()).as("Siniflandirilmamis /api/auth ucu: PROTECTED veya PUBLIC kumesine ekleyin")
                .isEqualTo(all);
    }

    @Test
    void anonymousMatrix() throws Exception {
        List<String> bad = new ArrayList<>();
        for (String ep : authEndpoints()) {
            String[] parts = ep.split(" ");
            var req = MockMvcRequestBuilders.request(org.springframework.http.HttpMethod.valueOf(parts[0]), parts[1])
                    .contentType(MediaType.APPLICATION_JSON).content("{}");
            int status = mvc.perform(req).andReturn().getResponse().getStatus();
            if (PROTECTED.contains(ep) && status != 401) {
                bad.add(ep + " -> " + status + " (401 beklenirdi)");
            }
            if (PUBLIC.contains(ep) && (status == 401 || status == 403)) {
                bad.add(ep + " -> " + status + " (anonim acik olmali)");
            }
        }
        assertThat(bad).isEmpty();
    }
}
