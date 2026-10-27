package edu.bingol.backend.event.dto;

import edu.bingol.backend.event.EventAttendance.Method;
import edu.bingol.backend.event.EventRsvp;
import edu.bingol.backend.event.UserEvent;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

/** Etkinlik uclarinin istek/yanit kayitlari. */
public final class EventDtos {

    private EventDtos() {}

    public record CreateEventRequest(
            @NotBlank @Size(min = 3, max = 150) String title,
            @Size(max = 2000) String description,
            @NotNull Instant startsAt,
            @NotNull Instant endsAt,
            @Size(max = 200) String location,
            @Min(1) @Max(100000) Integer capacity,
            Long communityId) {
    }

    /** Hepsi opsiyonel. capacity = 0 sinirsiz yapar. */
    public record UpdateEventRequest(
            @Size(min = 3, max = 150) String title,
            @Size(max = 2000) String description,
            Instant startsAt,
            Instant endsAt,
            @Size(max = 200) String location,
            @Min(0) @Max(100000) Integer capacity) {
    }

    /** myRsvp: GOING | INTERESTED | null. interestedCount yalnizca detayda doludur. */
    public record EventView(Long id, String title, String description, Instant startsAt, Instant endsAt,
                            String location, String coverUrl, Integer capacity, int goingCount,
                            Long interestedCount, Long communityId, String communityName, Long createdBy,
                            String organizerName, UserEvent.Status status, EventRsvp.Status myRsvp,
                            boolean canManage, Instant createdAt, boolean registrationClosed) {
    }

    public record RsvpRequest(@NotNull EventRsvp.Status status) {
    }

    public record RsvpResult(EventRsvp.Status myRsvp, int goingCount, Integer capacity) {
    }

    public record AttendeeView(Long userId, String displayName, String avatarUrl, EventRsvp.Status status,
                               Instant rsvpAt) {
    }

    /**
     * source: USER | OFFICIAL. Resmi kayitlarda saat yok (startsAt null), url kaynak sayfadir ve date haberin
     * YAYIN tarihidir (kaynak sitede ayri etkinlik tarihi alani yok). USER'da date takvim gunudur; onceki aydan
     * suren etkinlikte ayin ilk gunune kisitlanir. myRsvp/goingCount/interestedCount/capacity/status/communityName
     * yalnizca USER ogelerinde dolu, OFFICIAL'da null.
     */
    public record CalendarItem(String source, Long id, String title, LocalDate date, Instant startsAt,
                               Instant endsAt, String location, String url, String imageUrl, Long communityId,
                               EventRsvp.Status myRsvp, Integer goingCount, Long interestedCount, Integer capacity,
                               UserEvent.Status status, String communityName) {
    }

    public record AttendeeAvatar(Long userId, String displayName, String avatarUrl) {
    }

    /** Herkese acik onizleme: sayilar + gizlilik ayari izin veren en cok 8 avatar. */
    public record AttendeePreview(long goingCount, long interestedCount, List<AttendeeAvatar> avatars) {
    }

    public record CheckinCode(String code, String qrPayload, Instant expiresAt, int validForSeconds) {
    }

    public record CheckinRequest(@NotBlank @Size(max = 200) String code) {
    }

    /** Kullanicinin kendi yoklama durumu. present null ise kayit yok. */
    public record MyAttendance(Long eventId, EventRsvp.Status rsvpStatus, Boolean present, Method method,
                               Instant markedAt, boolean checkInOpen) {
    }

    public record AttendanceRow(Long userId, String displayName, String department, EventRsvp.Status rsvpStatus,
                                boolean present, Method method, Long markedBy, String markedByName,
                                Instant markedAt) {
    }

    public record MarkRequest(@NotNull Boolean present) {
    }

    public record BulkEntry(@NotNull Long userId, @NotNull Boolean present) {
    }

    public record BulkRequest(@NotEmpty @Size(max = 500) List<@Valid BulkEntry> entries) {
    }

    public record BulkResult(int updated) {
    }
}
