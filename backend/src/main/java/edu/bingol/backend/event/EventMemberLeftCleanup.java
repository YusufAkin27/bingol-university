package edu.bingol.backend.event;

import edu.bingol.backend.community.ClubMemberLeftEvent;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.event.extras.CoOrganizerRepository;
import java.time.Instant;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * T-041: kulupten ayrilan/cikarilan/yasaklanan kisinin o kulubun etkinliklerindeki organizator izleri temizlenir.
 * (1) Ortak organizator kayitlari silinir (kulup disi kisi yetki tasimaz; erisimde de canli kontrol vardir).
 * (2) Ozel (PRIVATE) kulup etkinliklerindeki bitmemis RSVP'leri silinir ve GOING sayaci atomik azaltilir (uye olmayan
 * ozel kulup etkinligini goremez). Herkese acik kulupte RSVP korunur. Commit sonrasi, ayri islemde; hata uyelik
 * islemini etkilemez.
 */
@Component
public class EventMemberLeftCleanup {

    private static final Logger log = LoggerFactory.getLogger(EventMemberLeftCleanup.class);

    private final CoOrganizerRepository coOrganizers;
    private final CommunityRepository communities;
    private final UserEventRepository events;
    private final EventRsvpRepository rsvps;

    public EventMemberLeftCleanup(CoOrganizerRepository coOrganizers, CommunityRepository communities,
                                  UserEventRepository events, EventRsvpRepository rsvps) {
        this.coOrganizers = coOrganizers;
        this.communities = communities;
        this.events = events;
        this.rsvps = rsvps;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void onMemberLeft(ClubMemberLeftEvent e) {
        try {
            cleanup(e.communityId(), e.userId());
        } catch (RuntimeException ex) {
            log.warn("Kulup etkinlik izleri temizlenemedi (kulup {}, kullanici {}): {}", e.communityId(), e.userId(),
                    ex.toString());
        }
    }

    /** Test icin dogrudan cagrilabilir. Doner: silinen RSVP sayisi. */
    int cleanup(Long communityId, Long userId) {
        coOrganizers.deleteMemberOfCommunityEvents(communityId, userId);
        boolean priv = communities.findById(communityId).map(c -> c.getVisibility() == Community.Visibility.PRIVATE)
                .orElse(false);
        if (!priv) {
            return 0;
        }
        int n = 0;
        List<Long> ids = events.liveIdsByCommunity(communityId,
                List.of(UserEvent.Status.ACTIVE, UserEvent.Status.PENDING_REVIEW), Instant.now());
        for (Long eventId : ids) {
            var rsvp = rsvps.findByEventIdAndUserId(eventId, userId).orElse(null);
            if (rsvp == null) {
                continue;
            }
            if (rsvp.getStatus() == EventRsvp.Status.GOING) {
                events.decrementGoing(eventId);
            }
            rsvps.delete(rsvp);
            n++;
        }
        return n;
    }
}
