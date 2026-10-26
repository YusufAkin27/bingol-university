package edu.bingol.backend.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.httpBasic;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

/** Guvenlik basliklari ve actuator erisim kurallari (MockMvc, H2 baglami). */
@SpringBootTest
class SecurityHeadersTest {

    @Autowired
    WebApplicationContext ctx;

    MockMvc mvc;

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.webAppContextSetup(ctx).apply(springSecurity()).build();
    }

    @Test
    void apiResponsesCarryHardeningHeaders() throws Exception {
        MockHttpServletResponse res = mvc.perform(get("/api/hello")).andReturn().getResponse();
        assertEquals(200, res.getStatus());
        assertEquals("nosniff", res.getHeader("X-Content-Type-Options"));
        assertEquals("DENY", res.getHeader("X-Frame-Options"));
        assertEquals("no-referrer", res.getHeader("Referrer-Policy"));
        String csp = res.getHeader("Content-Security-Policy");
        assertNotNull(csp);
        assertTrue(csp.contains("default-src 'none'") && csp.contains("frame-ancestors 'none'"));
    }

    @Test
    void hstsOnlyOnSecureRequests() throws Exception {
        MockHttpServletResponse https = mvc.perform(get("/api/hello").secure(true)).andReturn().getResponse();
        assertTrue(https.getHeader("Strict-Transport-Security").contains("max-age=31536000"));
        assertEquals(null, mvc.perform(get("/api/hello")).andReturn().getResponse().getHeader("Strict-Transport-Security"));
    }

    @Test
    void actuatorOnlyHealthIsPublic() throws Exception {
        assertEquals(401, mvc.perform(get("/actuator/info")).andReturn().getResponse().getStatus());
        assertEquals(401, mvc.perform(get("/actuator/metrics")).andReturn().getResponse().getStatus());
        int admin = mvc.perform(get("/actuator/info").with(httpBasic("admin", "test-admin-pw")))
                .andReturn().getResponse().getStatus();
        assertTrue(admin != 401 && admin != 403, "admin actuator erisimi: " + admin);
    }
}
