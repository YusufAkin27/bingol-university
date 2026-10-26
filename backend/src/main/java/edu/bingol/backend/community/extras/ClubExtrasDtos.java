package edu.bingol.backend.community.extras;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;

/** Kulup ekstralari (T15) istek/yanit kayitlari. */
public final class ClubExtrasDtos {

    private ClubExtrasDtos() {}

    // ---- duyuru ----
    public record AnnouncementRequest(@NotBlank @Size(max = 2000) String text) {}

    public record AnnouncementView(Long id, Long communityId, Long authorId, String authorName, String text,
                                   Instant createdAt) {}

    // ---- katilim sorulari ----
    public record QuestionView(Long id, String question) {}

    /** Sorular sirayla; bos liste formu kaldirir. En fazla 3 (servis denetler). */
    public record QuestionsRequest(@NotNull @Size(max = 10) List<@NotBlank @Size(max = 200) String> questions) {}

    public record AnswerInput(@NotNull Long questionId, @NotNull @Size(max = 500) String answer) {}

    /** Katilma istegi govdesi (opsiyonel): sorulu kulupte yanitlar. */
    public record JoinRequest(@Valid @Size(max = 10) List<AnswerInput> answers) {}

    public record AnswerView(Long questionId, String question, String answer, Instant answeredAt) {}

    // ---- sohbet odasi ----
    /** conversationId yalnizca oda aciksa dolu; joined: ben su an odanin uyesi miyim. */
    public record ChatRoomView(Long conversationId, boolean closed, boolean joined, long memberCount) {}

    public record ClosedRequest(@NotNull Boolean closed) {}

    // ---- istatistik ----
    public record ClubStats(long memberCount, long pendingRequests, long newMembersLast7Days, long postCount,
                            long postsLast7Days, long announcementCount, boolean chatActive, long chatMemberCount,
                            long chatMessagesLast7Days) {}
}
