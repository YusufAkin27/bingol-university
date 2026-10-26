package edu.bingol.backend.event.extras;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

/** Haftalik seriye ait etkinlik; seriesId = ilk etkinligin id'si, seq = 0'dan baslayan sira. */
@Entity
@Table(name = "event_series_member")
@Getter
@Setter
public class EventSeriesMember {

    @Id
    private Long eventId;

    @Column(nullable = false)
    private Long seriesId;

    @Column(nullable = false)
    private int seq;

    public EventSeriesMember() {}

    public EventSeriesMember(Long eventId, Long seriesId, int seq) {
        this.eventId = eventId;
        this.seriesId = seriesId;
        this.seq = seq;
    }
}
