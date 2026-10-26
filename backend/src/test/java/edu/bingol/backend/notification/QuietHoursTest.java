package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Instant;
import org.junit.jupiter.api.Test;

class QuietHoursTest {

    // 22:00-07:00 Istanbul (UTC+3)
    private static final int START = 22 * 60;
    private static final int END = 7 * 60;

    @Test
    void wrapsAroundMidnight() {
        // 20:30 UTC = 23:30 Istanbul -> sessiz
        assertTrue(QuietHours.isQuiet(true, START, END, "Europe/Istanbul", Instant.parse("2026-01-10T20:30:00Z")));
        // 02:00 UTC = 05:00 Istanbul -> sessiz
        assertTrue(QuietHours.isQuiet(true, START, END, "Europe/Istanbul", Instant.parse("2026-01-10T02:00:00Z")));
        // 09:00 UTC = 12:00 Istanbul -> sessiz degil
        assertFalse(QuietHours.isQuiet(true, START, END, "Europe/Istanbul", Instant.parse("2026-01-10T09:00:00Z")));
    }

    @Test
    void boundariesStartInclusiveEndExclusive() {
        assertTrue(QuietHours.isQuiet(true, START, END, "Europe/Istanbul", Instant.parse("2026-01-10T19:00:00Z"))); // 22:00
        assertFalse(QuietHours.isQuiet(true, START, END, "Europe/Istanbul", Instant.parse("2026-01-10T04:00:00Z"))); // 07:00
    }

    @Test
    void sameDayRangeAndTimezoneMatter() {
        // 13:00-15:00 UTC
        assertTrue(QuietHours.isQuiet(true, 13 * 60, 15 * 60, "UTC", Instant.parse("2026-01-10T14:00:00Z")));
        assertFalse(QuietHours.isQuiet(true, 13 * 60, 15 * 60, "UTC", Instant.parse("2026-01-10T15:00:00Z")));
        // ayni an Tokyo'da 23:00 -> aralik disinda
        assertFalse(QuietHours.isQuiet(true, 13 * 60, 15 * 60, "Asia/Tokyo", Instant.parse("2026-01-10T14:00:00Z")));
    }

    @Test
    void disabledOrDegenerateIsNeverQuiet() {
        Instant t = Instant.parse("2026-01-10T20:30:00Z");
        assertFalse(QuietHours.isQuiet(false, START, END, "Europe/Istanbul", t));
        assertFalse(QuietHours.isQuiet(true, 600, 600, "Europe/Istanbul", t));
        assertFalse(QuietHours.isQuiet(true, START, END, "Not/AZone", t));
        assertFalse(QuietHours.isQuiet(null, t));
    }

    @Test
    void zoneValidation() {
        assertTrue(QuietHours.validZone("Europe/Istanbul"));
        assertTrue(QuietHours.validZone("America/Argentina/Buenos_Aires"));
        assertTrue(QuietHours.validZone("UTC"));
        assertFalse(QuietHours.validZone("'; DROP TABLE x;--"));
        assertFalse(QuietHours.validZone("Foo/Bar"));
        assertFalse(QuietHours.validZone(null));
    }
}
