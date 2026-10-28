package edu.bingol.backend.post;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;

import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpMethod;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

/** Sade Kesfet: kaldirilan uclar kalici 410 FEATURE_REMOVED; kalan uclar (begeni) etkilenmez. */
@SpringBootTest
class RemovedFeatureControllerTest {

    @Autowired WebApplicationContext ctx;
    /** Test ortaminda Redis yok: hiz siniri sahte (uc 410 mantigi denenir). */
    @org.springframework.test.context.bean.override.mockito.MockitoBean edu.bingol.backend.common.RateLimiter limiter;
    MockMvc mvc;

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.webAppContextSetup(ctx).apply(springSecurity()).build();
    }

    private static UsernamePasswordAuthenticationToken user() {
        return new UsernamePasswordAuthenticationToken(4242L, null, List.of(new SimpleGrantedAuthority("ROLE_USER")));
    }

    private MockHttpServletResponse call(HttpMethod m, String path) throws Exception {
        return mvc.perform(MockMvcRequestBuilders.request(m, path).with(authentication(user())).contentType("application/json")
                .content("{}")).andReturn().getResponse();
    }

    @Test
    void removedEndpointsReturn410WithCode() throws Exception {
        record Call(HttpMethod m, String path) {}
        List<Call> calls = List.of(
                new Call(HttpMethod.GET, "/api/posts/1/comments"), new Call(HttpMethod.POST, "/api/posts/1/comments"),
                new Call(HttpMethod.PATCH, "/api/comments/1"), new Call(HttpMethod.DELETE, "/api/comments/1"),
                new Call(HttpMethod.GET, "/api/comments/1/replies"),
                new Call(HttpMethod.POST, "/api/stories"), new Call(HttpMethod.GET, "/api/stories/tray"),
                new Call(HttpMethod.POST, "/api/stories/1/view"), new Call(HttpMethod.GET, "/api/stories/1/viewers"),
                new Call(HttpMethod.DELETE, "/api/stories/1"), new Call(HttpMethod.GET, "/api/users/1/stories"),
                new Call(HttpMethod.GET, "/api/hashtags/trending"), new Call(HttpMethod.GET, "/api/hashtags/suggest"),
                new Call(HttpMethod.GET, "/api/hashtags/gunduz/posts"),
                new Call(HttpMethod.GET, "/api/users/mention-suggest"),
                new Call(HttpMethod.PUT, "/api/posts/1/save"), new Call(HttpMethod.DELETE, "/api/posts/1/save"),
                new Call(HttpMethod.GET, "/api/posts/saved"), new Call(HttpMethod.GET, "/api/posts/1/likes"));
        for (Call c : calls) {
            MockHttpServletResponse r = call(c.m(), c.path());
            assertEquals(410, r.getStatus(), c.m() + " " + c.path());
            assertTrue(r.getContentAsString().contains("FEATURE_REMOVED"), c.path());
        }
    }

    @Test
    void anonymousStillGets401() throws Exception {
        assertEquals(401, mvc.perform(MockMvcRequestBuilders.get("/api/stories/tray")).andReturn().getResponse().getStatus());
    }

    @Test
    void videoUploadIsRejectedAt400() throws Exception {
        MockHttpServletResponse r = mvc.perform(MockMvcRequestBuilders.multipart("/api/posts/media")
                .file(new org.springframework.mock.web.MockMultipartFile("file", "v.mp4", "video/mp4", new byte[] {0, 0, 0, 24}))
                .with(authentication(user()))).andReturn().getResponse();
        assertEquals(400, r.getStatus());
        assertTrue(r.getContentAsString().contains("POST_VIDEO_NOT_ALLOWED"));
    }
}
