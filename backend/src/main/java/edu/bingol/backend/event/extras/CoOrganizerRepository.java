package edu.bingol.backend.event.extras;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CoOrganizerRepository extends JpaRepository<CoOrganizer, Long> {

    boolean existsByEventIdAndUserId(Long eventId, Long userId);

    Optional<CoOrganizer> findByEventIdAndUserId(Long eventId, Long userId);

    List<CoOrganizer> findByEventIdOrderById(Long eventId);

    long countByEventId(Long eventId);

    List<CoOrganizer> findByUserId(Long userId);
}
