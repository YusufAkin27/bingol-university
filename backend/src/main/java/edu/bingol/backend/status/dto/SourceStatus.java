package edu.bingol.backend.status.dto;

import edu.bingol.backend.status.SyncStatus;

/**
 * maintenance=true ise mobil "bakimda" bandi gostermeli. message teknik (Turkce) ayrinti,
 * maintenanceMessage istek dilinde kullaniciya gosterilecek metindir (bakim yoksa null).
 */
public record SourceStatus(boolean maintenance, String lastSuccessAt, String lastAttemptAt, String message,
                           String maintenanceMessage) {

    /** Yonetim raporlari icin: yerellestirilmis bakim metni olmadan. */
    public static SourceStatus of(SyncStatus s) {
        return of(s, null);
    }

    public static SourceStatus of(SyncStatus s, String maintenanceMessage) {
        boolean maintenance = s.getState() == SyncStatus.State.MAINTENANCE;
        return new SourceStatus(
                maintenance,
                s.getLastSuccessAt() == null ? null : s.getLastSuccessAt().toString(),
                s.getLastAttemptAt() == null ? null : s.getLastAttemptAt().toString(),
                s.getMessage(),
                maintenance ? maintenanceMessage : null);
    }
}
