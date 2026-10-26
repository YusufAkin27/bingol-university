package edu.bingol.backend.event.extras;

import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.event.EventRsvp;
import edu.bingol.backend.event.UserEvent;
import java.time.Instant;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/** Kullanicinin GOING dedigi (gorunurluk kurallariyla) etkinlikler; ICS takvimi icin. */
public interface EventIcsRepository extends JpaRepository<UserEvent, Long> {

    @Query("""
            SELECT e FROM UserEvent e
            WHERE e.status = :active AND e.endsAt >= :since
              AND e.id IN (SELECT r.eventId FROM EventRsvp r WHERE r.userId = :uid AND r.status = :going)
              AND (e.communityId IS NULL OR e.communityId IN (
                    SELECT c.id FROM Community c WHERE c.status = :cActive AND (c.visibility = :pub
                      OR c.id IN (SELECT m.communityId FROM CommunityMember m WHERE m.userId = :uid AND m.status = :mActive))))
            ORDER BY e.startsAt, e.id
            """)
    List<UserEvent> going(@Param("uid") Long userId, @Param("since") Instant since,
                          @Param("active") UserEvent.Status active, @Param("going") EventRsvp.Status going,
                          @Param("cActive") Community.Status cActive, @Param("pub") Community.Visibility pub,
                          @Param("mActive") CommunityMember.Status mActive, Pageable page);
}
