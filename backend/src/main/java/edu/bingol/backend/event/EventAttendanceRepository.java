package edu.bingol.backend.event;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface EventAttendanceRepository extends JpaRepository<EventAttendance, Long> {

    Optional<EventAttendance> findByEventIdAndUserId(Long eventId, Long userId);

    List<EventAttendance> findByEventId(Long eventId);
}
