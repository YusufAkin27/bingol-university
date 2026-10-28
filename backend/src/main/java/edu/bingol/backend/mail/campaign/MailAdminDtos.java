package edu.bingol.backend.mail.campaign;

import edu.bingol.backend.user.Role;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;
import java.util.Map;

/** Yonetici mail sablonlari ve kampanyalari istek/yanit sekilleri (docs/ADMIN_API.md). */
public final class MailAdminDtos {

    private MailAdminDtos() {}

    // ---------- sablon ----------

    /** Tek dil icerigi. html bos ise o dil tanimsizdir (alicilar tr'ye duser). text bos ise html'den uretilir. */
    public record LangContentRequest(@Size(max = 200) String subject, @Size(max = 100000) String html,
                                     @Size(max = 100000) String text) {}

    public record TemplateRequest(@NotBlank @Size(max = 120) String name, @Size(max = 500) String description,
                                  @NotNull @Valid LangContentRequest tr, @Valid LangContentRequest en,
                                  @Valid LangContentRequest ar) {}

    /** Kaydedilmemis icerigi onizleme: lang istenen dil; content o dilin (veya tr'nin) icerigi. */
    public record DraftPreviewRequest(String lang, @NotNull @Valid LangContentRequest content) {}

    public record StoredPreviewRequest(String lang, Integer version) {}

    public record TestSendRequest(String lang) {}

    public record ContentView(String subject, String html, String text) {}

    public record TemplateRow(Long id, String name, String description, String category,
                              MailCustomTemplate.Status status, int version, List<String> languages,
                              String updatedAt) {}

    public record TemplateView(Long id, String name, String description, String category,
                               MailCustomTemplate.Status status, int version, ContentView tr, ContentView en,
                               ContentView ar, List<String> languages, List<String> variablesUsed, Long createdBy,
                               String createdAt, String updatedAt) {}

    public record VersionRow(int version, Long createdBy, String createdAt) {}

    public record PreviewView(String lang, String usedLang, boolean fallback, String subject, String html,
                              String text, Map<String, String> sampleVariables) {}

    public record TestSendView(boolean queued, String lang, String usedLang, String to) {}

    public record VariableInfo(String name, String placeholder, String description, boolean automatic) {}

    public record VariablesView(List<VariableInfo> variables, int maxHtmlLength, int maxSubjectLength) {}

    // ---------- kampanya ----------

    /** FILTER hedefi: tum alanlar istege bagli, en az biri dolu olmali; alanlar VE ile birlesir. */
    public record Filter(@Size(max = 120) String faculty, @Size(max = 120) String department, Short classYear,
                         Role role, @Size(max = 2) String language, Long communityId) {}

    /**
     * type: ALL (tum dogrulanmis kullanicilar), FILTER (filter), USERS (userIds, en cok 2000), EMAILS (emails, en cok
     * 2000; yalnizca KAYITLI kullanicilarla eslesir, kayitsiz adres yok sayilir ve sayilir).
     */
    public record AudienceRequest(@NotNull MailCampaign.AudienceType type, @Valid Filter filter,
                                  @Size(max = 2000) List<Long> userIds, @Size(max = 2000) List<@Size(max = 254) String> emails) {}

    public record AudiencePreviewRequest(@NotNull @Valid AudienceRequest audience, Long templateId) {}

    public record CampaignRequest(@NotBlank @Size(max = 120) String name, @NotNull Long templateId,
                                  @NotNull @Valid AudienceRequest audience, Instant scheduledAt,
                                  @Size(max = 64) String requestKey) {}

    public record ScheduleRequest(Instant scheduledAt) {}

    public record AudienceView(MailCampaign.AudienceType type, Filter filter, Integer userCount, int unmatched) {}

    public record Counters(int target, int pending, int queued, int skipped, int failed, int cancelled,
                           Map<String, Integer> skippedByReason, Map<String, Integer> languages,
                           int languageFallback, int progressPercent) {}

    public record CampaignView(Long id, String name, Long templateId, String templateName, int templateVersion,
                               MailCampaign.Status status, AudienceView audience, String scheduledAt,
                               String resolvedAt, String startedAt, String finishedAt, Long createdBy,
                               String createdAt, String updatedAt, String error, Counters counters) {}

    public record AudiencePreview(int total, int willSend, int skipped, Map<String, Integer> skippedByReason,
                                  int unmatched, Map<String, Integer> languages, int languageFallback) {}

    public record RecipientRow(Long userId, MailCampaignRecipient.Status status, String skipReason,
                               String errorCode, String lang, boolean langFallback, String email, String updatedAt) {}
}
