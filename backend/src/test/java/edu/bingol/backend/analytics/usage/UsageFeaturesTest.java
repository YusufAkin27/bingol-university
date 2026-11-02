package edu.bingol.backend.analytics.usage;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class UsageFeaturesTest {

    @Test
    void screensAndActionsMapToFeatures() {
        assertEquals("news", UsageFeatures.featureOf("news_list"));
        assertEquals("news", UsageFeatures.featureOf("announcement_open"));
        assertEquals("menu", UsageFeatures.featureOf("menu"));
        assertEquals("menu", UsageFeatures.featureOf("menu_view"));
        assertEquals("events", UsageFeatures.featureOf("events"));
        assertEquals("events", UsageFeatures.featureOf("event_rsvp"));
        assertEquals("clubs", UsageFeatures.featureOf("club_join"));
        assertEquals("chat", UsageFeatures.featureOf("message_send"));
        assertEquals("map", UsageFeatures.featureOf("campus_map"));
        assertEquals("map", UsageFeatures.featureOf("map_place_open"));
        assertEquals("polls", UsageFeatures.featureOf("poll_vote"));
        assertEquals("academic", UsageFeatures.featureOf("exam_open"));
        assertEquals("search", UsageFeatures.featureOf("search_query"));
    }

    @Test
    void realMobileKeysMap() {
        assertEquals("chat", UsageFeatures.featureOf("chat")); // alt gezinme sekmesi
        assertEquals("news", UsageFeatures.featureOf("announcements"));
        assertEquals("news", UsageFeatures.featureOf("saved_news"));
        assertEquals("events", UsageFeatures.featureOf("my_events"));
        assertEquals("clubs", UsageFeatures.featureOf("my_clubs"));
        assertEquals("chat", UsageFeatures.featureOf("new_chat"));
        assertEquals("chat", UsageFeatures.featureOf("message_requests"));
        assertEquals("polls", UsageFeatures.featureOf("poll_list"));
        assertEquals("academic", UsageFeatures.featureOf("timetable"));
        assertEquals("academic", UsageFeatures.featureOf("exams"));
        assertEquals("academic", UsageFeatures.featureOf("course_add"));
        assertNull(UsageFeatures.featureOf("app_error"));
    }

    @Test
    void unrelatedOrLookalikeKeysDoNotMatch() {
        assertNull(UsageFeatures.featureOf("home"));
        assertNull(UsageFeatures.featureOf("newsletter"));
        assertNull(UsageFeatures.featureOf("mapping"));
        assertNull(UsageFeatures.featureOf(null));
    }

    @Test
    void sqlCaseIsBuiltFromConstantsOnly() {
        String sql = UsageFeatures.sqlCase("k");
        assertTrue(sql.startsWith("CASE WHEN (k = 'news' OR starts_with(k, 'news_'))"), sql);
        assertTrue(sql.endsWith(" END"));
        assertTrue(sql.matches("[A-Za-z0-9_ '(),=]+"), sql);
    }
}
