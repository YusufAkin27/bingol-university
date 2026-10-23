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

    /** value: DEPARTMENT=bolum adi, CLASS_YEAR=1..8, USERS="12,15,40"; ALL/ADMINS/SELF icin bos. */
    public record Audience(@NotNull PushCampaign.AudienceType type, @Size(max = 2000) String value) {}

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

    public record AudienceCount(int count) {}

    public record CampaignView(Long id, Long createdBy, NotificationType type, Audience audience, Content tr,
                               Content en, Content ar, Target target, PushCampaign.Status status, String scheduledAt,
                               String startedAt, String finishedAt, Integer recipientCount, String error,
                               String createdAt) {
        static CampaignView of(PushCampaign c) {
            return new CampaignView(c.getId(), c.getCreatedBy(), c.getType(),
                    new Audience(c.getAudienceType(), c.getAudienceValue()),
                    new Content(c.getTitleTr(), c.getBodyTr()),
                    c.getTitleEn() == null ? null : new Content(c.getTitleEn(), c.getBodyEn()),
                    c.getTitleAr() == null ? null : new Content(c.getTitleAr(), c.getBodyAr()),
                    new Target(c.getTargetType(), c.getTargetValue()), c.getStatus(), c.getScheduledAt().toString(),
                    c.getStartedAt() == null ? null : c.getStartedAt().toString(),
                    c.getFinishedAt() == null ? null : c.getFinishedAt().toString(), c.getRecipientCount(),
                    c.getError(), c.getCreatedAt().toString());
        }
    }

    public record CampaignPage(List<CampaignView> items, Long nextCursor) {}
}
