package edu.bingol.backend.status;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Her veri kaynagi (NEWS, MENU) icin son senkronizasyon durumu. */
@Entity
@Getter
@Setter
public class SyncStatus {

    public enum State { OK, MAINTENANCE }

    @Id
    @Column(length = 32)
    private String source;

    private Instant lastAttemptAt;

    private Instant lastSuccessAt;

    private State state = State.OK;

    @Column(length = 500)
    private String message;
}
