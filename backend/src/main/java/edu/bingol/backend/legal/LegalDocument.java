package edu.bingol.backend.legal;

import jakarta.persistence.Column;
import edu.bingol.backend.common.cache.CacheInvalidationListener;
import jakarta.persistence.EntityListeners;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Bir sozlesmenin belirli dil ve surumdeki metni. Surum numarasi dillerde ortaktir; tr belge esastir. */
@Entity
@EntityListeners(CacheInvalidationListener.class)
@Getter
@Setter
public class LegalDocument {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 24)
    private LegalType type;

    @Column(nullable = false, length = 2)
    private String lang;

    @Column(nullable = false)
    private int version;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String content;

    @Column(nullable = false)
    private boolean requireReaccept = true;

    @Column(nullable = false)
    private boolean active;

    @Column(nullable = false)
    private Instant publishedAt = Instant.now();
}
