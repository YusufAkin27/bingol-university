package edu.bingol.backend.dbmaint.admin;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.time.LocalDate;
import lombok.Getter;
import lombok.Setter;

/** Disa aktarma makbuzu (V830): tablo, aralik, satir sayisi, SHA-256, yonetici. Silinemez (tetikleyici). */
@Entity
@Table(name = "data_export_receipt")
@Getter
@Setter
public class DataExportReceipt {

    public enum Status { RUNNING, COMPLETED, PARTIAL, FAILED }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 48)
    private String tableName;

    @Column(nullable = false)
    private LocalDate rangeFrom;

    /** Haric. */
    @Column(nullable = false)
    private LocalDate rangeTo;

    @Column(nullable = false, length = 16)
    private String format = "CSV_GZIP";

    @Column(nullable = false, length = 12)
    @jakarta.persistence.Enumerated(jakarta.persistence.EnumType.STRING)
    private Status status = Status.RUNNING;

    @Column(nullable = false)
    private long rowCount;

    @Column(nullable = false)
    private long byteCount;

    @Column(length = 64)
    private String sha256;

    private Long adminId;

    @Column(length = 254)
    private String adminEmail;

    @Column(length = 300)
    private String reason;

    @Column(length = 64)
    private String requestId;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    private Instant finishedAt;
}
