package edu.bingol.backend.event.extras;

import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface EventFeedbackRepository extends JpaRepository<EventFeedback, Long> {

    Optional<EventFeedback> findByEventIdAndUserId(Long eventId, Long userId);

    List<EventFeedback> findByUserId(Long userId);

    @Query("SELECT f FROM EventFeedback f WHERE f.eventId = :eid AND f.id < :cursor ORDER BY f.id DESC")
    List<EventFeedback> page(@Param("eid") Long eventId, @Param("cursor") long cursor, Pageable page);

    /** [puan, adet] satirlari. */
    @Query("SELECT f.rating, COUNT(f) FROM EventFeedback f WHERE f.eventId = :eid GROUP BY f.rating")
    List<Object[]> distribution(@Param("eid") Long eventId);
}
