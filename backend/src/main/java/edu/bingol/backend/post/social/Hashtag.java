package edu.bingol.backend.post.social;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** #etiket: tag = aksansiz arama anahtari (benzersiz), display = Turkce kucuk harfli gorunen ad. */
@Entity
@Table(name = "hashtag")
@Getter
@Setter
@NoArgsConstructor
public class Hashtag {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 40, unique = true)
    private String tag;

    @Column(nullable = false, length = 40)
    private String display;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();
}
