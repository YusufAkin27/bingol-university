package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.domain.PageRequest;

/**
 * FIX-P05 (A05#5): liste ve one cikan sorgulari baslangic alt siniri (60 gun) tasir; cok eski baslamis ama bitis tarihi
 * ileride kalmis (veri hatasi/eski uzun kayit) etkinlikler taranmaz, normal suren etkinlikler listelenir.
 */
@SpringBootTest
class EventUpcomingBoundedScanTest {

    @Autowired
    UserEventRepository repo;

    private UserEvent save(String title, Instant start, Duration len, int going) {
        UserEvent e = new UserEvent();
        e.setTitle(title);
        e.setStartsAt(start);
        e.setEndsAt(start.plus(len));
        e.setGoingCount(going);
        e.setCreatedBy(9002L);
        e.setStatus(UserEvent.Status.ACTIVE);
        return repo.saveAndFlush(e);
    }

    private List<UserEvent> upcoming(Instant from) {
        return repo.upcoming(UserEvent.Status.ACTIVE, from, from.plus(Duration.ofDays(400)), 0L, Instant.EPOCH, 0L,
                Community.Status.ACTIVE, Community.Visibility.PUBLIC, 1L, CommunityMember.Status.ACTIVE,
                PageRequest.of(0, 500));
    }

    @Test
    void upcomingSkipsEventsThatStartedMoreThanTheLookbackAgoButKeepsRunningOnes() {
        Instant now = Instant.now();
        UserEvent ancient = save("bounded-ancient", now.minus(Duration.ofDays(120)), Duration.ofDays(200), 0);
        UserEvent running = save("bounded-running", now.minus(Duration.ofDays(10)), Duration.ofDays(20), 0);
        UserEvent future = save("bounded-future", now.plus(Duration.ofDays(3)), Duration.ofHours(2), 0);

        List<Long> ids = upcoming(now).stream().map(UserEvent::getId).toList();

        assertFalse(ids.contains(ancient.getId()));
        assertTrue(ids.contains(running.getId()));
        assertTrue(ids.contains(future.getId()));
    }

    @Test
    void featuredAppliesTheSameLowerBound() {
        Instant now = Instant.now();
        // going=0: baska testlerin "en cok GOING" varsayimlarini bozmaz; sayfa buyuk tutulur
        UserEvent ancient = save("bounded-ancient-feat", now.minus(Duration.ofDays(120)), Duration.ofDays(200), 0);
        UserEvent real = save("bounded-real-feat", now.plus(Duration.ofDays(2)), Duration.ofHours(2), 0);

        List<Long> ids = repo.featured(UserEvent.Status.ACTIVE, now, Community.Status.ACTIVE,
                Community.Visibility.PUBLIC, 1L, CommunityMember.Status.ACTIVE, PageRequest.of(0, 5000))
                .stream().map(UserEvent::getId).toList();

        assertFalse(ids.contains(ancient.getId()));
        assertTrue(ids.contains(real.getId()));
    }
}
