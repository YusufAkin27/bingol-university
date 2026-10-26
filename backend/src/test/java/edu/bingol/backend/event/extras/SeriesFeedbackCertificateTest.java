package edu.bingol.backend.event.extras;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.event.EventAttendance;
import edu.bingol.backend.event.EventAttendanceRepository;
import edu.bingol.backend.event.EventService;
import edu.bingol.backend.event.UserEvent;
import edu.bingol.backend.event.UserEventRepository;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserStatus;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicLong;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

class SeriesFeedbackCertificateTest {

    private static final Actor ORG = new Actor(1L, false);
    private static final Actor USER = new Actor(7L, false);
    private static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");

    private final EventService events = mock(EventService.class);
    private final UserEventRepository eventRepo = mock(UserEventRepository.class);
    private final EventSeriesMemberRepository members = mock(EventSeriesMemberRepository.class);
    private final EventAttendanceRepository attendance = mock(EventAttendanceRepository.class);
    private final EventFeedbackRepository feedbackRepo = mock(EventFeedbackRepository.class);
    private final EventCertificateRepository certRepo = mock(EventCertificateRepository.class);
    private final CommunityService communities = mock(CommunityService.class);

    private UserEvent event(Instant start, Instant end) {
        UserEvent e = new UserEvent();
        e.setId(10L);
        e.setTitle("Etkinlik");
        e.setCapacity(30);
        e.setCreatedBy(1L);
        e.setStatus(UserEvent.Status.ACTIVE);
        e.setStartsAt(start);
        e.setEndsAt(end);
        return e;
    }

    private void expect(Runnable r, HttpStatus s, String code) {
        ApiException ex = assertThrows(ApiException.class, r::run);
        assertEquals(s, ex.status());
        assertEquals(code, ex.code());
    }

    private void present(Long eventId, Long userId, boolean p) {
        EventAttendance a = new EventAttendance();
        a.setPresent(p);
        when(attendance.findByEventIdAndUserId(eventId, userId)).thenReturn(Optional.of(a));
    }

    // ---- seri ----

    @Test
    void seriesCreatesWeeklyCopiesSameWallClock() {
        Instant now = Instant.now();
        UserEvent src = event(now.plus(Duration.ofDays(2)), now.plus(Duration.ofDays(2)).plusSeconds(3600));
        when(events.load(10L)).thenReturn(src);
        when(events.requireManager(ORG, src)).thenReturn(src);
        when(members.findByEventId(10L)).thenReturn(Optional.empty());
        AtomicLong ids = new AtomicLong(100);
        List<UserEvent> saved = new ArrayList<>();
        when(eventRepo.save(any(UserEvent.class))).thenAnswer(i -> {
            UserEvent u = i.getArgument(0);
            u.setId(ids.incrementAndGet());
            saved.add(u);
            return u;
        });
        when(eventRepo.findAllById(any())).thenAnswer(i -> {
            List<UserEvent> all = new ArrayList<>(saved);
            all.add(src);
            return all;
        });
        var v = new SeriesService(events, eventRepo, members).create(ORG, 10L, 3, now);
        assertEquals(4, v.events().size());
        assertEquals(10L, v.seriesId());
        assertEquals(3, saved.size());
        for (int i = 0; i < 3; i++) {
            assertEquals(src.getStartsAt().atZone(ZONE).plusWeeks(i + 1).toInstant(), saved.get(i).getStartsAt());
            assertEquals(src.getCreatedBy(), saved.get(i).getCreatedBy());
            assertEquals(src.getCapacity(), saved.get(i).getCapacity());
            assertEquals(0, saved.get(i).getGoingCount());
        }
    }

    @Test
    void seriesRejectsBadCountAlreadyInSeriesAndEnded() {
        Instant now = Instant.now();
        SeriesService svc = new SeriesService(events, eventRepo, members);
        expect(() -> svc.create(ORG, 10L, 12, now), HttpStatus.BAD_REQUEST, "INVALID_SERIES_COUNT");
        expect(() -> svc.create(ORG, 10L, 0, now), HttpStatus.BAD_REQUEST, "INVALID_SERIES_COUNT");
        UserEvent src = event(now.plusSeconds(100), now.plusSeconds(200));
        when(events.load(10L)).thenReturn(src);
        when(events.requireManager(ORG, src)).thenReturn(src);
        when(members.findByEventId(10L)).thenReturn(Optional.of(new EventSeriesMember(10L, 10L, 0)));
        expect(() -> svc.create(ORG, 10L, 2, now), HttpStatus.CONFLICT, "ALREADY_IN_SERIES");
        UserEvent past = event(now.minusSeconds(200), now.minusSeconds(100));
        when(events.load(10L)).thenReturn(past);
        when(events.requireManager(ORG, past)).thenReturn(past);
        expect(() -> svc.create(ORG, 10L, 2, now), HttpStatus.CONFLICT, "EVENT_ENDED");
    }

    @Test
    void cancelSeriesCancelsThisAndLaterOnly() {
        Instant now = Instant.now();
        UserEvent e1 = event(now.plus(Duration.ofDays(1)), now.plus(Duration.ofDays(1)).plusSeconds(60));
        e1.setId(10L);
        UserEvent e2 = event(now.plus(Duration.ofDays(8)), now.plus(Duration.ofDays(8)).plusSeconds(60));
        e2.setId(11L);
        UserEvent e3 = event(now.plus(Duration.ofDays(15)), now.plus(Duration.ofDays(15)).plusSeconds(60));
        e3.setId(12L);
        when(events.load(11L)).thenReturn(e2);
        when(events.requireManager(ORG, e2)).thenReturn(e2);
        when(events.canManage(ORG, e1)).thenReturn(true);
        when(events.canManage(ORG, e2)).thenReturn(true);
        when(events.canManage(ORG, e3)).thenReturn(true);
        when(members.findByEventId(11L)).thenReturn(Optional.of(new EventSeriesMember(11L, 10L, 1)));
        when(members.findBySeriesIdOrderBySeq(10L)).thenReturn(List.of(
                new EventSeriesMember(10L, 10L, 0), new EventSeriesMember(11L, 10L, 1), new EventSeriesMember(12L, 10L, 2)));
        when(eventRepo.findAllById(any())).thenReturn(List.of(e1, e2, e3));
        int n = new SeriesService(events, eventRepo, members).cancelFromHere(ORG, 11L, now);
        assertEquals(2, n);
        verify(events, never()).delete(ORG, 10L);
        verify(events).delete(ORG, 11L);
        verify(events).delete(ORG, 12L);
    }

    // ---- anket ----

    private EventFeedbackService feedback() {
        return new EventFeedbackService(events, attendance, feedbackRepo);
    }

    @Test
    void feedbackRequiresEndedEventAndAttendanceAndSingleAnswer() {
        Instant now = Instant.now();
        UserEvent running = event(now.minusSeconds(100), now.plusSeconds(100));
        when(events.loadVisible(USER, 10L)).thenReturn(running);
        expect(() -> feedback().submit(USER, 10L, 5, "iyi", now), HttpStatus.CONFLICT, "FEEDBACK_NOT_OPEN");

        UserEvent ended = event(now.minusSeconds(200), now.minusSeconds(100));
        when(events.loadVisible(USER, 10L)).thenReturn(ended);
        present(10L, 7L, false);
        expect(() -> feedback().submit(USER, 10L, 5, "iyi", now), HttpStatus.FORBIDDEN, "EVENT_NOT_ATTENDED");
        verify(feedbackRepo, never()).saveAndFlush(any());

        present(10L, 7L, true);
        when(feedbackRepo.findByEventIdAndUserId(10L, 7L)).thenReturn(Optional.of(new EventFeedback()));
        expect(() -> feedback().submit(USER, 10L, 5, "iyi", now), HttpStatus.CONFLICT, "FEEDBACK_EXISTS");

        when(feedbackRepo.findByEventIdAndUserId(10L, 7L)).thenReturn(Optional.empty());
        expect(() -> feedback().submit(USER, 10L, 6, null, now), HttpStatus.BAD_REQUEST, "INVALID_RATING");
        var v = feedback().submit(USER, 10L, 4, "  ", now);
        assertEquals(4, v.rating());
        assertEquals(null, v.comment());
        verify(feedbackRepo).saveAndFlush(any(EventFeedback.class));
    }

    @Test
    void feedbackSummaryAveragesAndOnlyManagers() {
        UserEvent e = event(Instant.now(), Instant.now());
        when(events.load(10L)).thenReturn(e);
        when(feedbackRepo.distribution(10L)).thenReturn(List.of(new Object[] {5, 3L}, new Object[] {4, 1L}));
        var s = feedback().summary(ORG, 10L);
        assertEquals(4, s.count());
        assertEquals(4.75, s.average());
        assertEquals(3, s.distribution()[4]);
        when(events.requireManager(USER, e)).thenThrow(new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", "x"));
        expect(() -> feedback().summary(USER, 10L), HttpStatus.FORBIDDEN, "FORBIDDEN");
    }

    // ---- sertifika ----

    private CertificateService certs() {
        return new CertificateService(events, eventRepo, attendance, certRepo, communities);
    }

    private User user(UserStatus st) {
        User u = new User();
        u.setId(7L);
        u.setDisplayName("Ayse Yilmaz");
        u.setStatus(st);
        return u;
    }

    @Test
    void certificateOnlyForPresentUserAndCodeIsUnguessable() {
        UserEvent e = event(Instant.now().minusSeconds(200), Instant.now().minusSeconds(100));
        when(events.loadVisible(USER, 10L)).thenReturn(e);
        present(10L, 7L, false);
        expect(() -> certs().issue(USER, 10L), HttpStatus.FORBIDDEN, "EVENT_NOT_ATTENDED");

        present(10L, 7L, true);
        when(certRepo.findByEventIdAndUserId(10L, 7L)).thenReturn(Optional.empty());
        when(communities.usersById(any())).thenReturn(Map.of(7L, user(UserStatus.ACTIVE)));
        var c = certs().issue(USER, 10L);
        assertEquals(20, c.code().length());
        assertTrue(c.code().matches("[A-Z2-7]{20}"));
        assertEquals("Ayse Yilmaz", c.holderName());
        assertEquals("/api/certificates/verify/" + c.code(), c.verifyPath());
        assertNotEquals(CertificateService.newCode(), CertificateService.newCode());
    }

    @Test
    void certificateIssueIsIdempotent() {
        UserEvent e = event(Instant.now().minusSeconds(200), Instant.now().minusSeconds(100));
        when(events.loadVisible(USER, 10L)).thenReturn(e);
        present(10L, 7L, true);
        EventCertificate existing = new EventCertificate();
        existing.setCode("ABCDEFGHIJKLMNOPQRST");
        existing.setHolderName("Ayse");
        when(certRepo.findByEventIdAndUserId(10L, 7L)).thenReturn(Optional.of(existing));
        assertEquals("ABCDEFGHIJKLMNOPQRST", certs().issue(USER, 10L).code());
        verify(certRepo, never()).saveAndFlush(any());
    }

    @Test
    void verifyRejectsMalformedAndUnknownCodesWith404() {
        expect(() -> certs().verify("short"), HttpStatus.NOT_FOUND, "CERTIFICATE_NOT_FOUND");
        expect(() -> certs().verify("abc'; DROP TABLE x;--"), HttpStatus.NOT_FOUND, "CERTIFICATE_NOT_FOUND");
        expect(() -> certs().verify(null), HttpStatus.NOT_FOUND, "CERTIFICATE_NOT_FOUND");
        expect(() -> certs().verify("ABCDEFGHIJKLMNOPQRST"), HttpStatus.NOT_FOUND, "CERTIFICATE_NOT_FOUND");
        verify(certRepo, times(1)).findByCode(any());
    }

    @Test
    void verifyValidThenInvalidWhenAttendanceRetractedOrUserDeleted() {
        EventCertificate c = new EventCertificate();
        c.setEventId(10L);
        c.setUserId(7L);
        c.setCode("ABCDEFGHIJKLMNOPQRST");
        c.setHolderName("Ayse Yilmaz");
        UserEvent e = event(Instant.now().minusSeconds(200), Instant.now().minusSeconds(100));
        when(certRepo.findByCode("ABCDEFGHIJKLMNOPQRST")).thenReturn(Optional.of(c));
        when(eventRepo.findById(10L)).thenReturn(Optional.of(e));
        when(communities.usersById(any())).thenReturn(Map.of(7L, user(UserStatus.ACTIVE)));
        present(10L, 7L, true);
        var ok = certs().verify("abcd-efgh-ijkl-mnop-qrst");
        assertTrue(ok.valid());
        assertEquals("Ayse Yilmaz", ok.holderName());

        present(10L, 7L, false);
        var bad = certs().verify("ABCDEFGHIJKLMNOPQRST");
        assertFalse(bad.valid());
        assertEquals(null, bad.holderName());

        present(10L, 7L, true);
        when(communities.usersById(any())).thenReturn(Map.of(7L, user(UserStatus.DELETED)));
        assertFalse(certs().verify("ABCDEFGHIJKLMNOPQRST").valid());
    }
}
