package edu.bingol.backend.common;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.SliceImpl;

class SlicePagingTest {

    @Test
    void limitIsClampedTo1To50() {
        assertEquals(50, SlicePaging.limit(null));
        assertEquals(50, SlicePaging.limit(500));
        assertEquals(1, SlicePaging.limit(-3));
        assertEquals(7, SlicePaging.limit(7));
    }

    @Test
    void cursorIsPageNumberAndNegativeBecomesZero() {
        assertEquals(0, SlicePaging.request(null, 10).getPageNumber());
        assertEquals(0, SlicePaging.request(-5L, 10).getPageNumber());
        assertEquals(3, SlicePaging.request(3L, 10).getPageNumber());
    }

    @Test
    void nextCursorHeaderOnlyWhenMoreRemains() {
        var more = new SliceImpl<>(List.of(1, 2), PageRequest.of(2, 2), true);
        assertEquals("3", SlicePaging.respond(more, List.of(1, 2)).getHeaders().getFirst("X-Next-Cursor"));
        var last = new SliceImpl<>(List.of(1), PageRequest.of(0, 2), false);
        assertNull(SlicePaging.respond(last, List.of(1)).getHeaders().getFirst("X-Next-Cursor"));
    }
}
