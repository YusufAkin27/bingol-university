package edu.bingol.backend.support.ticket;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

/** Destek yaniti bildirim govdesi: "#id + ozet" tek satir ve kirpilmis. */
class TicketSnippetTest {

    @Test
    void oneLineAndCapped() {
        assertEquals("a b c", TicketService.snippet("a\n  b\tc", 50));
        String s = TicketService.snippet("x".repeat(300), 120);
        assertEquals(120, s.length());
        assertTrue(s.endsWith("…"));
        assertEquals("", TicketService.snippet(null, 10));
    }
}
