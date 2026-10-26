package edu.bingol.backend.event.admission;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface EventApplicationRepository extends JpaRepository<EventApplication, Long> {

    Optional<EventApplication> findByEventIdAndUserId(Long eventId, Long userId);

    Optional<EventApplication> findByIdAndEventId(Long id, Long eventId);

    List<EventApplication> findByUserIdOrderByIdDesc(Long userId);

    long countByEventIdAndStatus(Long eventId, EventApplication.Status status);

    /** Organizator listesi (tum durumlar), artan id imeci. */
    @Query("SELECT a FROM EventApplication a WHERE a.eventId = :eid AND a.id > :cursor ORDER BY a.id")
    List<EventApplication> page(@Param("eid") Long eventId, @Param("cursor") long cursor, Pageable page);

    @Query("SELECT a FROM EventApplication a WHERE a.eventId = :eid AND a.status = :status AND a.id > :cursor ORDER BY a.id")
    List<EventApplication> pageByStatus(@Param("eid") Long eventId, @Param("status") EventApplication.Status status,
                                        @Param("cursor") long cursor, Pageable page);

    /** Kullanicinin kendi listesi: yeniden eskiye imec. */
    @Query("SELECT a FROM EventApplication a WHERE a.userId = :uid AND a.id < :cursor ORDER BY a.id DESC")
    List<EventApplication> mine(@Param("uid") Long userId, @Param("cursor") long cursor, Pageable page);

    /** Bekleme listesi, terfi sirasiyla: once giris ani, esitlikte id. */
    @Query("SELECT a FROM EventApplication a WHERE a.eventId = :eid AND a.status = :waitlisted ORDER BY a.queuedAt, a.id")
    List<EventApplication> waitlist(@Param("eid") Long eventId, @Param("waitlisted") EventApplication.Status waitlisted,
                                    Pageable page);

    /** Bekleme listesinde benden once gelen sayisi (sira = bu + 1). */
    @Query("""
            SELECT COUNT(a) FROM EventApplication a
            WHERE a.eventId = :eid AND a.status = :waitlisted
              AND (a.queuedAt < :q OR (a.queuedAt = :q AND a.id < :id))
            """)
    long waitlistAhead(@Param("eid") Long eventId, @Param("waitlisted") EventApplication.Status waitlisted,
                       @Param("q") Instant queuedAt, @Param("id") Long id);

    /** Etkinlik iptal/mod degisimi: bekleyen (PENDING/WAITLISTED) basvurulari kapatir; etkilenen kullanicilari once okuyun. */
    @Query("SELECT a.userId FROM EventApplication a WHERE a.eventId = :eid AND a.status IN :statuses")
    List<Long> userIdsByStatus(@Param("eid") Long eventId, @Param("statuses") Collection<EventApplication.Status> statuses);

    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE EventApplication a SET a.status = :to, a.updatedAt = :now WHERE a.eventId = :eid AND a.status IN :from")
    int closeAll(@Param("eid") Long eventId, @Param("from") Collection<EventApplication.Status> from,
                 @Param("to") EventApplication.Status to, @Param("now") Instant now);
}
