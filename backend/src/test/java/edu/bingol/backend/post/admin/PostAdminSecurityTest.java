package edu.bingol.backend.post.admin;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
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

/** /api/admin/posts/** yalniz ADMIN. */
@SpringBootTest
class PostAdminSecurityTest {

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
        for (String path : List.of("/api/admin/posts", "/api/admin/posts/stats", "/api/admin/posts/1")) {
            assertEquals(401, mvc.perform(get(path)).andReturn().getResponse().getStatus(), path);
            assertEquals(403, mvc.perform(get(path).with(authentication(user()))).andReturn().getResponse().getStatus(), path);
        }
        assertEquals(403, mvc.perform(post("/api/admin/posts/1/hide").with(authentication(user()))
                .contentType("application/json").content("{}")).andReturn().getResponse().getStatus());
        assertEquals(403, mvc.perform(delete("/api/admin/posts/1").with(authentication(user())))
                .andReturn().getResponse().getStatus());
        assertEquals(403, mvc.perform(patch("/api/admin/posts/1").with(authentication(user()))
                .contentType("application/json").content("{\"text\":\"x\"}")).andReturn().getResponse().getStatus());
    }
}
