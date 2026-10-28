package edu.bingol.backend.media.transcode;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import edu.bingol.backend.post.media.PostMedia;
import java.time.Instant;
import java.util.List;
import edu.bingol.backend.common.RateLimiter;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

/** GET /api/admin/ops/transcode/stats: yalniz ADMIN; sayaclar kuyruk satirlarindan gelir. */
@SpringBootTest
class AdminTranscodeControllerTest {

    @Autowired WebApplicationContext ctx;
    /** Testlerde Redis yok: hiz siniri sahte (HTTP sozlesmesi sinanir, sinirlayici degil). */
    @MockitoBean RateLimiter limiter;
    @Autowired PostMediaTranscodeRepository repo;
    MockMvc mvc;

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.webAppContextSetup(ctx).apply(springSecurity()).build();
    }

    private static UsernamePasswordAuthenticationToken token(String role) {
        return new UsernamePasswordAuthenticationToken(991001L, null, List.of(new SimpleGrantedAuthority(role)));
    }

    private void video(String status, Instant at) {
        PostMedia m = new PostMedia();
        m.setOwnerId(1L);
        m.setKind(PostMedia.VIDEO);
        m.setStorageKey("stats-" + System.nanoTime() + ".mp4");
        m.setContentType("video/mp4");
        m.setBytes(10);
        m.setTranscodeStatus(status);
        m.setTranscodeAt(at);
        repo.save(m);
    }

    private JsonNode stats() throws Exception {
        MockHttpServletResponse r = mvc.perform(get("/api/admin/ops/transcode/stats").with(authentication(token("ROLE_ADMIN"))))
                .andReturn().getResponse();
        assertEquals(200, r.getStatus());
        return new ObjectMapper().readTree(r.getContentAsString());
    }

    @Test
    void onlyAdminCanRead() throws Exception {
        assertEquals(401, mvc.perform(get("/api/admin/ops/transcode/stats")).andReturn().getResponse().getStatus());
        assertEquals(403, mvc.perform(get("/api/admin/ops/transcode/stats").with(authentication(token("ROLE_USER"))))
                .andReturn().getResponse().getStatus());
    }

    @Test
    void countersFollowQueueRows() throws Exception {
        JsonNode before = stats();
        video("PENDING", null);
        video("PENDING", null);
        video("PROCESSING", Instant.now());
        video("FAILED", Instant.now().minusSeconds(60));
        video("DONE", Instant.now().minusSeconds(60));
        video("DONE", Instant.now().minusSeconds(3 * 24 * 3600L)); // 24 saatten eski: sayilmaz
        JsonNode after = stats();
        assertEquals(2, after.get("pending").asLong() - before.get("pending").asLong());
        assertEquals(1, after.get("processing").asLong() - before.get("processing").asLong());
        assertEquals(1, after.get("failed").asLong() - before.get("failed").asLong());
        assertEquals(1, after.get("doneLast24h").asLong() - before.get("doneLast24h").asLong());
        assertTrue(after.has("enabled"));
    }
}
