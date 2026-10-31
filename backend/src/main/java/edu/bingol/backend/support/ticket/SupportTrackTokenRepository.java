package edu.bingol.backend.support.ticket;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface SupportTrackTokenRepository extends JpaRepository<SupportTrackToken, Long> {

    Optional<SupportTrackToken> findByTokenHash(String tokenHash);

    /** Talep silinirken (P12) durum baglantilari gecersiz olur. */
    @Modifying
    @Query("DELETE FROM SupportTrackToken t WHERE t.ticketId = :ticketId")
    int deleteByTicketId(@Param("ticketId") Long ticketId);

    /** T-062: suresi dolan (olusturma `before`dan eski) durum baglantilari. */
    @Transactional
    @Modifying
    @Query("DELETE FROM SupportTrackToken t WHERE t.createdAt < :before")
    int deleteCreatedBefore(@Param("before") java.time.Instant before);

    /** T-062: kapanali `before`dan uzun sure olan taleplerin durum baglantilari. */
    @Transactional
    @Modifying
    @Query("DELETE FROM SupportTrackToken t WHERE t.ticketId IN (SELECT k.id FROM SupportTicket k "
            + "WHERE k.status = edu.bingol.backend.support.ticket.SupportTicket.Status.CLOSED AND k.closedAt < :before)")
    int deleteForTicketsClosedBefore(@Param("before") java.time.Instant before);
}
