package edu.bingol.backend.support.ticket;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface SupportTrackTokenRepository extends JpaRepository<SupportTrackToken, Long> {

    Optional<SupportTrackToken> findByTokenHash(String tokenHash);

    /** Talep silinirken (P12) durum baglantilari gecersiz olur. */
    @Modifying
    @Query("DELETE FROM SupportTrackToken t WHERE t.ticketId = :ticketId")
    int deleteByTicketId(@Param("ticketId") Long ticketId);
}
