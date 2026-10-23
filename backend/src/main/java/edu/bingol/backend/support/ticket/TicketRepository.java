package edu.bingol.backend.support.ticket;

import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface TicketRepository extends JpaRepository<SupportTicket, Long> {

    @Query("SELECT t FROM SupportTicket t WHERE t.userId = :uid AND (:cursor IS NULL OR t.id < :cursor) ORDER BY t.id DESC")
    List<SupportTicket> mine(@Param("uid") Long userId, @Param("cursor") Long cursor, Pageable pageable);

    List<SupportTicket> findByUserIdOrderByIdDesc(Long userId);

    long countByUserIdAndStatusNot(Long userId, SupportTicket.Status status);

    /** Yonetici kuyrugu: en eski once (bekleyen talepler once cevaplanir). */
    @Query("SELECT t FROM SupportTicket t WHERE (:status IS NULL OR t.status = :status) AND (:cursor IS NULL OR t.id > :cursor) ORDER BY t.id ASC")
    List<SupportTicket> queue(@Param("status") SupportTicket.Status status, @Param("cursor") Long cursor,
                              Pageable pageable);
}
