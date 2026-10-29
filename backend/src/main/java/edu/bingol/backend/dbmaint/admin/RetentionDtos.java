package edu.bingol.backend.dbmaint.admin;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.time.LocalDate;

/** Veri saklama uclarinin istek/yanit kayitlari. */
public final class RetentionDtos {

    private RetentionDtos() {}

    /** Tablo satiri: satir sayisi TAHMINIDIR (pg_class.reltuples), tam COUNT yapilmaz. */
    public record TableInfo(String name, String label, String description, Long estimatedRows, Long sizeBytes,
                            Instant oldestAt, int minRetentionDays, LocalDate maxTo, boolean deletable,
                            String notDeletableReason, boolean personalData) {
    }

    public record ExportRequest(@NotBlank @Size(max = 48) String table, LocalDate from, LocalDate to,
                                @Size(max = 300) String reason) {
    }

    public record ReceiptView(Long id, String table, LocalDate from, LocalDate to, String format, String status,
                              long rowCount, long byteCount, String sha256, Long adminId, String adminEmail,
                              String reason, Instant createdAt, Instant finishedAt) {
    }

    public record PurgePreview(String table, LocalDate from, LocalDate to, long rowsInRange, boolean capped,
                               Long estimatedBytes, boolean deletable, String notDeletableReason, LocalDate maxTo,
                               int minRetentionDays, ReceiptView receipt, boolean receiptStale, boolean canPurge,
                               java.util.List<String> blockers) {
    }

    public record PurgeRequest(@NotBlank @Size(max = 48) String table, LocalDate from, LocalDate to,
                               @NotBlank @Size(max = 48) String confirmTable, Long receiptId,
                               Boolean forceWithoutExport, String reason) {
    }

    public record PurgeView(Long id, String table, LocalDate from, LocalDate to, Long receiptId, boolean forced,
                            String status, long estRows, long deletedRows, Instant oldestAt, Instant newestAt,
                            String reason, Long adminId, String adminEmail, String error, Instant startedAt,
                            Instant updatedAt, Instant finishedAt, boolean vacuumRecommended) {
    }
}
