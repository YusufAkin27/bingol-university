package edu.bingol.backend.event;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface EventModeratorRepository extends JpaRepository<EventModerator, Long> {

    Optional<EventModerator> findByEventIdAndUserId(Long eventId, Long userId);

    List<EventModerator> findByEventIdOrderByCreatedAtAsc(Long eventId);

    @Modifying
    @Transactional
    @Query("delete from EventModerator m where m.userId = :uid")
    int deleteByUser(@Param("uid") Long uid);
}
