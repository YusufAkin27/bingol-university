package edu.bingol.backend.event.dto;

import edu.bingol.backend.event.UserEvent;
import edu.bingol.backend.event.dto.EventDtos.EventView;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;

/** Yonetici etkinlik moderasyonu istek/yanit kayitlari. */
public final class EventAdminDtos {

    private EventAdminDtos() {}

    /** hide / unhide / cancel govdesi; sebep zorunlu (en cok 300 karakter), denetim gecmisine yazilir. */
    public record ReasonRequest(@NotBlank @Size(max = 300) String reason) {
    }

    /** PATCH govdesi: UpdateEventRequest alanlari (hepsi opsiyonel; capacity=0 sinirsiz) + istege bagli denetim sebebi. */
    public record AdminUpdateRequest(
            @Size(min = 3, max = 150) String title,
            @Size(max = 2000) String description,
            Instant startsAt,
            Instant endsAt,
            @Size(max = 200) String location,
            @jakarta.validation.constraints.Min(0) @jakarta.validation.constraints.Max(100000) Integer capacity,
            edu.bingol.backend.event.admission.EventAdmission.Mode joinPolicy,
            @Size(max = 300) String reason) {
        public EventDtos.UpdateEventRequest toUpdate() {
            return new EventDtos.UpdateEventRequest(title, description, startsAt, endsAt, location, capacity, joinPolicy);
        }
    }

    /** Katilim isteklerinin (APPROVAL) durum sayilari. */
    public record RequestCounts(long pending, long waitlisted, long accepted, long rejected, long cancelled) {
    }

    /** action: HIDE | UNHIDE | CANCEL | DELETE | EDIT | REPORT_HIDE | REPORT_UNHIDE. adminId/adminName null = Basic auth ya da rapor otomasyonu. */
    public record ModerationEntry(Long id, Long adminId, String adminName, String action,
                                  UserEvent.Status fromStatus, UserEvent.Status toStatus, String reason,
                                  Instant createdAt) {
    }

    /**
     * Yonetici detayi. allowedActions: bu durumda yapilabilecek islemler (approve, reject, hide, unhide, cancel);
     * web dugmeleri buna gore gosterir. attendedCount: yoklamada "geldi" isaretlenenler.
     */
    public record AdminEventDetail(EventView event, String organizerEmail, RequestCounts requests, long attendedCount,
                                   String reviewNote, String moderationReason, Long moderatedBy, Instant moderatedAt,
                                   List<ModerationEntry> history, List<String> allowedActions) {
    }
}
