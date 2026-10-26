package edu.bingol.backend.event.extras;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.event.UserEvent;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.Test;

class IcsWriterTest {

    private static UserEvent event(String title, String desc) {
        UserEvent e = new UserEvent();
        e.setId(42L);
        e.setTitle(title);
        e.setDescription(desc);
        e.setLocation("Salon A, Kat 2");
        // 2026-11-01 10:00 Istanbul = 07:00Z
        e.setStartsAt(Instant.parse("2026-11-01T07:00:00Z"));
        e.setEndsAt(Instant.parse("2026-11-01T09:30:00Z"));
        e.setStatus(UserEvent.Status.ACTIVE);
        e.setUpdatedAt(Instant.parse("2026-10-01T00:00:00Z"));
        return e;
    }

    @Test
    void structureUidTimezoneAndCrlf() {
        String s = IcsWriter.calendar("Takvim", List.of(event("Konferans", "Aciklama")), Instant.parse("2026-10-26T12:00:00Z"));
        assertTrue(s.startsWith("BEGIN:VCALENDAR\r\n"));
        assertTrue(s.endsWith("END:VCALENDAR\r\n"));
        assertTrue(s.contains("UID:event-42@bingol.edu.tr\r\n"));
        assertTrue(s.contains("DTSTART;TZID=Europe/Istanbul:20261101T100000\r\n"));
        assertTrue(s.contains("DTEND;TZID=Europe/Istanbul:20261101T123000\r\n"));
        assertTrue(s.contains("DTSTAMP:20261026T120000Z\r\n"));
        assertTrue(s.contains("TZID:Europe/Istanbul"));
        assertTrue(s.contains("LOCATION:Salon A\\, Kat 2\r\n"));
        assertTrue(s.contains("STATUS:CONFIRMED\r\n"));
        // Her satir CRLF ile biter: yalniz LF yok
        assertFalse(s.replace("\r\n", "").contains("\n"));
    }

    @Test
    void escapesSpecialCharsAndBlocksLineInjection() {
        String s = IcsWriter.calendar("t", List.of(event("A;B,C\\D", "x\r\nATTENDEE:mailto:evil@x.com\nEND:VEVENT")),
                Instant.now());
        assertTrue(s.contains("SUMMARY:A\\;B\\,C\\\\D\r\n"));
        assertTrue(s.contains("DESCRIPTION:x\\nATTENDEE:mailto:evil@x.com\\nEND:VEVENT\r\n"));
        assertFalse(s.contains("\r\nATTENDEE:"));
    }

    @Test
    void foldsLongLinesAt75OctetsWithoutBreakingUtf8() {
        String longText = "ü".repeat(100); // 2 oktet/karakter
        StringBuilder sb = new StringBuilder();
        IcsWriter.line(sb, "SUMMARY:" + longText);
        String[] lines = sb.toString().split("\r\n");
        assertTrue(lines.length > 1);
        for (int i = 0; i < lines.length; i++) {
            assertTrue(lines[i].getBytes(StandardCharsets.UTF_8).length <= 75, "satir " + i);
            if (i > 0) {
                assertTrue(lines[i].startsWith(" "));
            }
        }
        // Katlama geri alininca metin ayni
        String unfolded = sb.toString().replace("\r\n ", "").replace("\r\n", "");
        assertEquals("SUMMARY:" + longText, unfolded);
    }

    @Test
    void cancelledEventIsMarkedCancelled() {
        UserEvent e = event("x", null);
        e.setStatus(UserEvent.Status.CANCELLED);
        String s = IcsWriter.calendar("t", List.of(e), Instant.now());
        assertTrue(s.contains("STATUS:CANCELLED\r\n"));
        assertFalse(s.contains("DESCRIPTION"));
    }
}
