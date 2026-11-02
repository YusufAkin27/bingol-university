package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.time.Instant;
import org.junit.jupiter.api.Test;

/** Etkinlik degisikligi bildirimi: neyin degistigi (eski -> yeni). */
class EventChangeLineTest {

    @Test
    void showsOldAndNewTimeAndPlace() {
        assertEquals("02.11 13:00 → 02.11 14:30 | Salon A → Salon B", EventService.changeLine(
                Instant.parse("2026-11-02T10:00:00Z"), Instant.parse("2026-11-02T11:30:00Z"), "Salon A", "Salon B"));
    }

    @Test
    void unchangedMeansEmptyAndNewPlaceWithoutOldShowsOnlyNew() {
        assertEquals("", EventService.changeLine(Instant.EPOCH, Instant.EPOCH, "A", "A"));
        assertEquals("Salon B", EventService.changeLine(Instant.EPOCH, Instant.EPOCH, null, "Salon B"));
        assertEquals("", EventService.changeLine(Instant.EPOCH, Instant.EPOCH, "Salon A", null));
    }
}
