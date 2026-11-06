package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;

import edu.bingol.backend.community.Actor;
import edu.bingol.backend.event.dto.EventDtos.ScanResult;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

/**
 * Cok okutuculu yoklama yarisi (gercek transaction'lar, H2): ayni katilimcinin QR'i iki okutucuda ayni anda okutulunca
 * tek kayit olusur; biri MARKED, digeri ALREADY alir, hata donmez. (PostgreSQL ile ayni davranis benzersiz kisitla saglanir.)
 */
@SpringBootTest
class AttendanceScanRaceTest {

    @Autowired UserEventRepository events;
    @Autowired EventRsvpRepository rsvps;
    @Autowired EventAttendanceRepository attendance;
    @Autowired UserRepository users;
    @Autowired AttendanceService svc;
    @Autowired CheckinCodeService codes;

    private User user(String tag) {
        User u = new User();
        u.setEmail(tag + "@race.test");
        u.setPasswordHash("x");
        u.setDisplayName("Race " + tag);
        return users.saveAndFlush(u);
    }

    @Test
    void twoScannersSamePersonOneRecord() throws Exception {
        User owner = user("owner");
        UserEvent e = new UserEvent();
        e.setTitle("Yaris");
        e.setStartsAt(Instant.now().minus(Duration.ofMinutes(10)));
        e.setEndsAt(Instant.now().plus(Duration.ofHours(1)));
        e.setCreatedBy(owner.getId());
        e.setStatus(UserEvent.Status.ACTIVE);
        e.setAttendanceOpen(true);
        e = events.saveAndFlush(e);
        Actor scanner = new Actor(owner.getId(), false);

        for (int round = 0; round < 8; round++) {
            User p = user("p" + round);
            rsvps.saveAndFlush(new EventRsvp(e.getId(), p.getId(), EventRsvp.Status.GOING));
            String payload = codes.generateTicket(e.getId(), p.getId(), Instant.now());
            ExecutorService pool = Executors.newFixedThreadPool(2);
            CountDownLatch go = new CountDownLatch(1);
            Long eid = e.getId();
            List<Future<ScanResult>> fs = new ArrayList<>();
            for (int i = 0; i < 2; i++) {
                fs.add(pool.submit(() -> {
                    go.await();
                    return svc.scan(scanner, eid, payload, Instant.now());
                }));
            }
            go.countDown();
            int marked = 0;
            int already = 0;
            for (Future<ScanResult> f : fs) {
                ScanResult r = f.get();
                if ("MARKED".equals(r.status())) {
                    marked++;
                } else if ("ALREADY".equals(r.status())) {
                    already++;
                }
            }
            pool.shutdown();
            assertEquals(1, marked, "round " + round);
            assertEquals(1, already, "round " + round);
            assertEquals(1, attendance.findByEventId(e.getId()).stream()
                    .filter(a -> a.getUserId().equals(p.getId())).count());
            assertEquals(owner.getId(), attendance.findByEventIdAndUserId(e.getId(), p.getId()).orElseThrow().getMarkedBy());
        }
    }
}
