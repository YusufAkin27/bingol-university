package edu.bingol.backend.event.extras;

import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.event.EventRsvp;
import edu.bingol.backend.event.EventService;
import edu.bingol.backend.event.UserEvent;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** ICS disa aktarma. Gorunurluk EventService.loadVisible ile ayni (gorunmeyen etkinlik 404). */
@Service
public class IcsService {

    static final int MAX_EVENTS = 500;

    private final EventService events;
    private final EventIcsRepository repo;

    public IcsService(EventService events, EventIcsRepository repo) {
        this.events = events;
        this.repo = repo;
    }

    @Transactional(readOnly = true)
    public String single(Actor a, Long eventId, Instant now) {
        UserEvent e = events.loadVisible(a, eventId);
        return IcsWriter.calendar(e.getTitle(), List.of(e), now);
    }

    /** Kullanicinin GOING dedigi etkinlikler (son 30 gunden itibaren), ACTIVE ve gorunur olanlar. */
    @Transactional(readOnly = true)
    public String mine(Actor a, Instant now) {
        List<UserEvent> rows = repo.going(a.id(), now.minus(Duration.ofDays(30)), UserEvent.Status.ACTIVE,
                EventRsvp.Status.GOING, Community.Status.ACTIVE, Community.Visibility.PUBLIC,
                CommunityMember.Status.ACTIVE, PageRequest.of(0, MAX_EVENTS));
        return IcsWriter.calendar("BU Kampus", rows, now);
    }
}
