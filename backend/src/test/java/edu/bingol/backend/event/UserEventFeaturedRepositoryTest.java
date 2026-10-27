package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;

import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.domain.PageRequest;

/** featured sorgusu: en cok GOING, esitlikte yakin baslangic; bitmis/ACTIVE olmayanlar elenir. */
@SpringBootTest
class UserEventFeaturedRepositoryTest {

    @Autowired
    UserEventRepository repo;

    private UserEvent save(String title, int going, Instant start, Duration len, UserEvent.Status st) {
        UserEvent e = new UserEvent();
        e.setTitle(title);
        e.setStartsAt(start);
        e.setEndsAt(start.plus(len));
        e.setGoingCount(going);
        e.setCreatedBy(9001L);
        e.setStatus(st);
        return repo.saveAndFlush(e);
    }

    private List<UserEvent> top() {
        return repo.featured(UserEvent.Status.ACTIVE, Instant.now(), Community.Status.ACTIVE,
                Community.Visibility.PUBLIC, 1L, CommunityMember.Status.ACTIVE, PageRequest.of(0, 1));
    }

    @Test
    void picksHighestGoingThenEarliestAndSkipsEndedOrInactive() {
        Instant now = Instant.now();
        // Cok yuksek sayilar: diger testlerin verisi sonucu etkilemesin
        save("bitmis-cok", 2_000_000, now.minus(Duration.ofDays(3)), Duration.ofHours(2), UserEvent.Status.ACTIVE);
        save("iptal-cok", 2_000_000, now.plus(Duration.ofDays(3)), Duration.ofHours(2), UserEvent.Status.CANCELLED);
        save("bekleyen-cok", 2_000_000, now.plus(Duration.ofDays(3)), Duration.ofHours(2), UserEvent.Status.PENDING_REVIEW);
        save("az", 1_500_000, now.plus(Duration.ofDays(1)), Duration.ofHours(2), UserEvent.Status.ACTIVE);
        save("esit-gec", 1_900_000, now.plus(Duration.ofDays(9)), Duration.ofHours(2), UserEvent.Status.ACTIVE);
        save("esit-erken", 1_900_000, now.plus(Duration.ofDays(5)), Duration.ofHours(2), UserEvent.Status.ACTIVE);
        // Su an suren etkinlik de yaklasan sayilir
        save("suren", 1_800_000, now.minus(Duration.ofHours(1)), Duration.ofHours(3), UserEvent.Status.ACTIVE);

        assertEquals("esit-erken", top().get(0).getTitle());
    }
}
