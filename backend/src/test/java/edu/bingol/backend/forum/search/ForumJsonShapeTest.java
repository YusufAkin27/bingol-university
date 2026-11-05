package edu.bingol.backend.forum.search;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import edu.bingol.backend.forum.profile.ForumProfileService.ProfilePage;
import edu.bingol.backend.forum.profile.ForumProfileService.SavedItem;
import edu.bingol.backend.forum.profile.ForumProfileService.Summary;
import edu.bingol.backend.forum.topic.dto.Author;
import edu.bingol.backend.forum.topic.dto.ForumPage;
import edu.bingol.backend.forum.topic.dto.TopicSummary;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

/** Istemci sozlesmesi: arama sonucu TopicSummary ile DUZ birlesir; locked yalniz true iken yazilir; kaydedilen oge sekli. */
class ForumJsonShapeTest {

    /** Uretimle ayni seri hale getirici: Spring Boot 4 MVC Jackson 3 (tools.jackson) kullanir. */
    private static final JsonMapper OM = JsonMapper.builder().build();

    private static TopicSummary summary(long id) {
        return new TopicSummary(id, "Baslik", "onizleme", null, new Author(null, "Anonim #1", null, null, true),
                Instant.parse("2026-11-05T10:00:00Z"), null, 3, 2, false, false, false, null, 0, false, false, false,
                false, false, "ACTIVE");
    }

    @Test
    void searchItemIsFlatTopicSummaryPlusMatchedInAndSnippet() throws Exception {
        ForumPage<ForumSearchItem> page = new ForumPage<>(List.of(new ForumSearchItem(summary(9), "BODY", "parca")), "abc");
        JsonNode n = OM.readTree(OM.writeValueAsString(page));
        JsonNode item = n.get("items").get(0);
        assertEquals(9, item.get("id").asInt());
        assertEquals("Baslik", item.get("title").asText());
        assertEquals("BODY", item.get("matchedIn").asText());
        assertEquals("parca", item.get("snippet").asText());
        assertFalse(item.has("topic"), "TopicSummary icice degil duz olmali");
        assertEquals("abc", n.get("nextCursor").asText());
        assertTrue(item.get("author").get("anonymous").asBoolean());
        assertTrue(item.get("author").get("userId").isNull());
    }

    @Test
    void lockedIsWrittenOnlyWhenTrue() throws Exception {
        JsonNode open = OM.readTree(OM.writeValueAsString(
                new ProfilePage<>(List.of(summary(1)), null, null)));
        assertFalse(open.has("locked"));
        assertTrue(open.has("nextCursor"));
        JsonNode locked = OM.readTree(OM.writeValueAsString(new ProfilePage<TopicSummary>(List.of(), null, Boolean.TRUE)));
        assertTrue(locked.get("locked").asBoolean());
        assertEquals(0, locked.get("items").size());
        JsonNode sum = OM.readTree(OM.writeValueAsString(new Summary(2, 5, null)));
        assertEquals(2, sum.get("topicCount").asInt());
        assertFalse(sum.has("locked"));
    }

    @Test
    void savedItemCarriesTypeAndTopicCardPlusFlatComment() throws Exception {
        SavedItem t = new SavedItem("TOPIC", Instant.parse("2026-11-05T10:00:00Z"), summary(4), null);
        JsonNode tn = OM.readTree(OM.writeValueAsString(t));
        assertEquals("TOPIC", tn.get("type").asText());
        assertEquals(4, tn.get("topic").get("id").asInt());
        assertTrue(tn.get("comment").isNull());

        SavedItem c = new SavedItem("COMMENT", Instant.parse("2026-11-05T10:00:00Z"), summary(12),
                Map.of("id", 77, "body", "x", "topicId", 12, "topicTitle", "Konu"));
        JsonNode cn = OM.readTree(OM.writeValueAsString(c));
        assertEquals("COMMENT", cn.get("type").asText());
        assertEquals(12, cn.get("topic").get("id").asInt());
        assertEquals(77, cn.get("comment").get("id").asInt());
        assertEquals(12, cn.get("comment").get("topicId").asInt());
        assertEquals("Konu", cn.get("comment").get("topicTitle").asText());
    }
}
