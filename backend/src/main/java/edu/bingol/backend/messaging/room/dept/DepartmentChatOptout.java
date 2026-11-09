package edu.bingol.backend.messaging.room.dept;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.IdClass;
import jakarta.persistence.Table;
import java.io.Serializable;
import java.time.Instant;
import java.util.Objects;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Kullanicinin kendi ciktigi bolum kanali: otomatik katilim bu kanala bir daha eklemez (V1810). */
@Entity
@Table(name = "department_chat_optout")
@IdClass(DepartmentChatOptout.Key.class)
@Getter
@Setter
@NoArgsConstructor
public class DepartmentChatOptout {

    @Id
    @Column(name = "user_id")
    private Long userId;

    @Id
    @Column(name = "dept_key", length = 200)
    private String deptKey;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();

    public DepartmentChatOptout(Long userId, String deptKey) {
        this.userId = userId;
        this.deptKey = deptKey;
    }

    public static class Key implements Serializable {
        private Long userId;
        private String deptKey;

        public Key() {}

        @Override
        public boolean equals(Object o) {
            return o instanceof Key k && Objects.equals(userId, k.userId) && Objects.equals(deptKey, k.deptKey);
        }

        @Override
        public int hashCode() {
            return Objects.hash(userId, deptKey);
        }
    }
}
