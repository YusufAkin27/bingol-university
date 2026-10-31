package edu.bingol.backend.admin.pii;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertSame;

import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

/** T-018: ikinci savunma hatti - serbest metindeki e-posta ve IP/cihaz alanlari (saf fonksiyon). */
class PiiScrubberTest {

    @Test
    void masksEmailsInsideFreeText() {
        assertEquals("Ulasin: a***@bingol.edu.tr veya b***@example.com tesekkurler",
                PiiScrubber.maskEmails("Ulasin: ayse.yilmaz@bingol.edu.tr veya bora+x@example.com tesekkurler"));
    }

    @Test
    void maskingIsIdempotentAndLeavesPlainTextAlone() {
        String once = PiiScrubber.maskEmails("ayse@bingol.edu.tr");
        assertEquals("a***@bingol.edu.tr", once);
        assertEquals(once, PiiScrubber.maskEmails(once));
        assertEquals("selam @herkes", PiiScrubber.maskEmails("selam @herkes"));
        assertEquals("a@b", PiiScrubber.maskEmails("a@b")); // alan adi noktasiz: e-posta degil
    }

    @Test
    void scrubsNestedStructuresAndOpaqueKeys() {
        Object in = Map.of(
                "email", "ayse@bingol.edu.tr",
                "ip", "10.1.2.3",
                "lastIp", "10.1.2.4",
                "items", List.of(Map.of("deviceHash", "abc123", "note", "yazdi: x@y.com", "n", 5)),
                "empty", "");
        @SuppressWarnings("unchecked")
        Map<String, Object> out = (Map<String, Object>) PiiScrubber.scrub(in);
        assertEquals("a***@bingol.edu.tr", out.get("email"));
        assertEquals("***", out.get("ip"));
        assertEquals("***", out.get("lastIp"));
        assertEquals("", out.get("empty"));
        @SuppressWarnings("unchecked")
        Map<String, Object> item = (Map<String, Object>) ((List<?>) out.get("items")).get(0);
        assertEquals("***", item.get("deviceHash"));
        assertEquals("yazdi: x***@y.com", item.get("note"));
        assertEquals(5, item.get("n"));
    }

    @Test
    void nonStringLeavesAreReturnedAsIs() {
        Integer n = 7;
        assertSame(n, PiiScrubber.scrub(n));
    }
}
