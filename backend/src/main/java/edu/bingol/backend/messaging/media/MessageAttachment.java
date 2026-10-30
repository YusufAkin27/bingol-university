package edu.bingol.backend.messaging.media;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Sohbet gorseli eki. Baytlar ozel depoda (sifreli); burada anahtar + meta veri. messageId null = henuz mesaja baglanmadi. */
@Entity
@Table(name = "message_attachment")
@Getter
@Setter
public class MessageAttachment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long conversationId;

    @Column(nullable = false)
    private Long uploaderId;

    private Long messageId;

    @Column(nullable = false, length = 16)
    private String kind = "IMAGE";

    @Column(nullable = false, length = 80)
    private String storageKey;

    /** Video icin poster anahtari; poster yoksa null. */
    @Column(length = 80)
    private String thumbKey;

    @Column(nullable = false)
    private int width;

    @Column(nullable = false)
    private int height;

    /** Kucuk resmin gercek uzun kenari (px); null = eski kayit (320 px varsayilir). Istemci balon kaynagini bununla secer. */
    private Integer thumbEdge;

    @Column(nullable = false)
    private long bytes;

    @Column(nullable = false, length = 40)
    private String contentType;

    /** Yalniz video: sure (ms). */
    private Integer durationMs;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    private Instant hiddenAt;

    @Column(length = 16)
    private String hiddenBy;

    /** Tek gosterimlik: alicilar yalnizca bir kez acabilir; onizleme/link yok. */
    @Column(nullable = false)
    private boolean viewOnce = false;

    /** Tek gosterimlik baytlar diskten silindi (goruntuleme kaydi kalir). */
    private Instant purgedAt;

    public boolean isVideo() {
        return "VIDEO".equals(kind);
    }

    public boolean isHidden() {
        return hiddenAt != null;
    }
}
