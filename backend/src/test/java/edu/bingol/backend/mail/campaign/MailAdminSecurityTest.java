package edu.bingol.backend.mail.campaign;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;

import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

/** /api/admin/mail/** yalniz ADMIN: anonim 401, siradan kullanici 403 (okuma ve yazma). */
@SpringBootTest
class MailAdminSecurityTest {

    @Autowired WebApplicationContext ctx;
    MockMvc mvc;

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.webAppContextSetup(ctx).apply(springSecurity()).build();
    }

    private static UsernamePasswordAuthenticationToken user() {
        return new UsernamePasswordAuthenticationToken(5L, null, List.of(new SimpleGrantedAuthority("ROLE_USER")));
    }

    @Test
    void anonymousAndPlainUsersAreRejectedOnEveryMailAdminEndpoint() throws Exception {
        for (String path : List.of("/api/admin/mail/variables", "/api/admin/mail/templates", "/api/admin/mail/templates/1",
                "/api/admin/mail/templates/1/versions", "/api/admin/mail/campaigns", "/api/admin/mail/campaigns/1",
                "/api/admin/mail/campaigns/1/recipients")) {
            assertEquals(401, mvc.perform(get(path)).andReturn().getResponse().getStatus(), path);
            assertEquals(403, mvc.perform(get(path).with(authentication(user()))).andReturn().getResponse().getStatus(), path);
        }
        for (String path : List.of("/api/admin/mail/templates", "/api/admin/mail/templates/preview",
                "/api/admin/mail/templates/1/publish", "/api/admin/mail/templates/1/archive", "/api/admin/mail/templates/1/preview",
                "/api/admin/mail/templates/1/test", "/api/admin/mail/campaigns", "/api/admin/mail/campaigns/audience/preview",
                "/api/admin/mail/campaigns/1/schedule", "/api/admin/mail/campaigns/1/cancel", "/api/admin/mail/campaigns/1/pause",
                "/api/admin/mail/campaigns/1/resume")) {
            assertEquals(401, mvc.perform(post(path).contentType("application/json").content("{}")).andReturn().getResponse().getStatus(), path);
            assertEquals(403, mvc.perform(post(path).with(authentication(user())).contentType("application/json").content("{}"))
                    .andReturn().getResponse().getStatus(), path);
        }
        assertEquals(403, mvc.perform(put("/api/admin/mail/templates/1").with(authentication(user())).contentType("application/json")
                .content("{}")).andReturn().getResponse().getStatus());
        assertEquals(403, mvc.perform(put("/api/admin/mail/campaigns/1").with(authentication(user())).contentType("application/json")
                .content("{}")).andReturn().getResponse().getStatus());
        assertEquals(403, mvc.perform(delete("/api/admin/mail/templates/1").with(authentication(user()))).andReturn().getResponse().getStatus());
    }
}
