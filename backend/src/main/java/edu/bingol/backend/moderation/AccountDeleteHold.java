package edu.bingol.backend.moderation;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Acik sikayeti olan hesabin silme bekletmesi (T-058, V990): ilk talepte kayitlanir, {@code releaseAt} sonrasi silinebilir. */
@Entity
@Table(name = "account_delete_hold")
@Getter
@Setter
public class AccountDeleteHold {

    @Id
    private Long userId;

    @Column(nullable = false)
    private Instant requestedAt = Instant.now();

    @Column(nullable = false)
    private Instant releaseAt;
}
