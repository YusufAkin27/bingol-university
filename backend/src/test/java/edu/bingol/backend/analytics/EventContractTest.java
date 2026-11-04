package edu.bingol.backend.analytics;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.analytics.AnalyticsDtos.EventIn;
import edu.bingol.backend.analytics.AnalyticsService.ValidEvent;
import edu.bingol.backend.common.ApiException;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

/** Davranis olay sozlesmesi dogrulamasi: sid, sure, eylem beyaz listesi; bozuk olay tek tek elenir. */
class EventContractTest {

    private static final Instant NOW = Instant.parse("2026-11-02T12:00:00Z");

    private static Map<String, Object> p(Object... kv) {
        Map<String, Object> m = new LinkedHashMap<>();
        for (int i = 0; i < kv.length; i += 2) {
            m.put((String) kv[i], kv[i + 1]);
        }
        return m;
    }

    private static List<ValidEvent> run(EventIn... e) {
        return AnalyticsService.validate(List.of(e), NOW);
    }

    @Test
    void sidPatternChecked() {
        assertEquals(1, run(new EventIn("session_start", null, p("sid", "abcd1234"), null)).size());
        assertEquals(1, run(new EventIn("session_start", null, p("sid", "a".repeat(32)), null)).size());
        // desen disi: olay elenir, istek dusmez
        assertEquals(0, run(new EventIn("session_start", null, p("sid", "short"), null)).size());
        assertEquals(0, run(new EventIn("session_start", null, p("sid", "a".repeat(33)), null)).size());
        assertEquals(0, run(new EventIn("session_start", null, p("sid", "ABCD1234"), null)).size());
        assertEquals(0, run(new EventIn("session_start", null, p("sid", 12345678), null)).size());
        assertEquals(0, run(new EventIn("screen_view", "home", p("sid", "bad sid!"), null)).size());
    }

    @Test
    void sidOfOnlyDigitsIsNotTreatedAsPersonalData() {
        // rastgele uretilmis 12 rakamlik sid kisisel veri (telefon) sayilip tum istegi dusurmemeli
        assertEquals(1, run(new EventIn("screen_view", "home", p("sid", "123456789012"), null)).size());
        // ama baska anahtarda ayni deger yine reddedilir
        assertThrows(ApiException.class, () -> run(new EventIn("e", null, p("tel", "123456789012"), null)));
    }

    @Test
    void screenExitNeedsScreenAndBoundedDwell() {
        assertEquals(1, run(new EventIn("screen_exit", "home", p("sid", "abcd1234", "dwellMs", 1500), null)).size());
        assertEquals(1, run(new EventIn("screen_exit", "home", p("dwellMs", 0), null)).size());
        assertEquals(1, run(new EventIn("screen_exit", "home", p("dwellMs", 86_400_000), null)).size());
        assertEquals(1, run(new EventIn("screen_exit", "home", p("dwellMs", 1500.0), null)).size()); // tam sayi degerli
        assertEquals(0, run(new EventIn("screen_exit", "home", p("dwellMs", 86_400_001), null)).size());
        assertEquals(0, run(new EventIn("screen_exit", "home", p("dwellMs", -1), null)).size());
        assertEquals(0, run(new EventIn("screen_exit", "home", p("dwellMs", 12.5), null)).size());
        assertEquals(0, run(new EventIn("screen_exit", "home", p("dwellMs", "1500"), null)).size());
        assertEquals(0, run(new EventIn("screen_exit", "home", p(), null)).size()); // sure yok
        assertEquals(0, run(new EventIn("screen_exit", null, p("dwellMs", 10), null)).size()); // ekran yok
    }

    @Test
    void dwellIsStoredAsPlainInteger() {
        ValidEvent v = run(new EventIn("screen_exit", "home", p("sid", "abcd1234", "dwellMs", 1500.0), null)).get(0);
        assertEquals("{\"sid\":\"abcd1234\",\"dwellMs\":1500}", v.propsJson());
    }

    @Test
    void sessionEndNeedsDurationAndValidOptionalFields() {
        assertEquals(1, run(new EventIn("session_end", null,
                p("sid", "abcd1234", "durationMs", 61_000, "screens", 4, "reason", "background"), null)).size());
        assertEquals(1, run(new EventIn("session_end", null, p("durationMs", 10, "reason", "timeout"), null)).size());
        assertEquals(1, run(new EventIn("session_end", null, p("durationMs", 10, "reason", "exit"), null)).size());
        assertEquals(0, run(new EventIn("session_end", null, p("sid", "abcd1234"), null)).size());
        assertEquals(0, run(new EventIn("session_end", null, p("durationMs", 86_400_001), null)).size());
        assertEquals(0, run(new EventIn("session_end", null, p("durationMs", 10, "reason", "crash"), null)).size());
        assertEquals(0, run(new EventIn("session_end", null, p("durationMs", 10, "screens", -1), null)).size());
    }

    @Test
    void actionKindWhitelist() {
        for (String k : EventContract.ACTION_KINDS) {
            assertEquals(1, run(new EventIn("action", "home", p("sid", "abcd1234", "kind", k), null)).size(), k);
        }
        assertEquals(22, EventContract.ACTION_KINDS.size());
        assertTrue(EventContract.ACTION_KINDS.contains("tab_switch"));
        assertEquals(0, run(new EventIn("action", "home", p("kind", "hack_it"), null)).size());
        assertEquals(0, run(new EventIn("action", "home", p("kind", "LIKE"), null)).size());
        assertEquals(0, run(new EventIn("action", "home", p(), null)).size());
        assertEquals(1, run(new EventIn("action", "home", p("kind", "like", "target", "post"), null)).size());
        assertEquals(0, run(new EventIn("action", "home", p("kind", "like", "target", "Bad Target"), null)).size());
    }

    @Test
    void invalidEventsAreDroppedIndividually() {
        List<ValidEvent> v = run(
                new EventIn("screen_view", "home", p("sid", "abcd1234"), null),
                new EventIn("action", "home", p("kind", "nope"), null), // elenir
                new EventIn("session_end", null, p("sid", "abcd1234", "durationMs", 5000), null));
        assertEquals(List.of("screen_view", "session_end"), v.stream().map(ValidEvent::name).toList());
    }

    @Test
    void legacyEventsAreUnaffected() {
        assertEquals(1, run(new EventIn("app_open", null, null, null)).size());
        assertEquals(1, run(new EventIn("search", "search", p("len", 5), null)).size());
        assertEquals(1, run(new EventIn("screen_view", "home", null, null)).size());
    }

    @Test
    void eightPropsAllowedNinthRejectedAndCamelCaseKeys() {
        Map<String, Object> eight = new LinkedHashMap<>();
        for (int i = 0; i < 8; i++) {
            eight.put("k" + i, i);
        }
        assertEquals(1, run(new EventIn("e", null, eight, null)).size());
        eight.put("k8", 8);
        assertThrows(ApiException.class, () -> run(new EventIn("e", null, eight, null)));
        assertThrows(ApiException.class, () -> run(new EventIn("e", null, p("Bad-Key", 1), null)));
        assertFalse(run(new EventIn("e", null, p("camelKey", 1), null)).isEmpty());
    }
}
