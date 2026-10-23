package edu.bingol.backend.analytics;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import edu.bingol.backend.common.ApiException;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import org.junit.jupiter.api.Test;

/** Tarih araligi dogrulamasi ve Europe/Istanbul gun sinirlari (UTC+3, DST yok). */
class DateRangeTest {

    private static Clock at(String utcInstant) {
        return Clock.fixed(Instant.parse(utcInstant), ZoneOffset.UTC);
    }

    @Test
    void defaultsToLast30DaysEndingToday() {
        DateRange r = DateRange.parse(null, null, at("2026-10-23T12:00:00Z"));

        assertEquals(LocalDate.parse("2026-10-23"), r.to());
        assertEquals(LocalDate.parse("2026-09-24"), r.from());
        assertEquals(30, r.days());
    }

    @Test
    void todayFollowsIstanbulNotUtc() {
        // 21:30 UTC = ertesi gun 00:30 Istanbul
        assertEquals(LocalDate.parse("2026-10-24"), DateRange.today(at("2026-10-23T21:30:00Z")));
        // 20:59 UTC = hala ayni gun 23:59 Istanbul
        assertEquals(LocalDate.parse("2026-10-23"), DateRange.today(at("2026-10-23T20:59:59Z")));
    }

    @Test
    void dayBoundariesAreIstanbulMidnightInUtc() {
        DateRange r = DateRange.parse("2026-10-23", "2026-10-24", at("2026-10-25T00:00:00Z"));

        assertEquals("2026-10-22T21:00Z", r.startUtc().toString());
        // Haric uc: 25 Ekim 00:00 Istanbul = 24 Ekim 21:00 UTC
        assertEquals("2026-10-24T21:00Z", r.endUtc().toString());
        assertEquals(2, r.days());
    }

    @Test
    void midnightRecordFallsOnTheRightDay() {
        DateRange r = DateRange.parse("2026-10-24", "2026-10-24", at("2026-10-25T00:00:00Z"));
        Instant justBefore = Instant.parse("2026-10-23T20:59:59Z"); // 23 Ekim 23:59:59 Istanbul
        Instant atMidnight = Instant.parse("2026-10-23T21:00:00Z"); // 24 Ekim 00:00:00 Istanbul

        assertEquals(false, !justBefore.isBefore(r.startUtc().toInstant()));
        assertEquals(true, !atMidnight.isBefore(r.startUtc().toInstant()) && atMidnight.isBefore(r.endUtc().toInstant()));
    }

    @Test
    void singleDayRangeIsValid() {
        DateRange r = DateRange.parse("2026-02-28", "2026-02-28", at("2026-10-23T12:00:00Z"));
        assertEquals(1, r.days());
    }

    @Test
    void leapDayIsCounted() {
        // 2028 artik yil: 1 Sub - 1 Mar = 30 gun (29 Subat dahil)
        assertEquals(30, DateRange.parse("2028-02-01", "2028-03-01", at("2028-06-01T00:00:00Z")).days());
    }

    @Test
    void max366DaysAccepted() {
        DateRange r = DateRange.parse("2027-01-01", "2027-12-31", at("2028-01-01T00:00:00Z"));
        assertEquals(365, r.days());
        // 2028 artik yil: tam 366 gun
        assertEquals(366, DateRange.parse("2028-01-01", "2028-12-31", at("2029-01-01T00:00:00Z")).days());
    }

    @Test
    void moreThan366DaysRejected() {
        ApiException e = assertThrows(ApiException.class,
                () -> DateRange.parse("2027-01-01", "2028-01-02", at("2028-06-01T00:00:00Z")));
        assertEquals("INVALID_RANGE", e.code());
        assertEquals(400, e.status().value());
    }

    @Test
    void fromAfterToRejected() {
        assertThrows(ApiException.class, () -> DateRange.parse("2026-10-24", "2026-10-23", at("2026-10-25T00:00:00Z")));
    }

    @Test
    void malformedDatesRejected() {
        Clock c = at("2026-10-25T00:00:00Z");
        assertThrows(ApiException.class, () -> DateRange.parse("23.10.2026", "2026-10-24", c));
        assertThrows(ApiException.class, () -> DateRange.parse("2026-13-01", null, c));
        assertThrows(ApiException.class, () -> DateRange.parse("2026-02-30", null, c));
        assertThrows(ApiException.class, () -> DateRange.parse(null, "bugun", c));
    }

    @Test
    void onlyFromRunsUntilToday() {
        DateRange r = DateRange.parse("2026-10-20", null, at("2026-10-23T10:00:00Z"));
        assertEquals(LocalDate.parse("2026-10-23"), r.to());
        assertEquals(4, r.days());
    }

    @Test
    void onlyFromInTheFutureRejected() {
        assertThrows(ApiException.class, () -> DateRange.parse("2026-11-01", null, at("2026-10-23T10:00:00Z")));
    }
}
