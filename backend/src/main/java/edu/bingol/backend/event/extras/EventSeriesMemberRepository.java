package edu.bingol.backend.event.extras;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface EventSeriesMemberRepository extends JpaRepository<EventSeriesMember, Long> {

    Optional<EventSeriesMember> findByEventId(Long eventId);

    List<EventSeriesMember> findBySeriesIdOrderBySeq(Long seriesId);
}
