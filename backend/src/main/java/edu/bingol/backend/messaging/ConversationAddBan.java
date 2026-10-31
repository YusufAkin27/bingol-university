package edu.bingol.backend.messaging;

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

/**
 * T-025: gruptan cikan/cikarilan kullaniciyi onu ekleyen kisinin tekrar eklemesini engeller (rizasiz grup ekleme).
 * (user_id, adder_id) birincil anahtar; kayit hicbir yerde kullaniciya gosterilmez, ekleyen yalnizca "eklenmedi" gorur.
 */
@Entity
@Table(name = "conversation_add_ban")
@IdClass(ConversationAddBan.Key.class)
@Getter
@Setter
@NoArgsConstructor
public class ConversationAddBan {

    @Id
    @Column(name = "user_id")
    private Long userId;

    @Id
    @Column(name = "adder_id")
    private Long adderId;

    /** Cikisin yasandigi konusma (bilgi amacli). */
    @Column(name = "conversation_id")
    private Long conversationId;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    public ConversationAddBan(Long userId, Long adderId, Long conversationId) {
        this.userId = userId;
        this.adderId = adderId;
        this.conversationId = conversationId;
    }

    @Getter
    @Setter
    @NoArgsConstructor
    @AllArgsConstructor
    @EqualsAndHashCode
    public static class Key implements Serializable {
        private Long userId;
        private Long adderId;
    }
}
