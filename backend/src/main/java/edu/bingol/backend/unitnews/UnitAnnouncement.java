package edu.bingol.backend.unitnews;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.Instant;
import java.time.LocalDate;
import lombok.Getter;
import lombok.Setter;

/** Alt sitelerden cekilen duyuru. url benzersizdir (yeniden cekilmez); ekler JSON dizisi olarak saklanir. */
@Entity
@Table(name = "unit_announcement", uniqueConstraints = @UniqueConstraint(columnNames = "url"))
@Getter
@Setter
public class UnitAnnouncement {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 20)
    private String sourceCode;

    /** Bolum akisindan geldiyse bolum slug'i; genel (fakulte/okul) akistan geldiyse null. */
    @Column(length = 160)
    private String deptSlug;

    @Column(nullable = false, length = 300)
    private String title;

    @Column(nullable = false, length = 500)
    private String url;

    @Column(nullable = false)
    private LocalDate publishedDate;

    @Column(nullable = false, length = 300)
    private String summary = "";

    @Column(columnDefinition = "TEXT")
    private String body;

    /** [{"name","url","type"}] JSON. */
    @Column(columnDefinition = "TEXT")
    private String attachments;

    @Column(nullable = false)
    private boolean hidden;

    @Column(nullable = false)
    private Instant fetchedAt = Instant.now();

    /** Bildirimi (bolumunuzde yeni duyuru) gonderildi mi; null = bekliyor (V1180). */
    private Instant notifiedAt;
}
