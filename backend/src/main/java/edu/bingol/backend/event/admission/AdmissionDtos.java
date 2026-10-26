package edu.bingol.backend.event.admission;

import edu.bingol.backend.event.admission.EventAdmission.Mode;
import edu.bingol.backend.event.admission.EventApplication.Status;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;

/** Katilim (admission) uclarinin istek/yanit kayitlari. */
public final class AdmissionDtos {

    private AdmissionDtos() {}

    /** questions en fazla 3 adet, her biri en fazla 200 karakter (sinirlar serviste dogrulanir). */
    public record ConfigRequest(@NotNull Mode mode, @Size(max = 3) List<@Size(max = 200) String> questions) {
    }

    public record ConfigView(Long eventId, Mode mode, List<String> questions) {
    }

    /** answers: tanimli sorularla ayni sayida; her biri en fazla 500 karakter. */
    public record ApplyRequest(@Size(max = 500) String note, @Size(max = 3) List<@Size(max = 500) String> answers) {
    }

    /** Kullanicinin kendi basvurusu. queuePosition yalnizca WAITLISTED iken (1 = siradaki). */
    public record ApplicationView(Long id, Long eventId, String eventTitle, Status status, String note,
                                  List<String> answers, Integer queuePosition, String decisionNote,
                                  Instant createdAt, Instant updatedAt) {
    }

    /** Organizatorun gordugu basvuru. */
    public record ApplicantView(Long id, Long userId, String displayName, String avatarUrl, String department,
                                Status status, String note, List<String> answers, Instant queuedAt,
                                Instant createdAt, Instant updatedAt) {
    }

    public enum Action { ACCEPT, REJECT, WAITLIST }

    public record DecisionRequest(@NotEmpty @Size(max = 100) List<Long> ids, @NotNull Action action,
                                  @Size(max = 300) String reason) {
    }

    public record SingleDecisionRequest(@Size(max = 300) String reason) {
    }

    /** Her kimlik icin sonuc: status dolu (yeni durum) veya error kodu. */
    public record DecisionItem(Long id, Status status, String error) {
    }

    public record DecisionResult(List<DecisionItem> items) {
    }

    /** Organizator ozeti: durum sayilari + doluluk. */
    public record AdmissionSummary(Long eventId, Mode mode, Integer capacity, int goingCount, long pending,
                                   long accepted, long waitlisted, long rejected, long cancelled) {
    }
}
