package edu.bingol.backend.messaging;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Transient;
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

    /**
     * Duz metin (HTML yorumlanmaz; istemci kacis yaparak gostermelidir). KALICI DEGILDIR: veritabaninda yalnizca
     * sifreli govde (bodyCiphertext/bodyNonce/keyVersion) tutulur; bu alani {@link MessageCodec} doldurur.
     */
    @Transient
    private String body;

    /** AES-256-GCM sifreli govde (etiket sonda), 96-bit nonce ve konusma DEK surumu; bkz. docs/ENCRYPTION.md. */
    @Column(name = "body_ciphertext")
    private byte[] bodyCiphertext;

    @Column(name = "body_nonce")
    private byte[] bodyNonce;

    @Column(name = "key_version")
    private Integer keyVersion;

    /** Golge engel: engel iliskisi varken atildi; gonderen disinda kimseye gosterilmez/iletilmez (kalici). */
    @Column(nullable = false)
    private boolean suppressed = false;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    /** Moderasyonla gizlendi (yumusak silme): API icerik yerine sabit metin doner. */
    private Instant hiddenAt;

    /** Yanitlanan mesaj (ayni konusma); silinen mesajda temizlenir. */
    @Column(name = "reply_to_message_id")
    private Long replyToMessageId;

    /** Gonderen duzenlediyse zamani; onceki sifreli surumler `message_revision` tablosunda (yonetici goruntuleyici). */
    private Instant editedAt;

    /** Herkes icin silindi: kullanici API'sinde icerik kapali; sifreli govde/nonce/surum VERITABANINDA KALIR (T24, yalniz yonetici goruntuleyici). */
    private Instant deletedAt;

    private Long deletedBy;

    /** Yonetici gizlemesi (P08): hiddenAt de birlikte yazilir; bu alan gizlemenin geri alinabilir yonetici kaynakli oldugunu isaretler. */
    private Instant adminHiddenAt;

    private Long adminHiddenBy;

    /** Yonetici kalici silmesi (P08): icerik temizlendi, satir yer tutucu olarak kalir; geri alinamaz. */
    private Instant purgedAt;

    /** Yonetici kaynakli kaldirma (gizleme ya da kalici silme): kullanici "yonetici tarafindan kaldirildi" gorur. */
    public boolean isAdminRemoved() {
        return adminHiddenAt != null || purgedAt != null;
    }

    public boolean isDeleted() {
        return deletedAt != null;
    }

    public boolean isHidden() {
        return hiddenAt != null;
    }
}
