package edu.bingol.backend.menu;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.time.LocalDate;
import lombok.Getter;
import lombok.Setter;

/** Gunun menusu push'unun o gun denendigini gosteren idempotens kaydi (V1800). Yazma {@link JdbcDailyMenuLog} ile. */
@Entity
@Table(name = "daily_menu_push_log")
@Getter
@Setter
public class DailyMenuPushLog {

    @Id
    @Column(name = "push_date")
    private LocalDate pushDate;

    @Column(name = "outcome", nullable = false, length = 16)
    private String outcome;

    @Column(name = "enqueued_count", nullable = false)
    private int enqueuedCount;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();
}
