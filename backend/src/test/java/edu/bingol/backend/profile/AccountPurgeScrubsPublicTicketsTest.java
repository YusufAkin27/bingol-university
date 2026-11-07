package edu.bingol.backend.profile;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.support.ticket.SupportMessage;
import edu.bingol.backend.support.ticket.SupportMessageRepository;
import edu.bingol.backend.support.ticket.SupportTicket;
import edu.bingol.backend.support.ticket.SupportTrackToken;
import edu.bingol.backend.support.ticket.SupportTrackTokenRepository;
import edu.bingol.backend.support.ticket.TicketRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * FIX-P08 / A07#6 (K5c): hesap silinince, kimligi YALNIZ e-posta ile tutan herkese acik destek talepleri
 * (support_ticket.contact_email, kullanici mesajlari, takip jetonlari) temizlenir. Baska adresin talebine dokunulmaz.
 */
@SpringBootTest
class AccountPurgeScrubsPublicTicketsTest {

    @Autowired TicketRepository tickets;
    @Autowired SupportMessageRepository messages;
    @Autowired SupportTrackTokenRepository tokens;
    @Autowired JdbcTemplate jdbc;

    @org.junit.jupiter.api.AfterEach
    void after() {
        clean();
    }

    @BeforeEach
    void clean() {
        jdbc.update("DELETE FROM support_track_token");
        jdbc.update("DELETE FROM support_message");
        jdbc.update("DELETE FROM support_ticket");
    }

    SupportTicket ticket(String email) {
        SupportTicket t = new SupportTicket();
        t.setCategory(SupportTicket.Category.OTHER);
        t.setSubject("Giris sorunu");
        t.setPublicTicket(true);
        t.setContactEmail(email);
        t.setContactName("Ali Veli");
        t.setCodeHash("abc");
        return tickets.save(t);
    }

    void message(SupportTicket t, boolean staff, String text) {
        SupportMessage m = new SupportMessage();
        m.setTicketId(t.getId());
        m.setFromStaff(staff);
        m.setText(text);
        messages.save(m);
    }

    void token(SupportTicket t, String hash) {
        SupportTrackToken k = new SupportTrackToken();
        k.setTicketId(t.getId());
        k.setTokenHash(hash);
        tokens.save(k);
    }

    @Test
    void purgeScrubsPublicTicketsMatchedByOldEmail() {
        SupportTicket mine = ticket("ali.veli@bingol.edu.tr");
        message(mine, false, "Sifremi unuttum, numaram 12345");
        message(mine, true, "Merhaba, yardimci olalim");
        token(mine, "h1");
        SupportTicket other = ticket("baska@bingol.edu.tr");
        message(other, false, "Baskasinin mesaji");
        token(other, "h2");

        // purge(userId, oldEmail) bu SQL'leri kucuk harfli adresle SIRAYLA calistirir (mock testi: AccountDataPurgerTest);
        // burada ayni SQL'ler gercek (H2) semada denenir.
        for (String sql : AccountDataPurger.EMAIL_SCRUBS) {
            jdbc.update(sql, "ali.veli@bingol.edu.tr");
        }

        SupportTicket after = tickets.findById(mine.getId()).orElseThrow();
        assertEquals("[silindi]", after.getSubject());
        assertNull(after.getContactEmail());
        assertNull(after.getContactName());
        assertNull(after.getCodeHash());
        assertTrue(messages.findAll().stream().filter(m -> m.getTicketId().equals(mine.getId()) && !m.isFromStaff())
                .allMatch(m -> "[silindi]".equals(m.getText())));
        assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM support_track_token WHERE ticket_id = ?", Integer.class, mine.getId()));

        SupportTicket untouched = tickets.findById(other.getId()).orElseThrow();
        assertEquals("Giris sorunu", untouched.getSubject());
        assertEquals("baska@bingol.edu.tr", untouched.getContactEmail());
        assertEquals(1, jdbc.queryForObject("SELECT COUNT(*) FROM support_track_token WHERE ticket_id = ?", Integer.class, other.getId()));
        assertTrue(messages.findAll().stream().anyMatch(m -> "Baskasinin mesaji".equals(m.getText())));
    }

    @Test
    void ticketRowIsScrubbedLastSoSubRecordsAreStillFindableByAddress() {
        int ticketIdx = -1;
        for (int i = 0; i < AccountDataPurger.EMAIL_SCRUBS.size(); i++) {
            if (AccountDataPurger.EMAIL_SCRUBS.get(i).startsWith("UPDATE support_ticket ")) {
                ticketIdx = i;
            }
        }
        assertEquals(AccountDataPurger.EMAIL_SCRUBS.size() - 1, ticketIdx);
    }
}
