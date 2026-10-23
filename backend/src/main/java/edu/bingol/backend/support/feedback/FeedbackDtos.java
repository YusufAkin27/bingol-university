package edu.bingol.backend.support.feedback;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.List;

/** Geri bildirim ve oneri panosu istek/yanit tipleri. */
public final class FeedbackDtos {

    private FeedbackDtos() {}

    public record CreateFeedbackRequest(@NotNull Feedback.Category category,
                                        @NotBlank @Size(max = 120) String subject,
                                        @NotBlank @Size(max = 2000) String message,
                                        @Size(max = 32) String appVersion,
                                        @Pattern(regexp = "ANDROID|IOS|WEB") String platform) {}

    /** Kullanicinin kendi geri bildirimi (yonetici yaniti dahil). */
    public record FeedbackView(Long id, Feedback.Category category, String subject, String message,
                               Feedback.Status status, String adminResponse, String respondedAt,
                               boolean publicVisible, int voteCount, String createdAt) {
        public static FeedbackView of(Feedback f) {
            return new FeedbackView(f.getId(), f.getCategory(), f.getSubject(), f.getMessage(), f.getStatus(),
                    f.getAdminResponse(), f.getRespondedAt() == null ? null : f.getRespondedAt().toString(),
                    f.isPublicVisible(), f.getVoteCount(), f.getCreatedAt().toString());
        }
    }

    public record FeedbackPage(List<FeedbackView> items, Long nextCursor) {}

    /** Herkese acik panodaki oneri; yazar bilgisi icermez. */
    public record SuggestionView(Long id, String subject, String message, Feedback.Status status,
                                 String adminResponse, int voteCount, boolean votedByMe, String createdAt) {}

    public record SuggestionPage(List<SuggestionView> items, int page, int totalPages, long totalItems) {}

    public record AdminFeedbackView(Long id, Long userId, String userEmail, Feedback.Category category, String subject,
                                    String message, Feedback.Status status, String adminResponse, boolean publicVisible,
                                    int voteCount, String appVersion, String platform, String createdAt) {}

    public record AdminFeedbackPage(List<AdminFeedbackView> items, Long nextCursor) {}

    /** Verilmeyen (null) alanlar degismez. */
    public record UpdateFeedbackRequest(Feedback.Status status, @Size(max = 1000) String adminResponse,
                                        Boolean publicVisible) {}
}
