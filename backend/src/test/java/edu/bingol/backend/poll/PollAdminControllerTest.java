package edu.bingol.backend.poll;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;
import java.util.UUID;
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
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

/**
 * Yonetim paneli anket sozlesmesi (HTTP): sayfali liste {items,page,size,total}, /stats, /{id}, kapat/iptal, sil, toplu,
 * CSV; panelin olusturma/duzenleme icin kullandigi POST /api/polls ve PATCH /api/polls/{id} (ADMIN JWT).
 */
@SpringBootTest
class PollAdminControllerTest {

    private static final ObjectMapper OM = new ObjectMapper();

    @Autowired WebApplicationContext ctx;
    /** Testlerde Redis yok: hiz siniri sahte (HTTP sozlesmesi sinanir, sinirlayici degil). */
    @MockitoBean RateLimiter limiter;
    MockMvc mvc;

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.webAppContextSetup(ctx).apply(springSecurity()).build();
    }

    private static UsernamePasswordAuthenticationToken admin() {
        return new UsernamePasswordAuthenticationToken(990001L, null, List.of(new SimpleGrantedAuthority("ROLE_ADMIN")));
    }

    private static UsernamePasswordAuthenticationToken user() {
        return new UsernamePasswordAuthenticationToken(990002L, null, List.of(new SimpleGrantedAuthority("ROLE_USER")));
    }

    private MockHttpServletResponse call(MockHttpServletRequestBuilder b) throws Exception {
        return mvc.perform(b.with(authentication(admin()))).andReturn().getResponse();
    }

    private JsonNode createGlobal(String title, boolean draft) throws Exception {
        String body = "{\"title\":\"" + title + "\",\"scope\":\"GLOBAL\",\"type\":\"SINGLE\",\"options\":[\"Evet\",\"Hayir\"],"
                + "\"anonymous\":true,\"showResults\":\"ALWAYS\",\"draft\":" + draft + "}";
        MockHttpServletResponse r = call(post("/api/polls").contentType("application/json").content(body));
        assertEquals(201, r.getStatus(), r.getContentAsString());
        return OM.readTree(r.getContentAsString());
    }

    @Test
    void adminEndpointsRejectAnonymousAndPlainUsers() throws Exception {
        for (String path : List.of("/api/admin/polls", "/api/admin/polls/stats", "/api/admin/polls/1")) {
            assertEquals(401, mvc.perform(get(path)).andReturn().getResponse().getStatus(), path);
            assertEquals(403, mvc.perform(get(path).with(authentication(user()))).andReturn().getResponse().getStatus(), path);
        }
        assertEquals(403, mvc.perform(post("/api/admin/polls/bulk").with(authentication(user()))
                .contentType("application/json").content("{\"ids\":[1],\"action\":\"CLOSE\"}")).andReturn().getResponse().getStatus());
    }

    @Test
    void listIsPagedAndFilteredAndStatsMatchTheContract() throws Exception {
        String marker = "Sozlesme" + UUID.randomUUID().toString().substring(0, 8);
        createGlobal(marker + " acik", false);
        createGlobal(marker + " taslak", true);

        MockHttpServletResponse r = call(get("/api/admin/polls").param("q", marker).param("size", "1").param("page", "0"));
        assertEquals(200, r.getStatus());
        JsonNode page = OM.readTree(r.getContentAsString());
        assertEquals(1, page.get("items").size());
        assertEquals(0, page.get("page").asInt());
        assertEquals(1, page.get("size").asInt());
        assertEquals(2, page.get("total").asLong());
        JsonNode row = page.get("items").get(0);
        for (String f : List.of("id", "title", "type", "scope", "status", "state", "anonymous", "totalVotes", "createdAt")) {
            assertTrue(row.has(f), "AdminPollRow." + f);
        }

        JsonNode drafts = OM.readTree(call(get("/api/admin/polls").param("q", marker).param("status", "DRAFT")).getContentAsString());
        assertEquals(1, drafts.get("total").asLong());
        assertEquals("DRAFT", drafts.get("items").get(0).get("status").asText());
        JsonNode menu = OM.readTree(call(get("/api/admin/polls").param("q", marker).param("scope", "MENU")).getContentAsString());
        assertEquals(0, menu.get("total").asLong());

        JsonNode stats = OM.readTree(call(get("/api/admin/polls/stats")).getContentAsString());
        for (String f : List.of("total", "open", "closed", "draft", "cancelled", "totalVotes", "byScope")) {
            assertTrue(stats.has(f), "AdminStats." + f);
        }
        assertTrue(stats.get("byScope").has("GLOBAL") && stats.get("byScope").has("COMMUNITY") && stats.get("byScope").has("MENU"));

        MockHttpServletResponse bad = call(get("/api/admin/polls").param("scope", "GENERAL"));
        assertEquals(400, bad.getStatus());
        assertEquals("POLL_INVALID", OM.readTree(bad.getContentAsString()).get("code").asText());
    }

    @Test
    void createEditCloseCancelDeleteAndCsvFlowWorksWithAdminJwt() throws Exception {
        JsonNode created = createGlobal("Akis " + UUID.randomUUID().toString().substring(0, 6), true);
        long id = created.get("id").asLong();
        assertEquals("DRAFT", created.get("status").asText());

        // Duzenleme: panel PATCH /api/polls/{id} kullanir (taslak -> yayin).
        MockHttpServletResponse upd = call(patch("/api/polls/" + id).contentType("application/json")
                .content("{\"title\":\"Yeni baslik\",\"draft\":false}"));
        assertEquals(200, upd.getStatus(), upd.getContentAsString());
        JsonNode view = OM.readTree(upd.getContentAsString());
        assertEquals("Yeni baslik", view.get("title").asText());
        assertEquals("OPEN", view.get("status").asText());

        JsonNode detail = OM.readTree(call(get("/api/admin/polls/" + id)).getContentAsString());
        assertTrue(detail.get("resultsVisible").asBoolean());
        assertTrue(detail.get("canManage").asBoolean());
        assertEquals(2, detail.get("results").size());
        assertFalse(detail.toString().contains("voterId") || detail.toString().contains("userId"), "gizli oyda kimlik yok");

        MockHttpServletResponse csv = call(get("/api/admin/polls/" + id + "/export.csv"));
        assertEquals(200, csv.getStatus());
        assertTrue(csv.getContentType().startsWith("text/csv"));
        assertTrue(csv.getContentAsString().startsWith("optionId,text,count,percent,score"));

        JsonNode closed = OM.readTree(call(post("/api/admin/polls/" + id + "/close")).getContentAsString());
        assertEquals("CLOSED", closed.get("status").asText());
        // Kapali ankete PATCH 409.
        assertEquals(409, call(patch("/api/polls/" + id).contentType("application/json").content("{\"title\":\"x\"}")).getStatus());

        JsonNode other = createGlobal("Iptal " + UUID.randomUUID().toString().substring(0, 6), false);
        JsonNode cancelled = OM.readTree(call(post("/api/admin/polls/" + other.get("id").asLong() + "/cancel")).getContentAsString());
        assertEquals("CANCELLED", cancelled.get("status").asText());

        assertEquals(204, call(delete("/api/admin/polls/" + id)).getStatus());
        MockHttpServletResponse gone = call(get("/api/admin/polls/" + id));
        assertEquals(404, gone.getStatus());
        assertEquals("POLL_NOT_FOUND", OM.readTree(gone.getContentAsString()).get("code").asText());
    }

    @Test
    void bulkReturnsDoneAndSkippedAndValidatesInput() throws Exception {
        long a = createGlobal("Toplu " + UUID.randomUUID().toString().substring(0, 6), false).get("id").asLong();
        long b = createGlobal("Toplu " + UUID.randomUUID().toString().substring(0, 6), false).get("id").asLong();
        MockHttpServletResponse r = call(post("/api/admin/polls/bulk").contentType("application/json")
                .header("X-Admin-Reason", "toplu kapatma testi")
                .content("{\"ids\":[" + a + "," + b + ",424242],\"action\":\"CLOSE\"}"));
        assertEquals(200, r.getStatus(), r.getContentAsString());
        JsonNode res = OM.readTree(r.getContentAsString());
        assertEquals(2, res.get("done").asInt());
        assertEquals(1, res.get("skipped").asInt());

        MockHttpServletResponse bad = call(post("/api/admin/polls/bulk").contentType("application/json")
                .header("X-Admin-Reason", "gecersiz eylem testi").content("{\"ids\":[1],\"action\":\"NUKE\"}"));
        assertEquals(400, bad.getStatus());
    }
}
