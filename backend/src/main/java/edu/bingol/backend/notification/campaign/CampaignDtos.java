package edu.bingol.backend.notification.campaign;

import edu.bingol.backend.notification.NotificationType;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;

public final class CampaignDtos {

    private CampaignDtos() {}

    /**
     * value: DEPARTMENT/FACULTY=ad, CLASS_YEAR=1..8, LANGUAGE=tr|en|ar, USERS="12,15,40" (en cok 500),
     * EMAILS=satir/virgul ayrili e-posta veya kullanici no listesi (en cok 500; olusturmada USERS'a cevrilir);
     * ALL/ADMINS/SELF icin bos.
     */
    public record Audience(@NotNull PushCampaign.AudienceType type, @Size(max = 20000) String value) {}

    /** FCM bildirim govdesi sinirlarina uygun uzunluklar. */
    public record Content(@NotBlank @Size(max = 100) String title, @NotBlank @Size(max = 300) String body) {}

    /** Bildirime dokunulunca acilacak hedef; mobil data["target"] / data["value"] ile yonlendirir. */
    public record Target(@NotNull PushCampaign.TargetType type, @Size(max = 500) String value) {}

    /**
     * tr zorunlu; en/ar yoksa o dildeki kullanicilara tr metin gider. type: ANNOUNCEMENT (varsayilan), NEWS, EVENT,
     * SYSTEM (kullanici tercihlerini gecer; yalnizca onemli duyurular icin). scheduledAt bos/gecmis ise hemen gonderilir.
     */
    public record CreateCampaignRequest(NotificationType type, @NotNull @Valid Audience audience,
                                        @NotNull @Valid Content tr, @Valid Content en, @Valid Content ar,
                                        @Valid Target target, Instant scheduledAt) {}

    /** Test ve hizli gonderim: kitle sunucuda belirlenir (yoneticinin kendisi / secilen kullanici), zamanlama yok. */
    public record SendRequest(NotificationType type, @NotNull @Valid Content tr, @Valid Content en, @Valid Content ar,
                              @Valid Target target) {}

    public record AudienceCount(int count) {}

    /** type: bildirim turu (tercih suzmesini onizlemek icin; bos = ANNOUNCEMENT). */
    public record PreviewRequest(@NotNull @Valid Audience audience, NotificationType type) {}

    public record SamplePerson(Long id, String displayName, String email, String language) {}

    /**
     * count: tekil kitle; willReceive: bildirim tercihi kapali olmayanlar; optedOut = count - willReceive.
     * notFound: listede bulunamayan girdiler (en cok 50); sample: ilk 10 kisi.
     */
    public record AudiencePreview(int count, int willReceive, int optedOut, java.util.Map<String, Integer> byLanguage,
                                  List<SamplePerson> sample, List<String> notFound) {}

    public record CampaignView(Long id, Long createdBy, NotificationType type, Audience audience, Content tr,
                               Content en, Content ar, Target target, PushCampaign.Status status, String scheduledAt,
                               String startedAt, String finishedAt, Integer recipientCount, Integer audienceSize,
                               Integer skippedCount, PushCampaign.Source source, String error, String createdAt) {
        static CampaignView of(PushCampaign c) {
            return new CampaignView(c.getId(), c.getCreatedBy(), c.getType(),
                    new Audience(c.getAudienceType(), c.getAudienceValue()),
                    new Content(c.getTitleTr(), c.getBodyTr()),
                    c.getTitleEn() == null ? null : new Content(c.getTitleEn(), c.getBodyEn()),
                    c.getTitleAr() == null ? null : new Content(c.getTitleAr(), c.getBodyAr()),
                    new Target(c.getTargetType(), c.getTargetValue()), c.getStatus(), c.getScheduledAt().toString(),
                    c.getStartedAt() == null ? null : c.getStartedAt().toString(),
                    c.getFinishedAt() == null ? null : c.getFinishedAt().toString(), c.getRecipientCount(),
                    c.getAudienceSize(),
                    c.getAudienceSize() == null || c.getRecipientCount() == null ? null
                            : Math.max(0, c.getAudienceSize() - c.getRecipientCount()),
                    c.getSource(), c.getError(), c.getCreatedAt().toString());
        }
    }

    public record CampaignPage(List<CampaignView> items, Long nextCursor) {}
}
