package edu.bingol.backend.share;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;

import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

/** /s/** gercek guvenlik zincirinde: kimliksiz erisim, kendi CSP'si, olmayan icerikte notr sayfa, gorselde 404. */
@SpringBootTest(properties = "spring.messages.basename=i18n/messages,i18n/share")
class SharePageSecurityTest {

    @Autowired
    WebApplicationContext ctx;

    MockMvc mvc;

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.webAppContextSetup(ctx).apply(springSecurity()).build();
    }

    @Test
    void anonymousGetsTheNeutralPageForMissingContentWithItsOwnCsp() throws Exception {
        MockHttpServletResponse r = mvc.perform(get("/s/p/987654").header("Accept-Language", "en")).andReturn().getResponse();
        String html = r.getContentAsString(StandardCharsets.UTF_8);

        assertEquals(200, r.getStatus());
        assertTrue(html.contains("Something on BÜ Kampüs"));
        assertTrue(html.contains("apps.apple.com/tr/app/id6830530499"));
        assertTrue(html.contains("play.google.com/store/apps/details?id=tr.com.bukampus.app"));
        String csp = r.getHeader("Content-Security-Policy");
        assertNotNull(csp);
        assertTrue(csp.contains("script-src 'sha256-"), csp);
        assertFalse(csp.contains("default-src 'none'; frame-ancestors"), "genel API CSP'si degil");
        assertEquals("DENY", r.getHeader("X-Frame-Options"));
        assertEquals("nosniff", r.getHeader("X-Content-Type-Options"));
        assertEquals("noindex, nofollow", r.getHeader("X-Robots-Tag"));
        assertEquals("public, max-age=300", r.getHeader("Cache-Control"));
    }

    @Test
    void imageOfMissingPostIs404NotAnAuthChallengeAndOtherPathsStayProtected() throws Exception {
        assertEquals(404, mvc.perform(get("/s/p/987654/img")).andReturn().getResponse().getStatus());
        assertEquals(401, mvc.perform(get("/s/p/1/img/extra")).andReturn().getResponse().getStatus());
        assertEquals(401, mvc.perform(get("/s/p")).andReturn().getResponse().getStatus());
    }
}
