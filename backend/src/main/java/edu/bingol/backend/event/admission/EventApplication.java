package edu.bingol.backend.event.admission;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import lombok.Getter;
import lombok.Setter;

/** APPROVAL modundaki etkinlige katilim basvurusu. ACCEPTED iken kullanicinin GOING RSVP'si de vardir. */
@Entity
@Table(name = "event_application", uniqueConstraints = @UniqueConstraint(columnNames = {"event_id", "user_id"}))
@Getter
@Setter
public class EventApplication {

    public enum Status { PENDING, ACCEPTED, REJECTED, WAITLISTED, CANCELLED }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long eventId;

    @Column(nullable = false)
    private Long userId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Status status = Status.PENDING;

    @Column(length = 500)
    private String note;

    @Column(length = 500)
    private String answer1;

    @Column(length = 500)
    private String answer2;

    @Column(length = 500)
    private String answer3;

    /** Bekleme listesine giris ani (terfi sirasi). */
    private Instant queuedAt;

    private Long decidedBy;

    private Instant decidedAt;

    @Column(length = 300)
    private String decisionNote;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    @Column(nullable = false)
    private Instant updatedAt = Instant.now();

    public EventApplication() {}

    public EventApplication(Long eventId, Long userId) {
        this.eventId = eventId;
        this.userId = userId;
    }

    public List<String> answers() {
        List<String> a = new ArrayList<>(3);
        for (String s : new String[] {answer1, answer2, answer3}) {
            if (s != null) {
                a.add(s);
            }
        }
        return a;
    }

    public void setAnswers(List<String> a) {
        answer1 = a.size() > 0 ? a.get(0) : null;
        answer2 = a.size() > 1 ? a.get(1) : null;
        answer3 = a.size() > 2 ? a.get(2) : null;
    }
}
