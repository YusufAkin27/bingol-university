package edu.bingol.backend.notification.campaign;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.notification.campaign.CampaignDtos.Audience;
import edu.bingol.backend.notification.campaign.CampaignDtos.CampaignPage;
import edu.bingol.backend.notification.campaign.CampaignDtos.CampaignView;
import edu.bingol.backend.notification.campaign.CampaignDtos.Content;
import edu.bingol.backend.notification.campaign.CampaignDtos.CreateCampaignRequest;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserRepository.UserLang;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

/**
 * Yonetici push kampanyalari: olusturma -> zamanlayici (10 sn) -> kitleyi coz -> dil bazli toplu gonderim.
 * Gonderim istek ipliginde degil zamanlayicida yapilir; istek aninda 202 doner.
 */
@Service
public class CampaignService {

    private static final Logger log = LoggerFactory.getLogger(CampaignService.class);
    private static final Duration MAX_SCHEDULE_AHEAD = Duration.ofDays(30);
    private static final int MAX_USER_IDS = 500;

    private static final Set<NotificationType> ALLOWED_TYPES =
            Set.of(NotificationType.ANNOUNCEMENT, NotificationType.NEWS, NotificationType.EVENT, NotificationType.SYSTEM);

    private final PushCampaignRepository campaigns;
    private final UserRepository users;
    private final NotificationService notifications;

    public CampaignService(PushCampaignRepository campaigns, UserRepository users, NotificationService notifications) {
        this.campaigns = campaigns;
        this.users = users;
        this.notifications = notifications;
    }

    public PushCampaign create(Long adminId, CreateCampaignRequest r) {
        NotificationType type = r.type() == null ? NotificationType.ANNOUNCEMENT : r.type();
        if (!ALLOWED_TYPES.contains(type)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz bildirim türü.");
        }
        String audienceValue = normalizeAudienceValue(r.audience());
        if (resolve(r.audience().type(), audienceValue, adminId).isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "NO_RECIPIENTS", "Bu hedef kitlede alıcı bulunamadı.");
        }
        Instant now = Instant.now();
        Instant when = r.scheduledAt() == null || r.scheduledAt().isBefore(now) ? now : r.scheduledAt();
        if (when.isAfter(now.plus(MAX_SCHEDULE_AHEAD))) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "En fazla 30 gün sonrası zamanlanabilir.");
        }

        PushCampaign c = new PushCampaign();
        c.setCreatedBy(adminId);
        c.setType(type);
        c.setAudienceType(r.audience().type());
        c.setAudienceValue(audienceValue);
        c.setTitleTr(r.tr().title().trim());
        c.setBodyTr(r.tr().body().trim());
        if (r.en() != null) {
            c.setTitleEn(r.en().title().trim());
            c.setBodyEn(r.en().body().trim());
        }
        if (r.ar() != null) {
            c.setTitleAr(r.ar().title().trim());
            c.setBodyAr(r.ar().body().trim());
        }
        if (r.target() != null) {
            validateTarget(r.target());
            c.setTargetType(r.target().type());
            c.setTargetValue(blankToNull(r.target().value()));
        }
        c.setScheduledAt(when);
        return campaigns.save(c);
    }

    /** Gondermeden once kitle buyuklugunu gosterir ("1.240 kisiye gidecek"). */
    public int count(Long adminId, Audience audience) {
        return resolve(audience.type(), normalizeAudienceValue(audience), adminId).size();
    }

    public CampaignPage list(Long cursor, int size) {
        int s = CursorPage.clampSize(size);
        CursorPage<CampaignView> page = CursorPage.of(campaigns.page(cursor, PageRequest.of(0, s + 1)), s,
                PushCampaign::getId, CampaignView::of);
        return new CampaignPage(page.items(), page.nextCursor());
    }

    public PushCampaign get(Long id) {
        return campaigns.findById(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "CAMPAIGN_NOT_FOUND", "Kampanya bulunamadı."));
    }

    public void cancel(Long id) {
        get(id);
        if (campaigns.cancelIfScheduled(id) == 0) {
            throw new ApiException(HttpStatus.CONFLICT, "CAMPAIGN_NOT_CANCELLABLE",
                    "Yalnızca bekleyen kampanyalar iptal edilebilir.");
        }
    }

    // --- zamanlayici ---

    /** Zamani gelen kampanyalari sirayla gonderir. Birden fazla sunucuda guvenlidir (claimNext). */
    @Scheduled(fixedDelayString = "${app.push.poll-ms:10000}")
    public void dispatchDue() {
        for (int i = 0; i < 20; i++) { // bir turda en fazla 20 kampanya
            Long id = campaigns.claimNext().orElse(null);
            if (id == null) {
                return;
            }
            dispatch(id);
        }
    }

    void dispatch(Long id) {
        PushCampaign c = campaigns.findById(id).orElse(null);
        if (c == null) {
            return;
        }
        try {
            List<UserLang> recipients = resolve(c.getAudienceType(), c.getAudienceValue(), c.getCreatedBy());
            Map<String, List<Long>> byLang = new HashMap<>();
            for (UserLang u : recipients) {
                byLang.computeIfAbsent(Lang.of(u.getLanguage()).code(), k -> new ArrayList<>()).add(u.getId());
            }
            Map<String, String> data = new HashMap<>();
            if (c.getTargetType() != PushCampaign.TargetType.NONE) {
                data.put("target", c.getTargetType().name());
                if (c.getTargetValue() != null) {
                    data.put("value", c.getTargetValue());
                }
            }
            data.put("campaignId", String.valueOf(c.getId()));

            int sent = 0;
            for (Map.Entry<String, List<Long>> e : byLang.entrySet()) {
                Content text = contentFor(c, Lang.of(e.getKey()));
                sent += notifications.sendBulk(e.getValue(), c.getType(), text.title(), text.body(), data);
            }
            c.setStatus(PushCampaign.Status.SENT);
            c.setRecipientCount(sent);
            c.setFinishedAt(Instant.now());
            log.info("Push kampanyasi {} gonderildi: {} kisi", id, sent);
        } catch (RuntimeException e) {
            log.error("Push kampanyasi {} basarisiz", id, e);
            c.setStatus(PushCampaign.Status.FAILED);
            c.setError(truncate(e.toString(), 500));
            c.setFinishedAt(Instant.now());
        }
        campaigns.save(c);
    }

    // --- yardimcilar ---

    private Content contentFor(PushCampaign c, Lang lang) {
        return switch (lang) {
            case EN -> c.getTitleEn() != null ? new Content(c.getTitleEn(), c.getBodyEn()) : tr(c);
            case AR -> c.getTitleAr() != null ? new Content(c.getTitleAr(), c.getBodyAr()) : tr(c);
            case TR -> tr(c);
        };
    }

    private static Content tr(PushCampaign c) {
        return new Content(c.getTitleTr(), c.getBodyTr());
    }

    /** Kitleyi (aktif ve dogrulanmis kullanicilar) cozer. */
    List<UserLang> resolve(PushCampaign.AudienceType type, String value, Long adminId) {
        return switch (type) {
            case ALL -> users.audienceAll();
            case DEPARTMENT -> users.audienceDepartment(value);
            case CLASS_YEAR -> users.audienceClassYear(Short.parseShort(value));
            case USERS -> users.audienceIds(parseIds(value));
            case ADMINS -> users.audienceAdmins();
            case SELF -> users.audienceIds(List.of(adminId));
        };
    }

    /** Kitle degerini dogrular ve normallestirir; hatada 400 INVALID_AUDIENCE. */
    static String normalizeAudienceValue(Audience a) {
        String v = a.value() == null ? "" : a.value().trim();
        switch (a.type()) {
            case ALL, ADMINS, SELF -> {
                return null;
            }
            case DEPARTMENT -> {
                if (v.isEmpty() || v.length() > 120) {
                    throw invalidAudience();
                }
                return v;
            }
            case CLASS_YEAR -> {
                try {
                    short y = Short.parseShort(v);
                    if (y < 0 || y > 8) {
                        throw invalidAudience();
                    }
                    return String.valueOf(y);
                } catch (NumberFormatException e) {
                    throw invalidAudience();
                }
            }
            case USERS -> {
                Set<Long> ids = parseIds(v);
                if (ids.isEmpty() || ids.size() > MAX_USER_IDS) {
                    throw invalidAudience();
                }
                return String.join(",", ids.stream().map(String::valueOf).toList());
            }
            default -> throw invalidAudience();
        }
    }

    private static Set<Long> parseIds(String csv) {
        Set<Long> ids = new LinkedHashSet<>();
        if (csv == null || csv.isBlank()) {
            return ids;
        }
        for (String part : csv.split(",")) {
            try {
                ids.add(Long.parseLong(part.trim()));
            } catch (NumberFormatException e) {
                throw invalidAudience();
            }
        }
        return ids;
    }

    private static void validateTarget(CampaignDtos.Target t) {
        String v = blankToNull(t.value());
        switch (t.type()) {
            case NONE -> { }
            case URL -> {
                // Yalnizca https baglantilari (javascript:, intent: vb. engellenir)
                if (v == null || !v.startsWith("https://")) {
                    throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "URL https:// ile başlamalıdır.");
                }
            }
            default -> {
                if (v == null || !v.matches("\\d{1,18}")) {
                    throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Hedef id sayı olmalıdır.");
                }
            }
        }
    }

    private static ApiException invalidAudience() {
        return new ApiException(HttpStatus.BAD_REQUEST, "INVALID_AUDIENCE", "Hedef kitle geçersiz.");
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }

    private static String truncate(String s, int max) {
        return s.length() <= max ? s : s.substring(0, max);
    }
}
