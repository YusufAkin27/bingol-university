package edu.bingol.backend.event;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Etkinlik moderatoru: sahibin kulup uyeleri arasindan sectigi, bit alani ile tek tek yetkilendirilen kisi. */
@Entity
@Table(name = "event_moderator")
@Getter
@Setter
public class EventModerator {

    /** Moderatore verilebilen yetkiler. Kapatma/iptal/silme, yoklamayi acip kapatma, moderator ve yetki yonetimi HICBIR ZAMAN burada degildir (sahip-ozel). */
    public enum Perm {
        TAKE_ATTENDANCE(1), MANAGE_REQUESTS(2), VIEW_ATTENDEES(4), SEND_ANNOUNCEMENT(8), EDIT_INFO(16), EDIT_SCHEDULE(32);

        public final int bit;

        Perm(int bit) {
            this.bit = bit;
        }
    }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long eventId;

    @Column(nullable = false)
    private Long userId;

    @Column(nullable = false)
    private int permissions;

    @Column(nullable = false)
    private Long addedBy;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    @Column(nullable = false)
    private Instant updatedAt = Instant.now();

    public boolean has(Perm p) {
        return (permissions & p.bit) != 0;
    }
}
