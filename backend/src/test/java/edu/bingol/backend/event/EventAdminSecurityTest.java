package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

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

/** /api/admin/events/** yalniz ADMIN: anonim 401, normal kullanici 403. */
@SpringBootTest
class EventAdminSecurityTest {

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
    void anonymousAndPlainUsersAreRejected() throws Exception {
        for (String path : List.of("/api/admin/events", "/api/admin/events/1")) {
            assertEquals(401, mvc.perform(get(path)).andReturn().getResponse().getStatus(), path);
            assertEquals(403, mvc.perform(get(path).with(authentication(user()))).andReturn().getResponse().getStatus(), path);
        }
        for (String action : List.of("hide", "unhide", "cancel", "approve", "reject")) {
            String path = "/api/admin/events/1/" + action;
            assertEquals(401, mvc.perform(post(path).contentType("application/json").content("{\"reason\":\"x\"}"))
                    .andReturn().getResponse().getStatus(), path);
            assertEquals(403, mvc.perform(post(path).with(authentication(user()))
                    .contentType("application/json").content("{\"reason\":\"x\"}")).andReturn().getResponse().getStatus(), path);
        }
    }
}
