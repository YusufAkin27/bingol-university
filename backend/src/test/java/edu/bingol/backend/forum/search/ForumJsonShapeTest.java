package edu.bingol.backend.forum.search;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import edu.bingol.backend.forum.profile.ForumProfileService.ProfileComment;
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

    private static final ObjectMapper OM = new ObjectMapper().findAndRegisterModules()
            .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);

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
    void savedItemCarriesKindAndExactlyOneOfTopicOrComment() throws Exception {
        SavedItem t = new SavedItem("TOPIC", Instant.parse("2026-11-05T10:00:00Z"), summary(4), null);
        JsonNode tn = OM.readTree(OM.writeValueAsString(t));
        assertEquals("TOPIC", tn.get("kind").asText());
        assertEquals(4, tn.get("topic").get("id").asInt());
        assertTrue(tn.get("comment").isNull());

        SavedItem c = new SavedItem("COMMENT", Instant.parse("2026-11-05T10:00:00Z"), null,
                new ProfileComment(Map.of("id", 77, "body", "x"), 12, "Konu"));
        JsonNode cn = OM.readTree(OM.writeValueAsString(c));
        assertTrue(cn.get("topic").isNull());
        assertEquals(77, cn.get("comment").get("comment").get("id").asInt());
        assertEquals(12, cn.get("comment").get("topicId").asInt());
        assertEquals("Konu", cn.get("comment").get("topicTitle").asText());
    }
}
