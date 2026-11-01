package edu.bingol.backend.support.admin;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;

import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.support.feedback.FeedbackRepository;
import edu.bingol.backend.support.ticket.SupportTicket;
import edu.bingol.backend.support.ticket.TicketRepository;
import edu.bingol.backend.user.UserRepository;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.mock.web.MockHttpServletResponse;

/**
 * P07-B11: destek CSV dokumu id azalan 1000'luk sayfalarla akar (50 bin tam entity + findAllById yok): sayfa sinirinda
 * satir kaybi/tekrari olmaz, sira en yeni once, formul kacisi korunur.
 */
@SpringBootTest
class SupportExportStreamingTest {

    @Autowired TicketRepository tickets;
    @Autowired FeedbackRepository feedback;
    @Autowired UserRepository users;

    private SupportExportController controller;

    @BeforeEach
    void setUp() {
        controller = new SupportExportController(tickets, feedback, users, mock(RateLimiter.class));
        tickets.deleteAll();
        List<SupportTicket> rows = new ArrayList<>();
        for (int i = 0; i < 1250; i++) {
            SupportTicket t = new SupportTicket();
            t.setPublicTicket(true);
            t.setContactEmail("kisi" + i + "@example.com");
            t.setCategory(SupportTicket.Category.OTHER);
            t.setSubject(i == 0 ? "=HYPERLINK(\"x\")" : "Konu " + i);
            rows.add(t);
        }
        tickets.saveAll(rows);
    }

    @Test
    void streamsAllRowsAcrossPagesInDescendingIdOrderWithoutDuplicates() throws Exception {
        MockHttpServletResponse res = new MockHttpServletResponse();
        controller.ticketsCsv(null, null, null, null, false, null, null, res);

        String body = res.getContentAsString(java.nio.charset.StandardCharsets.UTF_8);
        String[] lines = body.replace("﻿", "").split("\r?\n");
        assertEquals(1251, lines.length, "baslik + 1250 satir");
        assertTrue(lines[0].startsWith("id,durum"), lines[0]);

        List<Long> ids = new ArrayList<>();
        for (int i = 1; i < lines.length; i++) {
            ids.add(Long.parseLong(lines[i].substring(0, lines[i].indexOf(','))));
        }
        assertEquals(1250, ids.stream().distinct().count(), "tekrar yok");
        for (int i = 1; i < ids.size(); i++) {
            assertTrue(ids.get(i - 1) > ids.get(i), "id azalan");
        }
        assertTrue(body.contains("'=HYPERLINK"), "CSV formul kacisi korunmali");
        assertEquals("text/csv;charset=UTF-8", res.getContentType().replace("; ", ";"));
    }
}
