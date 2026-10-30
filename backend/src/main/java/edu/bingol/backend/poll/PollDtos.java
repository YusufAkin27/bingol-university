package edu.bingol.backend.poll;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;

/** Anket API sozlesmesi (docs/API_CONTRACTS_V2.md "Anket ve oylama"). Entity'ler API'ye donmez. */
public final class PollDtos {

    private PollDtos() {}

    public record OptionView(Long id, String text, int position) {}

    public record CreatedBy(Long id, String displayName) {}

    /** Kullanicinin kendi oyu: RATING'de rating 1..5, RANKED'de optionIds tercih sirasindadir. */
    public record MyVote(List<Long> optionIds, Integer rating, OffsetDateTime votedAt) {}

    /** score yalniz RANKED'de (Borda puani). */
    public record Result(Long optionId, int count, double percent, Integer score) {}

    public record Turnout(int voted, Integer eligible, Double percent) {}

    /** Hedef kitle: bos alan kisitsiz; hepsi bos = herkes. */
    public record Audience(String faculty, String department, String grade) {}

    public record PollView(Long id, String title, String description, String type, String scope, Long communityId,
                           String communityName, LocalDate menuDate, List<String> menuItems, List<OptionView> options,
                           int maxChoices, boolean anonymous, boolean allowChangeVote, String showResults,
                           @JsonProperty("notify") boolean notifyUsers,
                           OffsetDateTime opensAt, OffsetDateTime closesAt, Audience audience, String status, String state,
                           OffsetDateTime createdAt, OffsetDateTime closedAt, CreatedBy createdBy, boolean canVote,
                           String voteBlockedReason, boolean canManage, MyVote myVote, boolean resultsVisible,
                           List<Result> results, Integer totalVotes, Turnout turnout, Double average, Integer ratingCount) {}

    /** totalCount = bu kapsamdaki toplam kayit; openCount = sekme rozeti icin acik anket sayisi (ikisi de sayfadan bagimsiz). */
    public record PollPage(List<PollView> items, Long nextCursor, Long totalCount, Long openCount) {}

    /** Olusturma: tum alanlar metin/null; dogrulama PollService'te (tutarli POLL_INVALID mesajlari). */
    public record CreateRequest(String title, String description, String type, String scope, Long communityId,
                                LocalDate menuDate, List<String> options, Integer maxChoices, Boolean anonymous,
                                Boolean allowChangeVote, String showResults, @JsonProperty("notify") Boolean notifyUsers, String opensAt,
                                String closesAt, Audience audience, Boolean draft) {}

    /** Guncelleme: null = degismez. closesAt "" (bos metin) kapanisi kaldirir. */
    public record UpdateRequest(String title, String description, String type, List<String> options, Integer maxChoices,
                                Boolean anonymous, Boolean allowChangeVote, String showResults, @JsonProperty("notify") Boolean notifyUsers,
                                String opensAt, String closesAt, Audience audience, Boolean draft) {}

    public record VoteRequest(List<Long> optionIds, Integer rating) {}

    public record BulkRequest(List<Long> ids, String action) {}

    public record BulkResult(int done, int skipped) {}

    public record AdminPollRow(Long id, String title, String type, String scope, Long communityId, String status,
                               String state, boolean anonymous, int totalVotes, OffsetDateTime opensAt,
                               OffsetDateTime closesAt, OffsetDateTime createdAt, Long createdBy) {}

    public record AdminPollPage(List<AdminPollRow> items, int page, int size, long total) {}

    public record AdminStats(long total, long open, long closed, long draft, long cancelled, long totalVotes,
                             java.util.Map<String, Long> byScope, Double avgTurnoutPercent) {}
}
