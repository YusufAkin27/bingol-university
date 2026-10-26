package edu.bingol.backend.event.extras;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Paging;
import edu.bingol.backend.community.Texts;
import edu.bingol.backend.event.EventAttendance;
import edu.bingol.backend.event.EventAttendanceRepository;
import edu.bingol.backend.event.EventService;
import edu.bingol.backend.event.UserEvent;
import edu.bingol.backend.event.extras.ExtrasDtos.FeedbackSummary;
import edu.bingol.backend.event.extras.ExtrasDtos.FeedbackView;
import java.time.Instant;
import java.util.List;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Etkinlik sonrasi anket: yalnizca yoklamasi alinmis (present) kullanici, etkinlik bittikten sonra, tek yanit.
 * Organizator listesi anonimdir (kimlik donmez); yorum yazarini ifsa etmemek icin.
 */
@Service
public class EventFeedbackService {

    private final EventService events;
    private final EventAttendanceRepository attendance;
    private final EventFeedbackRepository repo;

    public EventFeedbackService(EventService events, EventAttendanceRepository attendance, EventFeedbackRepository repo) {
        this.events = events;
        this.attendance = attendance;
        this.repo = repo;
    }

    @Transactional
    public FeedbackView submit(Actor a, Long eventId, int rating, String comment, Instant now) {
        UserEvent e = events.loadVisible(a, eventId);
        if (rating < 1 || rating > 5) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_RATING", "Puan 1 ile 5 arasında olmalı.");
        }
        if (e.getStatus() != UserEvent.Status.ACTIVE) {
            throw new ApiException(HttpStatus.CONFLICT, "EVENT_NOT_OPEN", "Etkinlik henüz yayında değil.");
        }
        if (e.getEndsAt().isAfter(now)) {
            throw new ApiException(HttpStatus.CONFLICT, "FEEDBACK_NOT_OPEN", "Geri bildirim etkinlik bittikten sonra verilebilir.");
        }
        if (!attended(eventId, a.id())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "EVENT_NOT_ATTENDED", "Bu işlem için etkinliğe katılmış (yoklaması alınmış) olmalısınız.");
        }
        if (repo.findByEventIdAndUserId(eventId, a.id()).isPresent()) {
            throw new ApiException(HttpStatus.CONFLICT, "FEEDBACK_EXISTS", "Bu etkinlik için zaten geri bildirim verdiniz.");
        }
        EventFeedback f = new EventFeedback();
        f.setEventId(eventId);
        f.setUserId(a.id());
        f.setRating((short) rating);
        f.setComment(Texts.blankToNull(comment));
        f.setCreatedAt(now);
        try {
            repo.saveAndFlush(f);
        } catch (DataIntegrityViolationException ex) {
            throw new ApiException(HttpStatus.CONFLICT, "FEEDBACK_EXISTS", "Bu etkinlik için zaten geri bildirim verdiniz.");
        }
        return toView(f);
    }

    @Transactional(readOnly = true)
    public FeedbackView mine(Actor a, Long eventId) {
        events.loadVisible(a, eventId);
        return repo.findByEventIdAndUserId(eventId, a.id()).map(EventFeedbackService::toView).orElseThrow(() ->
                new ApiException(HttpStatus.NOT_FOUND, "FEEDBACK_NOT_FOUND", "Geri bildirim bulunamadı."));
    }

    @Transactional(readOnly = true)
    public FeedbackSummary summary(Actor a, Long eventId) {
        events.requireManager(a, events.load(eventId));
        long[] dist = new long[5];
        long total = 0;
        long sum = 0;
        for (Object[] row : repo.distribution(eventId)) {
            int rating = ((Number) row[0]).intValue();
            long n = ((Number) row[1]).longValue();
            if (rating >= 1 && rating <= 5) {
                dist[rating - 1] = n;
                total += n;
                sum += n * rating;
            }
        }
        double avg = total == 0 ? 0 : Math.round(sum * 100.0 / total) / 100.0;
        return new FeedbackSummary(total, avg, dist);
    }

    @Transactional(readOnly = true)
    public CursorPage<FeedbackView> list(Actor a, Long eventId, Long cursor, int size) {
        events.requireManager(a, events.load(eventId));
        int s = CursorPage.clampSize(size);
        List<EventFeedback> rows = repo.page(eventId, Paging.descStart(cursor), PageRequest.of(0, s + 1));
        return Paging.map(rows, s, EventFeedback::getId, items -> items.stream().map(EventFeedbackService::toView).toList());
    }

    private boolean attended(Long eventId, Long userId) {
        return attendance.findByEventIdAndUserId(eventId, userId).filter(EventAttendance::isPresent).isPresent();
    }

    private static FeedbackView toView(EventFeedback f) {
        return new FeedbackView(f.getRating(), f.getComment(), f.getCreatedAt());
    }
}
