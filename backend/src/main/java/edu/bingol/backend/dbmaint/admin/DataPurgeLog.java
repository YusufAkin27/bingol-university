package edu.bingol.backend.dbmaint.admin;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.time.LocalDate;
import lombok.Getter;
import lombok.Setter;

/** Elle temizlik meta kaydi (V830): denetim kaydinin kendisi silinse bile kim/ne zaman/ne kadar silmis kalir. */
@Entity
@Table(name = "data_purge_log")
@Getter
@Setter
public class DataPurgeLog {

    public enum Status { RUNNING, COMPLETED, FAILED, INTERRUPTED }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 48)
    private String tableName;

    @Column(nullable = false)
    private LocalDate rangeFrom;

    @Column(nullable = false)
    private LocalDate rangeTo;

    private Long receiptId;

    @Column(nullable = false)
    private boolean forced;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 12)
    private Status status = Status.RUNNING;

    @Column(nullable = false)
    private long estRows;

    @Column(nullable = false)
    private long deletedRows;

    private Instant oldestAt;

    private Instant newestAt;

    @Column(nullable = false, length = 300)
    private String reason;

    private Long adminId;

    @Column(length = 254)
    private String adminEmail;

    @Column(length = 64)
    private String requestId;

    @Column(length = 300)
    private String error;

    @Column(nullable = false)
    private Instant startedAt = Instant.now();

    @Column(nullable = false)
    private Instant updatedAt = Instant.now();

    private Instant finishedAt;
}
