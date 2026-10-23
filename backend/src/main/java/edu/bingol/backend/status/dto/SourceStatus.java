package edu.bingol.backend.status.dto;

import edu.bingol.backend.status.SyncStatus;

/** maintenance=true ise mobil "bakimda" bandi gostermeli. */
public record SourceStatus(boolean maintenance, String lastSuccessAt, String lastAttemptAt, String message) {

    public static SourceStatus of(SyncStatus s) {
        return new SourceStatus(
                s.getState() == SyncStatus.State.MAINTENANCE,
                s.getLastSuccessAt() == null ? null : s.getLastSuccessAt().toString(),
                s.getLastAttemptAt() == null ? null : s.getLastAttemptAt().toString(),
                s.getMessage());
    }
}
