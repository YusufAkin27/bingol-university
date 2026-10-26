package edu.bingol.backend.event.extras;

import java.time.Instant;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface EventAnnouncementRepository extends JpaRepository<EventAnnouncement, Long> {

    long countByEventIdAndCreatedAtGreaterThanEqual(Long eventId, Instant since);

    List<EventAnnouncement> findBySenderId(Long senderId);
}
