package edu.bingol.backend.event.extras;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CoOrganizerRepository extends JpaRepository<CoOrganizer, Long> {

    boolean existsByEventIdAndUserId(Long eventId, Long userId);

    Optional<CoOrganizer> findByEventIdAndUserId(Long eventId, Long userId);

    List<CoOrganizer> findByEventIdOrderById(Long eventId);

    long countByEventId(Long eventId);

    List<CoOrganizer> findByUserId(Long userId);

    @Query("SELECT c.eventId FROM CoOrganizer c WHERE c.userId = :uid AND c.eventId IN :ids")
    List<Long> coOrganizedAmong(@Param("ids") Collection<Long> eventIds, @Param("uid") Long userId);

    /** T-041: kulupten dusen kisinin o kulubun etkinliklerindeki ortak organizator kayitlari. */
    @org.springframework.data.jpa.repository.Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("DELETE FROM CoOrganizer c WHERE c.userId = :uid AND c.eventId IN "
            + "(SELECT e.id FROM UserEvent e WHERE e.communityId = :cid)")
    int deleteMemberOfCommunityEvents(@Param("cid") Long communityId, @Param("uid") Long userId);
}
