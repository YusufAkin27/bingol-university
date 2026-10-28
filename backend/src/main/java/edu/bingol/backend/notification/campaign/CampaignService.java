package edu.bingol.backend.notification.campaign;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationPrefRepository;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.notification.campaign.AudienceResolver.Member;
import edu.bingol.backend.notification.campaign.AudienceResolver.Resolved;
import edu.bingol.backend.notification.campaign.CampaignDtos.Audience;
import edu.bingol.backend.notification.campaign.CampaignDtos.AudiencePreview;
import edu.bingol.backend.notification.campaign.CampaignDtos.SamplePerson;
import edu.bingol.backend.notification.campaign.CampaignDtos.SendRequest;
import edu.bingol.backend.notification.campaign.CampaignDtos.CampaignPage;
import edu.bingol.backend.notification.campaign.CampaignDtos.CampaignView;
import edu.bingol.backend.notification.campaign.CampaignDtos.Content;
import edu.bingol.backend.notification.campaign.CampaignDtos.CreateCampaignRequest;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
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

    /** Ayni icerik+kitle bu surede tekrar olusturulamaz (cift tiklama / yeniden deneme korumasi). */
    static final Duration DUPLICATE_WINDOW = Duration.ofMinutes(2);

    private final PushCampaignRepository campaigns;
    private final AudienceResolver resolver;
    private final NotificationPrefRepository prefs;
    private final NotificationService notifications;

    public CampaignService(PushCampaignRepository campaigns, AudienceResolver resolver,
                           NotificationPrefRepository prefs, NotificationService notifications) {
        this.campaigns = campaigns;
        this.resolver = resolver;
        this.prefs = prefs;
        this.notifications = notifications;
    }

    public PushCampaign create(Long adminId, CreateCampaignRequest r) {
        return create(adminId, r, PushCampaign.Source.CAMPAIGN);
    }

    PushCampaign create(Long adminId, CreateCampaignRequest r, PushCampaign.Source source) {
        NotificationType type = r.type() == null ? NotificationType.ANNOUNCEMENT : r.type();
        if (!ALLOWED_TYPES.contains(type)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz bildirim türü.");
        }
        PushCampaign.AudienceType audienceType = r.audience().type();
        String audienceValue = normalizeAudienceValue(r.audience());
        Resolved resolved = resolver.resolve(audienceType, audienceValue, adminId);
        if (resolved.members().isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "NO_RECIPIENTS", "Bu hedef kitlede alıcı bulunamadı.");
        }
        if (audienceType == PushCampaign.AudienceType.EMAILS) {
            // Liste olusturma aninda kimliklere sabitlenir: sonradan e-posta degisse de ayni kisiler hedeflenir
            audienceType = PushCampaign.AudienceType.USERS;
            audienceValue = resolved.members().stream().map(m -> String.valueOf(m.id())).collect(Collectors.joining(","));
        }
        Instant now = Instant.now();
        Instant when = r.scheduledAt() == null || r.scheduledAt().isBefore(now) ? now : r.scheduledAt();
        if (when.isAfter(now.plus(MAX_SCHEDULE_AHEAD))) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "En fazla 30 gün sonrası zamanlanabilir.");
        }
        String titleTr = r.tr().title().trim();
        String bodyTr = r.tr().body().trim();
        if (source == PushCampaign.Source.CAMPAIGN && campaigns.countRecentDuplicates(adminId, titleTr, bodyTr,
                audienceType, audienceValue == null ? "" : audienceValue, now.minus(DUPLICATE_WINDOW)) > 0) {
            throw new ApiException(HttpStatus.CONFLICT, "CAMPAIGN_DUPLICATE",
                    "Aynı içerik ve kitleyle bir kampanya az önce oluşturuldu.");
        }

        PushCampaign c = new PushCampaign();
        c.setCreatedBy(adminId);
        c.setSource(source);
        c.setType(type);
        c.setAudienceType(audienceType);
        c.setAudienceValue(audienceValue);
        c.setTitleTr(titleTr);
        c.setBodyTr(bodyTr);
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

    /** Test gonderimi: icerik yalnizca yoneticinin kendisine, hemen gider (kampanya listesinde TEST olarak gorunur). */
    public PushCampaign createTest(Long adminId, SendRequest r) {
        return create(adminId, toRequest(r, new Audience(PushCampaign.AudienceType.SELF, null)), PushCampaign.Source.TEST);
    }

    /** Hizli gonderim: tek kullaniciya hemen (kullanici detay sayfasi). */
    public PushCampaign createQuick(Long adminId, Long userId, SendRequest r) {
        return create(adminId, toRequest(r, new Audience(PushCampaign.AudienceType.USERS, String.valueOf(userId))),
                PushCampaign.Source.QUICK);
    }

    private static CreateCampaignRequest toRequest(SendRequest r, Audience a) {
        return new CreateCampaignRequest(r.type(), a, r.tr(), r.en(), r.ar(), r.target(), null);
    }

    /**
     * Kitle onizleme: tekil sayi, tercih nedeniyle atlanacaklar, dil kirilimi, ilk 10 kisi, bulunamayan girdiler.
     * SYSTEM turunde tercih suzmesi yoktur (optedOut hep 0).
     */
    public AudiencePreview preview(Long adminId, Audience audience, NotificationType type) {
        NotificationType t = type == null ? NotificationType.ANNOUNCEMENT : type;
        Resolved r = resolver.resolve(audience.type(), normalizeForPreview(audience), adminId);
        List<Member> members = r.members();
        List<Long> ids = members.stream().map(Member::id).toList();
        int willReceive = 0;
        for (int i = 0; i < ids.size(); i += 500) {
            willReceive += prefs.allowing(ids.subList(i, Math.min(i + 500, ids.size())), t.prefColumn()).size();
        }
        Map<String, Integer> byLang = new LinkedHashMap<>();
        for (String code : new String[] {"tr", "en", "ar"}) {
            byLang.put(code, 0);
        }
        for (Member m : members) {
            byLang.merge(Lang.of(m.language()).code(), 1, Integer::sum);
        }
        List<SamplePerson> sample = members.stream().limit(10)
                .map(m -> new SamplePerson(m.id(), m.displayName(), m.email(), m.language())).toList();
        return new AudiencePreview(members.size(), willReceive, members.size() - willReceive, byLang, sample,
                r.notFound());
    }

    private static String normalizeForPreview(Audience a) {
        // EMAILS ham liste olarak cozumleyiciye gider; digerleri dogrulanir
        if (a.type() == PushCampaign.AudienceType.EMAILS) {
            normalizeAudienceValue(a);
            return a.value();
        }
        return normalizeAudienceValue(a);
    }

    /** Gondermeden once kitle buyuklugunu gosterir ("1.240 kisiye gidecek"). */
    public int count(Long adminId, Audience audience) {
        return resolver.resolve(audience.type(), normalizeForPreview(audience), adminId).members().size();
    }

    public CampaignPage list(Long cursor, int size) {
        return list(cursor, size, null);
    }

    public CampaignPage list(Long cursor, int size, PushCampaign.Status status) {
        int s = CursorPage.clampSize(size);
        List<PushCampaign> rows = status == null ? campaigns.page(cursor, PageRequest.of(0, s + 1))
                : campaigns.pageByStatus(status, cursor, PageRequest.of(0, s + 1));
        CursorPage<CampaignView> page = CursorPage.of(rows, s,
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

    public void pause(Long id) {
        get(id);
        if (campaigns.pauseIfScheduled(id) == 0) {
            throw new ApiException(HttpStatus.CONFLICT, "CAMPAIGN_NOT_PAUSABLE",
                    "Yalnızca bekleyen kampanyalar duraklatılabilir.");
        }
    }

    /** Duraklatilmis kampanyayi surdurur; zamani gecmisse bir sonraki turda (10 sn) gonderilir. */
    public void resume(Long id) {
        get(id);
        if (campaigns.resumeIfPaused(id) == 0) {
            throw new ApiException(HttpStatus.CONFLICT, "CAMPAIGN_NOT_RESUMABLE",
                    "Yalnızca duraklatılmış kampanyalar sürdürülebilir.");
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
            // Cozumleyici kimlige gore tekillestirir; gonderim aninda aktif/dogrulanmis olmayan (askida, silinmis) elenir
            List<Member> recipients =
                    resolver.resolve(c.getAudienceType(), c.getAudienceValue(), c.getCreatedBy()).members();
            Map<String, List<Long>> byLang = new HashMap<>();
            for (Member u : recipients) {
                byLang.computeIfAbsent(Lang.of(u.language()).code(), k -> new ArrayList<>()).add(u.id());
            }
            c.setAudienceSize(recipients.size());
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
            case FACULTY -> {
                if (v.isEmpty() || v.length() > 120) {
                    throw invalidAudience();
                }
                return v;
            }
            case LANGUAGE -> {
                String l = v.toLowerCase(java.util.Locale.ROOT);
                if (!l.equals("tr") && !l.equals("en") && !l.equals("ar")) {
                    throw invalidAudience();
                }
                return l;
            }
            case EMAILS -> {
                AudienceResolver.Tokens t = AudienceResolver.parseEmails(v);
                if (t.emails().isEmpty() && t.ids().isEmpty()) {
                    throw invalidAudience();
                }
                return v;
            }
            case USERS -> {
                Set<Long> ids = AudienceResolver.parseIds(v);
                if (ids.isEmpty() || ids.size() > MAX_USER_IDS) {
                    throw invalidAudience();
                }
                return ids.stream().sorted().map(String::valueOf).collect(Collectors.joining(","));
            }
            default -> throw invalidAudience();
        }
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

    static ApiException invalidAudience() {
        return new ApiException(HttpStatus.BAD_REQUEST, "INVALID_AUDIENCE", "Hedef kitle geçersiz.");
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }

    private static String truncate(String s, int max) {
        return s.length() <= max ? s : s.substring(0, max);
    }
}
