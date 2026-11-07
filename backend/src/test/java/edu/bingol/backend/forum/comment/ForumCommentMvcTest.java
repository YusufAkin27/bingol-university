package edu.bingol.backend.forum.comment;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.startsWith;
import static org.mockito.Mockito.verify;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.forum.topic.ForumTopic;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

/** Forum yorum HTTP sozlesmesi (H2): alan adlari, durum kodlari, hata govdesi, rate limit, anonimlik (ham JSON). */
@SpringBootTest(properties = "spring.messages.basename=i18n/messages,i18n/forum,i18n/forumc")
class ForumCommentMvcTest {

    private static final ObjectMapper OM = new ObjectMapper();

    @Autowired WebApplicationContext ctx;
    @Autowired UserRepository users;
    @Autowired jakarta.persistence.EntityManager em;
    @Autowired org.springframework.transaction.PlatformTransactionManager tm;
    @Autowired org.springframework.jdbc.core.JdbcTemplate jdbc;
    @MockitoBean RateLimiter limiter;
    MockMvc mvc;

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.webAppContextSetup(ctx).apply(springSecurity()).build();
    }

    private User user(String name) {
        User u = new User();
        u.setEmail(name + "-" + UUID.randomUUID() + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName(name);
        u.setEmailVerified(true);
        return users.save(u);
    }

    private ForumTopic topic(User author) {
        return ForumTopicFixtures.topic(em, tm, author.getId(), false);
    }

    private MockHttpServletResponse as(User u, MockHttpServletRequestBuilder b) throws Exception {
        var token = new UsernamePasswordAuthenticationToken(u.getId(), null, List.of(new SimpleGrantedAuthority("ROLE_USER")));
        return mvc.perform(b.with(authentication(token))).andReturn().getResponse();
    }

    private static JsonNode json(MockHttpServletResponse r) throws Exception {
        return OM.readTree(r.getContentAsString(StandardCharsets.UTF_8));
    }

    private MockHttpServletRequestBuilder createReq(ForumTopic t, String body) {
        return post("/api/forum/topics/" + t.getId() + "/comments").contentType(MediaType.APPLICATION_JSON).content(body);
    }

    @Test
    void createReturns201WithContractFieldsAndRateLimits() throws Exception {
        User owner = user("sahip");
        User a = user("ali");
        ForumTopic t = topic(owner);
        MockHttpServletResponse r = as(a, createReq(t, "{\"body\":\"merhaba\"}").header("Idempotency-Key", "abcdefgh-12345"));
        assertEquals(201, r.getStatus());
        JsonNode c = json(r);
        for (String f : List.of("id", "topicId", "parentCommentId", "depth", "author", "body", "anonymous", "createdAt", "editedAt",
                "likeCount", "likedByMe", "savedByMe", "replyCount", "mine", "deleted", "canModerate", "topicAuthor")) {
            assertTrue(c.has(f), "alan eksik: " + f);
        }
        assertTrue(c.get("parentCommentId").isNull());
        assertTrue(c.get("editedAt").isNull());
        assertEquals("merhaba", c.get("body").asText());
        assertEquals(t.getId(), c.get("topicId").asLong());
        assertEquals(a.getId(), c.get("author").get("userId").asLong());
        assertTrue(c.get("mine").asBoolean());
        assertFalse(c.has("path"), "path yalniz GET /comments/{id}'de");
        verify(limiter, org.mockito.Mockito.atLeastOnce()).check(startsWith("forum:comment:create:"), eq(20), eq(Duration.ofMinutes(1)));

        // cift gonderim: ayni anahtar ayni yorum
        MockHttpServletResponse again = as(a, createReq(t, "{\"body\":\"merhaba\"}").header("Idempotency-Key", "abcdefgh-12345"));
        assertEquals(c.get("id").asLong(), json(again).get("id").asLong());
    }

    @Test
    void listEnvelopeAndGetWithPath() throws Exception {
        User owner = user("sahip");
        User a = user("ali");
        ForumTopic t = topic(owner);
        long top = json(as(a, createReq(t, "{\"body\":\"ust\"}"))).get("id").asLong();
        long child = json(as(owner, createReq(t, "{\"body\":\"alt\",\"parentCommentId\":" + top + "}"))).get("id").asLong();

        JsonNode page = json(as(a, get("/api/forum/topics/" + t.getId() + "/comments?sort=NEWEST&size=5")));
        assertTrue(page.has("items") && page.has("nextCursor"));
        assertTrue(page.get("nextCursor").isNull());
        JsonNode first = page.get("items").get(0);
        assertEquals(top, first.get("id").asLong());
        assertEquals(1, first.get("replyCount").asInt());
        assertEquals(child, first.get("replyPreview").get(0).get("id").asLong());

        JsonNode replies = json(as(a, get("/api/forum/comments/" + top + "/replies")));
        assertEquals(child, replies.get("items").get(0).get("id").asLong());

        JsonNode single = json(as(a, get("/api/forum/comments/" + child)));
        assertEquals(top, single.get("path").get(0).asLong());
        assertEquals(1, single.get("depth").asInt());
        assertTrue(single.get("topicAuthor").asBoolean(), "konu sahibinin yorumu");
        assertEquals(400, as(a, get("/api/forum/topics/" + t.getId() + "/comments?sort=EN_COK")).getStatus());
        assertEquals(404, as(a, get("/api/forum/comments/987654")).getStatus());
        assertEquals(404, as(a, get("/api/forum/topics/987654/comments")).getStatus());
    }

    @Test
    void ownershipErrorsAreJsonWithTranslatedMessage() throws Exception {
        User owner = user("sahip");
        User a = user("ali");
        User b = user("veli");
        ForumTopic t = topic(owner);
        long id = json(as(a, createReq(t, "{\"body\":\"benim\"}"))).get("id").asLong();

        MockHttpServletResponse r = as(b, patch("/api/forum/comments/" + id).contentType(MediaType.APPLICATION_JSON)
                .content("{\"body\":\"ele gecirdim\"}"));
        assertEquals(403, r.getStatus());
        assertEquals("FORUM_NOT_OWNER", json(r).get("code").asText());
        MockHttpServletResponse en = as(b, delete("/api/forum/comments/" + id).header("Accept-Language", "en"));
        assertEquals(403, en.getStatus());
        assertEquals("FORUM_NOT_OWNER", json(en).get("code").asText());
        assertFalse(json(en).get("message").asText().isBlank());

        MockHttpServletResponse ok = as(a, patch("/api/forum/comments/" + id).contentType(MediaType.APPLICATION_JSON)
                .content("{\"body\":\"duzenlendi\"}"));
        assertEquals(200, ok.getStatus());
        assertEquals("duzenlendi", json(ok).get("body").asText());
        assertFalse(json(ok).get("editedAt").isNull());
        verify(limiter, org.mockito.Mockito.atLeastOnce()).check(startsWith("forum:comment:write:"), eq(60), any(Duration.class));

        assertEquals(204, as(a, delete("/api/forum/comments/" + id)).getStatus());
        assertEquals(404, as(a, get("/api/forum/comments/" + id)).getStatus());
    }

    @Test
    void placeholderJsonCarriesNullBodyAndAuthor() throws Exception {
        User owner = user("sahip");
        User a = user("ali");
        ForumTopic t = topic(owner);
        long id = json(as(a, createReq(t, "{\"body\":\"silinecek ozel metin\"}"))).get("id").asLong();
        as(owner, createReq(t, "{\"body\":\"cevap\",\"parentCommentId\":" + id + "}"));
        as(a, delete("/api/forum/comments/" + id));
        String raw = as(owner, get("/api/forum/topics/" + t.getId() + "/comments")).getContentAsString(StandardCharsets.UTF_8);
        assertFalse(raw.contains("silinecek ozel metin"));
        JsonNode item = OM.readTree(raw).get("items").get(0);
        assertTrue(item.get("deleted").asBoolean());
        assertTrue(item.get("body").isNull());
        assertTrue(item.get("author").isNull());
    }

    @Test
    void anonymousJsonNeverContainsIdentity() throws Exception {
        User owner = user("sahip");
        User secret = user("cok-gizli-kisi");
        User viewer = user("izleyen");
        ForumTopic t = topic(owner);
        MockHttpServletResponse r = as(secret, createReq(t, "{\"body\":\"anonim yorum\",\"anonymous\":true}"));
        assertEquals(201, r.getStatus());
        long id = json(r).get("id").asLong();
        for (String raw : List.of(
                as(viewer, get("/api/forum/topics/" + t.getId() + "/comments")).getContentAsString(StandardCharsets.UTF_8),
                as(viewer, get("/api/forum/comments/" + id)).getContentAsString(StandardCharsets.UTF_8))) {
            assertTrue(raw.contains("Anonim #"));
            assertFalse(raw.contains("cok-gizli-kisi"));
            assertFalse(raw.contains(secret.getEmail()));
            assertFalse(raw.contains("\"userId\":" + secret.getId()));
        }
        JsonNode author = json(as(viewer, get("/api/forum/comments/" + id))).get("author");
        assertTrue(author.get("userId").isNull());
        assertTrue(author.get("avatarUrl").isNull());
        assertTrue(author.get("anonymous").asBoolean());
        // Accept-Language: ar / en
        String en = as(viewer, get("/api/forum/comments/" + id).header("Accept-Language", "en")).getContentAsString(StandardCharsets.UTF_8);
        assertTrue(en.contains("Anonymous #"), en);
    }

    @Test
    void likeAndBookmarkEndpoints() throws Exception {
        User owner = user("sahip");
        User a = user("ali");
        ForumTopic t = topic(owner);
        long id = json(as(owner, createReq(t, "{\"body\":\"begen\"}"))).get("id").asLong();
        JsonNode l = json(as(a, put("/api/forum/comments/" + id + "/like")));
        assertTrue(l.get("liked").asBoolean());
        assertEquals(1, l.get("likeCount").asInt());
        assertEquals(1, json(as(a, put("/api/forum/comments/" + id + "/like"))).get("likeCount").asInt());
        JsonNode u = json(as(a, delete("/api/forum/comments/" + id + "/like")));
        assertFalse(u.get("liked").asBoolean());
        assertEquals(0, u.get("likeCount").asInt());
        verify(limiter, org.mockito.Mockito.atLeastOnce()).check(startsWith("forum:comment:like:"), eq(120), any(Duration.class));
        assertTrue(json(as(a, put("/api/forum/comments/" + id + "/bookmark"))).get("saved").asBoolean());
        assertTrue(json(as(a, get("/api/forum/comments/" + id))).get("savedByMe").asBoolean());
        assertFalse(json(as(a, delete("/api/forum/comments/" + id + "/bookmark"))).get("saved").asBoolean());
    }

    @Test
    void lockedTopicIs409AndEmptyBodyIs400AndLongBodyIs422() throws Exception {
        User owner = user("sahip");
        User a = user("ali");
        ForumTopic t = topic(owner);
        assertEquals(400, as(a, createReq(t, "{\"body\":\"   \"}")).getStatus());
        assertEquals("FORUM_COMMENT_EMPTY", json(as(a, createReq(t, "{}"))).get("code").asText());
        MockHttpServletResponse big = as(a, createReq(t, "{\"body\":\"" + "x".repeat(4001) + "\"}"));
        assertEquals(422, big.getStatus());
        assertEquals("FORUM_COMMENT_TOO_LONG", json(big).get("code").asText());
        jdbc.update("UPDATE forum_topic SET locked_at = CURRENT_TIMESTAMP WHERE id = ?", t.getId());
        MockHttpServletResponse locked = as(a, createReq(t, "{\"body\":\"yeni\"}"));
        assertEquals(409, locked.getStatus());
        assertEquals("FORUM_TOPIC_LOCKED", json(locked).get("code").asText());
    }

    @Test
    void anonymousRequestIs401() throws Exception {
        assertEquals(401, mvc.perform(get("/api/forum/comments/1")).andReturn().getResponse().getStatus());
        assertEquals(401, mvc.perform(put("/api/forum/comments/1/like")).andReturn().getResponse().getStatus());
    }

    @Test
    void rateLimiterIsCalledOnEveryWriteAndRead() throws Exception {
        User owner = user("sahip");
        User a = user("ali");
        ForumTopic t = topic(owner);
        as(a, get("/api/forum/topics/" + t.getId() + "/comments"));
        verify(limiter, org.mockito.Mockito.atLeastOnce()).check(startsWith("forum:comment:read:"), eq(240), any(Duration.class));
        as(a, put("/api/forum/comments/55/bookmark"));
        verify(limiter, org.mockito.Mockito.atLeastOnce()).check(startsWith("forum:comment:save:"), eq(120), any(Duration.class));
    }
}
