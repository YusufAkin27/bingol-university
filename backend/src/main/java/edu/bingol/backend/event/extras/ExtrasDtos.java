package edu.bingol.backend.event.extras;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;

public final class ExtrasDtos {

    private ExtrasDtos() {}

    public record AddCoOrganizerRequest(@NotNull Long userId) {}

    public record CoOrganizerView(Long userId, String displayName, String avatarUrl, Instant addedAt) {}

    public record AnnouncementRequest(@NotBlank @Size(max = 80) String title, @NotBlank @Size(max = 500) String message) {}

    public record AnnouncementResult(int recipients, int remainingToday) {}

    /** count = eklenecek ek tekrar sayisi (ilk etkinlik haric); en fazla 11 (toplam 12). */
    public record SeriesRequest(@NotNull @Min(1) @Max(11) Integer count) {}

    public record SeriesView(Long seriesId, List<SeriesItem> events) {}

    public record SeriesItem(Long eventId, int seq, Instant startsAt, Instant endsAt, String status) {}

    public record FeedbackRequest(@NotNull @Min(1) @Max(5) Integer rating, @Size(max = 500) String comment) {}

    public record FeedbackView(int rating, String comment, Instant createdAt) {}

    /** distribution[0] = 1 puanli adet ... distribution[4] = 5 puanli adet. */
    public record FeedbackSummary(long count, double average, long[] distribution) {}

    public record Certificate(String code, String verifyPath, String holderName, Long eventId, String eventTitle,
                              Instant startsAt, Instant endsAt, String location, Instant issuedAt) {}

    /** Herkese acik dogrulama; gecersizse yalniz valid=false doner (kisi/etkinlik bilgisi sizmaz). */
    public record CertificateVerification(boolean valid, String holderName, String eventTitle, Instant startsAt,
                                          Instant endsAt, Instant issuedAt) {}
}
