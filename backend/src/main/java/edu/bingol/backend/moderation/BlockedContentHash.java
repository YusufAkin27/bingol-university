package edu.bingol.backend.moderation;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Yasakli icerik ozeti (SHA-256, 64 karakter kucuk harf hex). */
@Entity
@Getter
@Setter
@NoArgsConstructor
public class BlockedContentHash {

    @Id
    @Column(length = 64)
    private String sha256;

    @Column(length = 300)
    private String note;

    private Long createdBy;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    public BlockedContentHash(String sha256, String note, Long createdBy) {
        this.sha256 = sha256;
        this.note = note;
        this.createdBy = createdBy;
    }
}
