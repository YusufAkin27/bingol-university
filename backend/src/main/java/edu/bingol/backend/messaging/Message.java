package edu.bingol.backend.messaging;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

@Entity
@Getter
@Setter
public class Message {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long conversationId;

    @Column(nullable = false)
    private Long senderId;

    /** Istemci kimligi; (conversation, sender, clientId) benzersiz. */
    @Column(nullable = false, length = 64)
    private String clientId;

    /** Duz metin (HTML yorumlanmaz); istemci kacis yaparak gostermelidir. */
    @Column(nullable = false, length = 2000)
    private String body;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    /** Moderasyonla gizlendi (yumusak silme): API icerik yerine sabit metin doner. */
    private Instant hiddenAt;

    public boolean isHidden() {
        return hiddenAt != null;
    }
}
