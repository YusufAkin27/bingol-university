package edu.bingol.backend.event.admin;

import edu.bingol.backend.event.extras.EventAnnouncement;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/** Yonetici duyuru kaydi sorgulari (bean: adminAnnouncementRepository). */
public interface AdminAnnouncementRepository extends JpaRepository<EventAnnouncement, Long> {

    Optional<EventAnnouncement> findByIdAndEventId(Long id, Long eventId);

    /** Azalan id imeci. */
    @Query("SELECT a FROM EventAnnouncement a WHERE a.eventId = :eid AND a.id < :cursor ORDER BY a.id DESC")
    List<EventAnnouncement> page(@Param("eid") Long eventId, @Param("cursor") long cursor, Pageable page);
}
