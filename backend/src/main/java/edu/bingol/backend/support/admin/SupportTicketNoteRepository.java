package edu.bingol.backend.support.admin;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface SupportTicketNoteRepository extends JpaRepository<SupportTicketNote, Long> {

    List<SupportTicketNote> findByTicketIdOrderByIdAsc(Long ticketId);

    @Modifying
    @Query("DELETE FROM SupportTicketNote n WHERE n.ticketId = :ticketId")
    int deleteByTicketId(@Param("ticketId") Long ticketId);
}
