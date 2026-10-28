package edu.bingol.backend.community.category;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
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

/** /api/admin/community-categories/** yalniz ADMIN: anonim 401, normal kullanici 403; herkese acik liste girisli. */
@SpringBootTest
class CommunityCategoryAdminSecurityTest {

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
    void anonymousAndPlainUsersAreRejectedOnEveryAdminEndpoint() throws Exception {
        String json = "{\"nameTr\":\"X\"}";
        var requests = List.of(
                get("/api/admin/community-categories"),
                post("/api/admin/community-categories").contentType("application/json").content(json),
                put("/api/admin/community-categories/1").contentType("application/json").content(json),
                put("/api/admin/community-categories/order").contentType("application/json").content("{\"ids\":[1]}"),
                patch("/api/admin/community-categories/1/active").contentType("application/json").content("{\"active\":false}"),
                delete("/api/admin/community-categories/1"));
        for (var rb : requests) {
            assertEquals(401, mvc.perform(rb).andReturn().getResponse().getStatus(), rb.toString());
        }
        for (var rb : requests) {
            assertEquals(403, mvc.perform(rb.with(authentication(user()))).andReturn().getResponse().getStatus(), rb.toString());
        }
    }

    @Test
    void publicListRequiresLoginAndReturnsVersionHeader() throws Exception {
        assertEquals(401, mvc.perform(get("/api/communities/categories")).andReturn().getResponse().getStatus());
        var res = mvc.perform(get("/api/communities/categories").with(authentication(user()))).andReturn().getResponse();
        assertEquals(200, res.getStatus());
        assertEquals(true, res.getHeader("X-Categories-Version") != null);
    }
}
