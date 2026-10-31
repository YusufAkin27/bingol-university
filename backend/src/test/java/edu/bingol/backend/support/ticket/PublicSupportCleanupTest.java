package edu.bingol.backend.support.ticket;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.common.RateLimiter;
import java.time.Duration;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

/**
 * T-020: zamanlayici girisi `scheduledCleanup()` DOGRUDAN cagrilir (cleanup'a proxy uzerinden degil, sinif ici
 * cagri yoluyla ulasir). Eskiden `@Transactional` dolanip silme sorgulari "No active transaction" ile basarisiz
 * oluyordu: dogrulanmamis (24 sa) ve saklama suresi (365 gun) dolan herkese acik talepler hic silinmiyordu.
 * Entity'ler @PrePersist'siz oldugundan tarihler dogrudan ayarlanir; tum islemler islemsiz (test yontemi islemsiz).
 */
@SpringBootTest
class PublicSupportCleanupTest {

    @Autowired PublicSupportService svc;
    @Autowired TicketRepository tickets;
    @MockitoBean RateLimiter limiter;

    private SupportTicket save(boolean verified, Instant created, Instant updated) {
        SupportTicket t = new SupportTicket();
        t.setPublicTicket(true);
        t.setEmailVerified(verified);
        t.setContactEmail("temizlik." + UUID.randomUUID().toString().substring(0, 8) + "@example.com");
        t.setContactName("T");
        t.setCategory(SupportTicket.Category.OTHER);
        t.setSubject("temizlik");
        t.setCreatedAt(created);
        t.setUpdatedAt(updated);
        return tickets.save(t);
    }

    @Test
    void scheduledCleanupDeletesUnverifiedAfter24hAndPublicAfterRetentionButKeepsFreshOnes() {
        Instant now = Instant.now();
        SupportTicket oldUnverified = save(false, now.minus(Duration.ofHours(25)), now.minus(Duration.ofHours(25)));
        SupportTicket freshUnverified = save(false, now.minus(Duration.ofHours(2)), now.minus(Duration.ofHours(2)));
        SupportTicket expiredVerified = save(true, now.minus(Duration.ofDays(400)), now.minus(Duration.ofDays(366)));
        SupportTicket freshVerified = save(true, now.minus(Duration.ofDays(400)), now.minus(Duration.ofDays(10)));

        svc.scheduledCleanup();

        assertFalse(tickets.existsById(oldUnverified.getId()), "24 saati gecen dogrulanmamis talep silinmeli");
        assertTrue(tickets.existsById(freshUnverified.getId()), "taze dogrulanmamis talep kalmali");
        assertFalse(tickets.existsById(expiredVerified.getId()), "365 gunu gecen herkese acik talep silinmeli");
        assertTrue(tickets.existsById(freshVerified.getId()), "yakin zamanda guncellenen talep kalmali");
    }
}
