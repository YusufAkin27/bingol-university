package edu.bingol.backend.analytics;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

import edu.bingol.backend.analytics.AnalyticsDtos.EventIn;
import edu.bingol.backend.analytics.AnalyticsService.ValidEvent;
import edu.bingol.backend.common.ApiException;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

class AnalyticsServiceTest {

    private static final Instant NOW = Instant.parse("2026-10-23T12:00:00Z");

    private static EventIn ev(String name) {
        return new EventIn(name, null, null, null);
    }

    private static List<ValidEvent> ok(EventIn... e) {
        return AnalyticsService.validate(List.of(e), NOW);
    }

    private static void rejected(EventIn... e) {
        ApiException ex = assertThrows(ApiException.class, () -> AnalyticsService.validate(List.of(e), NOW));
        assertEquals("INVALID_EVENT", ex.code());
        assertEquals(400, ex.status().value());
    }

    @Test
    void validNamesAccepted() {
        assertEquals(1, ok(ev("screen_view")).size());
        assertEquals(1, ok(ev("a")).size());
        assertEquals(1, ok(ev("x".repeat(40))).size());
        assertEquals(1, ok(ev("event_2")).size());
    }

    @Test
    void invalidNamesRejected() {
        rejected(ev(null));
        rejected(ev(""));
        rejected(ev("Screen_View"));
        rejected(ev("screen-view"));
        rejected(ev("screen view"));
        rejected(ev("x".repeat(41)));
        rejected(ev("ekran_görünüm"));
        rejected(ev("a'; drop table"));
    }

    @Test
    void atMost50EventsPerRequest() {
        List<EventIn> fifty = new ArrayList<>();
        for (int i = 0; i < 50; i++) {
            fifty.add(ev("e" + i));
        }
        assertEquals(50, AnalyticsService.validate(fifty, NOW).size());
        fifty.add(ev("one_more"));
        assertThrows(ApiException.class, () -> AnalyticsService.validate(fifty, NOW));
    }

    @Test
    void oneBadEventRejectsTheWholeBatch() {
        assertThrows(ApiException.class, () -> AnalyticsService.validate(List.of(ev("good"), ev("BAD")), NOW));
    }

    @Test
    void screenPatternChecked() {
        assertEquals("home/news", ok(new EventIn("v", "home/news", null, null)).get(0).screen());
        assertNull(ok(new EventIn("v", "  ", null, null)).get(0).screen());
        rejected(new EventIn("v", "bad screen!", null, null));
        rejected(new EventIn("v", "s".repeat(61), null, null));
    }

    @Test
    void propsLimits() {
        Map<String, Object> five = new LinkedHashMap<>();
        for (int i = 0; i < 5; i++) {
            five.put("k" + i, "v" + i);
        }
        assertEquals("{\"k0\":\"v0\",\"k1\":\"v1\",\"k2\":\"v2\",\"k3\":\"v3\",\"k4\":\"v4\"}",
                ok(new EventIn("e", null, five, null)).get(0).propsJson());

        Map<String, Object> six = new LinkedHashMap<>(five);
        six.put("k5", "v");
        rejected(new EventIn("e", null, six, null));
    }

    @Test
    void propsValueLengthAndPersonalDataGuard() {
        rejected(new EventIn("e", null, Map.of("q", "x".repeat(101)), null));
        assertEquals(1, ok(new EventIn("e", null, Map.of("q", "x".repeat(100)), null)).size());
        // E-posta benzeri deger kisisel veri sayilir
        rejected(new EventIn("e", null, Map.of("who", "ali@bingol.edu.tr"), null));
        // Telefon / TC kimlik no benzeri uzun rakam dizisi
        rejected(new EventIn("e", null, Map.of("tel", "05321234567"), null));
        rejected(new EventIn("e", null, Map.of("tc", 12345678901L), null));
        assertEquals(1, ok(new EventIn("e", null, Map.of("count", 123456789), null)).size());
        // Anahtar bicimi
        rejected(new EventIn("e", null, Map.of("Bad-Key", "v"), null));
        // Ic ice nesne / dizi yasak
        rejected(new EventIn("e", null, Map.of("k", Map.of("a", "b")), null));
        rejected(new EventIn("e", null, Map.of("k", List.of("a")), null));
    }

    @Test
    void scalarPropsKeepTheirJsonTypeAndStringsAreEscaped() {
        Map<String, Object> p = new LinkedHashMap<>();
        p.put("n", 3);
        p.put("b", true);
        p.put("s", "a\"b\\c\nd");
        assertEquals("{\"n\":3,\"b\":true,\"s\":\"a\\\"b\\\\c\\nd\"}", AnalyticsService.propsJson(p));
    }

    @Test
    void emptyPropsBecomeNull() {
        assertNull(AnalyticsService.propsJson(null));
        assertNull(AnalyticsService.propsJson(Map.of()));
    }

    @Test
    void controlCharactersEscapedAsUnicode() {
        assertEquals("\"a\\u0001b\"", AnalyticsService.quote("a\u0001b"));
    }

    @Test
    void timestampsClampedToServerTime() {
        assertEquals(NOW, AnalyticsService.time(null, NOW).toInstant());
        Instant recent = NOW.minusSeconds(3600);
        assertEquals(recent, AnalyticsService.time(recent, NOW).toInstant());
        // 7 gunden eski ve gelecekteki (saat sapmasi payindan fazla) saatler sunucu saatine cekilir
        assertEquals(NOW, AnalyticsService.time(NOW.minus(java.time.Duration.ofDays(8)), NOW).toInstant());
        assertEquals(NOW, AnalyticsService.time(NOW.plusSeconds(3600), NOW).toInstant());
        Instant slightlyAhead = NOW.plusSeconds(60);
        assertEquals(slightlyAhead, AnalyticsService.time(slightlyAhead, NOW).toInstant());
    }
}
