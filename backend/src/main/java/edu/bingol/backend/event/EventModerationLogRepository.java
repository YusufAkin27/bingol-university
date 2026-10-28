package edu.bingol.backend.event;

import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface EventModerationLogRepository extends JpaRepository<EventModerationLog, Long> {

    /** Son kayitlar (yeniden eskiye). */
    @Query("SELECT l FROM EventModerationLog l WHERE l.eventId = :eid ORDER BY l.id DESC")
    List<EventModerationLog> recent(@Param("eid") Long eventId, Pageable page);
}
