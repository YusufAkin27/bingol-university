package edu.bingol.backend.support.ticket;

import java.time.Instant;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface TicketRepository extends JpaRepository<SupportTicket, Long>, JpaSpecificationExecutor<SupportTicket> {

    @Query("SELECT t FROM SupportTicket t WHERE t.userId = :uid AND (:cursor IS NULL OR t.id < :cursor) ORDER BY t.id DESC")
    List<SupportTicket> mine(@Param("uid") Long userId, @Param("cursor") Long cursor, Pageable pageable);

    List<SupportTicket> findByUserIdOrderByIdDesc(Long userId);

    long countByUserIdAndStatusNot(Long userId, SupportTicket.Status status);

    /**
     * Yonetici kuyrugu: en eski once. Dogrulanmamis herkese acik talepler hic gorunmez;
     * publicOnly=true yalnizca herkese acik talepleri getirir.
     */
    @Query("SELECT t FROM SupportTicket t WHERE t.emailVerified = true AND (:status IS NULL OR t.status = :status) "
            + "AND (:publicOnly = false OR t.publicTicket = true) AND (:cursor IS NULL OR t.id > :cursor) ORDER BY t.id ASC")
    List<SupportTicket> queue(@Param("status") SupportTicket.Status status, @Param("publicOnly") boolean publicOnly,
                              @Param("cursor") Long cursor, Pageable pageable);

    /** Bu e-posta icin en yeni dogrulanmamis herkese acik talep. */
    @Query("SELECT t FROM SupportTicket t WHERE t.publicTicket = true AND t.emailVerified = false "
            + "AND t.contactEmail = :email ORDER BY t.id DESC")
    List<SupportTicket> pendingByEmail(@Param("email") String email, Pageable pageable);

    // T-020: @Modifying silme islem ister; aynı sinif ici cagri (scheduledCleanup -> cleanup) proxy'yi dolandigindan
    // islemi depo yontemi kendisi acar (hangi yoldan cagrilirsa cagrilsin calisir)
    @Transactional
    @Modifying
    @Query("DELETE FROM SupportTicket t WHERE t.publicTicket = true AND t.emailVerified = false AND t.createdAt < :before")
    int deleteUnverifiedBefore(@Param("before") Instant before);

    @Transactional
    @Modifying
    @Query("DELETE FROM SupportTicket t WHERE t.publicTicket = true AND t.updatedAt < :before")
    int deletePublicUpdatedBefore(@Param("before") Instant before);
}
