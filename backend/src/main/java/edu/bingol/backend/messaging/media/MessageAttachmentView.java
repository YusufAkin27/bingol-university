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

    @Column(nullable = false)
    private Instant viewedAt = Instant.now();

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
