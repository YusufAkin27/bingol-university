package edu.bingol.backend.event.admission;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import lombok.Getter;
import lombok.Setter;

/** Etkinlik basina alim ayari. Satir yoksa etkinlik OPEN'dir. */
@Entity
@Table(name = "event_admission")
@Getter
@Setter
public class EventAdmission {

    public enum Mode { OPEN, APPROVAL }

    @Id
    private Long eventId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Mode mode = Mode.OPEN;

    @Column(length = 200)
    private String question1;

    @Column(length = 200)
    private String question2;

    @Column(length = 200)
    private String question3;

    @Column(nullable = false)
    private Instant updatedAt = Instant.now();

    public EventAdmission() {}

    public EventAdmission(Long eventId) {
        this.eventId = eventId;
    }

    public List<String> questions() {
        List<String> q = new ArrayList<>(3);
        for (String s : new String[] {question1, question2, question3}) {
            if (s != null && !s.isBlank()) {
                q.add(s);
            }
        }
        return q;
    }

    public void setQuestions(List<String> q) {
        question1 = q.size() > 0 ? q.get(0) : null;
        question2 = q.size() > 1 ? q.get(1) : null;
        question3 = q.size() > 2 ? q.get(2) : null;
    }
}
