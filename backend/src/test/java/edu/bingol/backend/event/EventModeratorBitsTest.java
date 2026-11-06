package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import edu.bingol.backend.common.ApiException;
import java.util.List;
import org.junit.jupiter.api.Test;

class EventModeratorBitsTest {

    @Test
    void permissionsRoundTrip() {
        int b = EventModeratorService.bits(List.of("TAKE_ATTENDANCE", "EDIT_SCHEDULE"));
        assertEquals(List.of("TAKE_ATTENDANCE", "EDIT_SCHEDULE"), EventModeratorService.names(b));
        assertEquals(0, EventModeratorService.bits(List.of()));
    }

    @Test
    void ownerOnlyPermissionsCanNeverBeGranted() {
        for (String n : List.of("CLOSE_EVENT", "CANCEL_EVENT", "DELETE_EVENT", "TOGGLE_ATTENDANCE", "MANAGE_MODERATORS", "x")) {
            assertEquals("VALIDATION_ERROR", assertThrows(ApiException.class, () -> EventModeratorService.bits(List.of(n))).code());
        }
    }
}
