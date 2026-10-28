package edu.bingol.backend.support.ticket;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface SupportMessageRepository extends JpaRepository<SupportMessage, Long> {

    List<SupportMessage> findByTicketIdOrderByIdAsc(Long ticketId);

    /** Talep silinirken (P12) mesajlari temizler. */
    @Modifying
    @Query("DELETE FROM SupportMessage m WHERE m.ticketId = :ticketId")
    int deleteByTicketId(@Param("ticketId") Long ticketId);
}
