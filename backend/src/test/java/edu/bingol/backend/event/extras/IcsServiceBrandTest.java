package edu.bingol.backend.event.extras;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;

import edu.bingol.backend.community.Actor;
import edu.bingol.backend.event.EventService;
import java.time.Instant;
import org.junit.jupiter.api.Test;

/** A9-03 / T-124: takvim adi kullaniciya gorunur; dogru yazim "BÜ Kampüs". */
class IcsServiceBrandTest {

    @Test
    void myCalendarNameUsesCorrectBrandSpelling() {
        // Mockito varsayilani: going(...) bos liste doner
        IcsService svc = new IcsService(mock(EventService.class), mock(EventIcsRepository.class));
        String ics = svc.mine(new Actor(1L, false), Instant.parse("2026-10-26T12:00:00Z"));
        assertTrue(ics.contains("X-WR-CALNAME:B\u00dc Kamp\u00fcs\r\n"), ics);
        assertFalse(ics.contains("X-WR-CALNAME:BU Kampus"));
    }
}
