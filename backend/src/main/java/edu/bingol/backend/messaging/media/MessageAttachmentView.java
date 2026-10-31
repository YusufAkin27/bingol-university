package edu.bingol.backend.messaging.media;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.IdClass;
import jakarta.persistence.Table;
import java.io.Serializable;
import java.time.Instant;
import lombok.AllArgsConstructor;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Tek gosterimlik ekin kim tarafindan ne zaman acildigi. (attachment_id, user_id) birincil anahtar: ikinci acis olmaz. */
@Entity
@Table(name = "message_attachment_view")
@IdClass(MessageAttachmentView.Key.class)
@Getter
@Setter
@NoArgsConstructor
public class MessageAttachmentView {

    @Id
    @Column(name = "attachment_id")
    private Long attachmentId;

    @Id
    @Column(name = "user_id")
    private Long userId;

    /** Acis TALEBI zamani (T-033: govde yazilmaya baslarken alinir; yazim bitene kadar deliveredAt bos kalir). */
    @Column(nullable = false)
    private Instant viewedAt = Instant.now();

    /** Govde istemciye TAMAMEN yazildiginda dolar; bos satir = devam eden ya da yarim kalan acis (gorulmus sayilmaz). */
    private Instant deliveredAt;

    /** Teslimden sonraki tek yeniden acis (ag kopmasi penceresi) kullanildiysa dolar. */
    private Instant reopenedAt;

    public MessageAttachmentView(Long attachmentId, Long userId) {
        this.attachmentId = attachmentId;
        this.userId = userId;
    }

    @Getter
    @Setter
    @NoArgsConstructor
    @AllArgsConstructor
    @EqualsAndHashCode
    public static class Key implements Serializable {
        private Long attachmentId;
        private Long userId;
    }
}
