package edu.bingol.backend.mail.campaign;

import edu.bingol.backend.admin.AdminDtos.PageResponse;
import edu.bingol.backend.admin.UserFilter;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.mail.campaign.MailAdminDtos.AudiencePreview;
import edu.bingol.backend.mail.campaign.MailAdminDtos.AudiencePreviewRequest;
import edu.bingol.backend.mail.campaign.MailAdminDtos.AudienceView;
import edu.bingol.backend.mail.campaign.MailAdminDtos.CampaignRequest;
import edu.bingol.backend.mail.campaign.MailAdminDtos.CampaignView;
import edu.bingol.backend.mail.campaign.MailAdminDtos.Counters;
import edu.bingol.backend.mail.campaign.MailAdminDtos.RecipientRow;
import edu.bingol.backend.mail.campaign.MailAudienceResolver.Normalized;
import edu.bingol.backend.mail.campaign.MailAudienceResolver.Plan;
import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Yonetici mail kampanyalari: kayit (TASLAK) -> zamanla -> (zamanlayici dagitir) -> bitti. Durum gecisleri kosullu
 * UPDATE ile yapilir: cift tiklama/yaris durumunda ikinci istek etkisizdir (idempotent). Alici satirlari
 * (campaign_id,user_id) benzersizdir; ayni kullaniciya ikinci e-posta yazilamaz.
 */
@Service
public class MailCampaignAdminService {

    static final Duration MAX_SCHEDULE_AHEAD = Duration.ofDays(90);
    private static final List<String> LANGS = List.of("tr", "en", "ar");

    private final MailCampaignRepository campaigns;
    private final MailCustomTemplateRepository templates;
    private final MailCustomTemplateVersionRepository versions;
    private final MailAudienceResolver resolver;
    private final NamedParameterJdbcTemplate jdbc;
    private final TransactionTemplate tx;
    private final MailCampaignSupport support;

    public MailCampaignAdminService(MailCampaignRepository campaigns, MailCustomTemplateRepository templates,
                                    MailCustomTemplateVersionRepository versions, MailAudienceResolver resolver,
                                    NamedParameterJdbcTemplate jdbc, TransactionTemplate tx,
                                    MailCampaignSupport support) {
        this.campaigns = campaigns;
        this.templates = templates;
        this.versions = versions;
        this.resolver = resolver;
        this.jdbc = jdbc;
        this.tx = tx;
        this.support = support;
    }

    // ---------- okuma ----------

    public PageResponse<CampaignView> list(MailCampaign.Status status, String q, int page, int size) {
        int s = Math.max(1, Math.min(size, 100));
        int p = Math.max(0, page);
        StringBuilder where = new StringBuilder(" WHERE 1 = 1");
        MapSqlParameterSource params = new MapSqlParameterSource();
        if (status != null) {
            where.append(" AND status = :status");
            params.addValue("status", status.name());
        }
        if (q != null && !q.isBlank()) {
            where.append(" AND LOWER(name) LIKE :q ESCAPE '\\'");
            params.addValue("q", "%" + UserFilter.escapeLike(q.trim().toLowerCase(Locale.ROOT)) + "%");
        }
        Long total = jdbc.queryForObject("SELECT COUNT(*) FROM mail_campaign" + where, params, Long.class);
        params.addValue("lim", s).addValue("off", (long) p * s);
        List<Long> ids = jdbc.queryForList("SELECT id FROM mail_campaign" + where
                + " ORDER BY id DESC LIMIT :lim OFFSET :off", params, Long.class);
        Map<Long, Counters> counters = counters(ids);
        List<CampaignView> rows = new ArrayList<>();
        for (MailCampaign c : campaigns.findAllById(ids).stream().sorted((a, b) -> Long.compare(b.getId(), a.getId())).toList()) {
            rows.add(view(c, counters.get(c.getId())));
        }
        return PageResponse.of(rows, p, s, total == null ? 0 : total);
    }

    public CampaignView get(Long id) {
        MailCampaign c = find(id);
        return view(c, counters(List.of(id)).get(id));
    }

    /** Hata/atlanan listesi: adres maskeli. status: FAILED/SKIPPED/QUEUED/PENDING/CANCELLED (bos = hepsi). */
    public PageResponse<RecipientRow> recipients(Long id, MailCampaignRecipient.Status status, int page, int size) {
        find(id);
        int s = Math.max(1, Math.min(size, 100));
        int p = Math.max(0, page);
        MapSqlParameterSource params = new MapSqlParameterSource("c", id);
        String where = " WHERE r.campaign_id = :c";
        if (status != null) {
            where += " AND r.status = :st";
            params.addValue("st", status.name());
        }
        Long total = jdbc.queryForObject("SELECT COUNT(*) FROM mail_campaign_recipient r" + where, params, Long.class);
        params.addValue("lim", s).addValue("off", (long) p * s);
        List<RecipientRow> rows = jdbc.query("SELECT r.user_id, r.status, r.skip_reason, r.error_code, r.lang, "
                + "r.lang_fallback, r.updated_at, u.email FROM mail_campaign_recipient r "
                + "LEFT JOIN app_user u ON u.id = r.user_id" + where + " ORDER BY r.id LIMIT :lim OFFSET :off", params,
                (rs, i) -> new RecipientRow(rs.getLong("user_id"), MailCampaignRecipient.Status.valueOf(rs.getString("status")),
                        rs.getString("skip_reason"), rs.getString("error_code"), rs.getString("lang"),
                        rs.getBoolean("lang_fallback"), support.mask(rs.getString("email")),
                        rs.getTimestamp("updated_at").toInstant().toString()));
        return PageResponse.of(rows, p, s, total == null ? 0 : total);
    }

    /** Hedef kitle onizleme: gonderilecek/atlanacak sayilar ve dil dagilimi (kayit yazmaz). */
    public AudiencePreview previewAudience(AudiencePreviewRequest r) {
        Normalized n = resolver.normalize(r.audience());
        MailCustomTemplateVersion v = null;
        if (r.templateId() != null) {
            MailCustomTemplate t = templates.findById(r.templateId()).orElseThrow(MailCampaignAdminService::templateNotFound);
            v = versions.findByTemplateIdAndVersion(t.getId(), t.getCurrentVersion()).orElse(null);
        }
        List<Plan> plans = resolver.plan(n.type(), n.value(), v);
        int willSend = 0;
        int fallback = 0;
        Map<String, Integer> skippedBy = new LinkedHashMap<>();
        Map<String, Integer> langs = emptyLangs();
        for (Plan p : plans) {
            if (p.status() == MailCampaignRecipient.Status.PENDING) {
                willSend++;
                langs.merge(p.lang(), 1, Integer::sum);
                if (p.fallback()) {
                    fallback++;
                }
            } else {
                skippedBy.merge(p.skipReason(), 1, Integer::sum);
            }
        }
        return new AudiencePreview(plans.size(), willSend, plans.size() - willSend, skippedBy, n.unmatched(), langs, fallback);
    }

    // ---------- yazma ----------

    public CampaignView create(Long adminId, CampaignRequest r) {
        if (r.requestKey() != null && !r.requestKey().isBlank()) {
            MailCampaign existing = campaigns.findByCreatedByAndRequestKey(adminId, r.requestKey().trim()).orElse(null);
            if (existing != null) {
                return get(existing.getId());
            }
        }
        MailCampaign c = new MailCampaign();
        c.setCreatedBy(adminId);
        c.setRequestKey(r.requestKey() == null || r.requestKey().isBlank() ? null : r.requestKey().trim());
        apply(c, r);
        try {
            c = campaigns.save(c);
        } catch (DataIntegrityViolationException e) {
            // Ayni istek anahtariyla es zamanli ikinci istek: mevcut kampanyayi dondur
            MailCampaign dup = c.getRequestKey() == null ? null
                    : campaigns.findByCreatedByAndRequestKey(adminId, c.getRequestKey()).orElse(null);
            if (dup == null) {
                throw e;
            }
            return get(dup.getId());
        }
        return get(c.getId());
    }

    /** Yalnizca TASLAK duzenlenebilir. */
    public CampaignView update(Long id, CampaignRequest r) {
        MailCampaign c = find(id);
        if (c.getStatus() != MailCampaign.Status.DRAFT) {
            throw notEditable();
        }
        apply(c, r);
        c.setUpdatedAt(Instant.now());
        // Yalniz hala TASLAK ise yaz (zamanlayici/baska yonetici ile yaris)
        if (jdbc.queryForObject("SELECT status FROM mail_campaign WHERE id = :id", Map.of("id", id), String.class)
                .equals("DRAFT")) {
            campaigns.save(c);
        } else {
            throw notEditable();
        }
        return get(id);
    }

    /**
     * TASLAK -> ZAMANLANDI (sablon yayinda olmali, hedefte en az bir alici). Sablonun o anki surumune sabitlenir.
     * Zaten ZAMANLANDI/GONDERILIYOR/BITTI ise etkisiz doner (cift tiklama); ZAMANLANDI iken yeni zaman verilirse
     * (henuz cozulmediyse) zaman guncellenir.
     */
    public CampaignView schedule(Long id, Instant scheduledAt) {
        MailCampaign c = find(id);
        switch (c.getStatus()) {
            case SCHEDULED -> {
                if (scheduledAt != null && c.getResolvedAt() == null) {
                    Instant when = validWhen(scheduledAt);
                    jdbc.update("UPDATE mail_campaign SET scheduled_at = :t, updated_at = :now WHERE id = :id "
                            + "AND status = 'SCHEDULED' AND resolved_at IS NULL", new MapSqlParameterSource("t", ts(when))
                            .addValue("now", ts(Instant.now())).addValue("id", id));
                }
                return get(id);
            }
            case SENDING, DONE -> {
                return get(id);
            }
            case DRAFT -> { }
            default -> throw invalidState();
        }
        MailCustomTemplate t = templates.findById(c.getTemplateId()).orElseThrow(MailCampaignAdminService::templateNotFound);
        if (t.getStatus() != MailCustomTemplate.Status.PUBLISHED) {
            throw new ApiException(HttpStatus.CONFLICT, "MAIL_TEMPLATE_NOT_PUBLISHED", "Şablon yayında değil.");
        }
        MailCustomTemplateVersion v = versions.findByTemplateIdAndVersion(t.getId(), t.getCurrentVersion()).orElseThrow();
        int willSend = (int) resolver.plan(c.getAudienceType(), c.getAudienceValue(), v).stream()
                .filter(p -> p.status() == MailCampaignRecipient.Status.PENDING).count();
        if (willSend == 0) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "MAIL_CAMPAIGN_NO_RECIPIENTS", "Bu hedefte alıcı bulunamadı.");
        }
        Instant when = validWhen(scheduledAt != null ? scheduledAt : c.getScheduledAt());
        int n = jdbc.update("UPDATE mail_campaign SET status = 'SCHEDULED', scheduled_at = :t, template_version = :v, "
                + "updated_at = :now WHERE id = :id AND status = 'DRAFT'", new MapSqlParameterSource("t", ts(when))
                .addValue("v", t.getCurrentVersion()).addValue("now", ts(Instant.now())).addValue("id", id));
        if (n == 0 && find(id).getStatus() != MailCampaign.Status.SCHEDULED) {
            throw invalidState();
        }
        return get(id);
    }

    public CampaignView cancel(Long id) {
        MailCampaign c = find(id);
        if (c.getStatus() == MailCampaign.Status.CANCELLED) {
            return get(id);
        }
        if (c.getStatus() == MailCampaign.Status.DONE || c.getStatus() == MailCampaign.Status.FAILED) {
            throw invalidState();
        }
        Boolean ok = tx.execute(s -> {
            int n = jdbc.update("UPDATE mail_campaign SET status = 'CANCELLED', finished_at = :now, updated_at = :now "
                    + "WHERE id = :id AND status IN ('DRAFT', 'SCHEDULED', 'SENDING', 'PAUSED')",
                    new MapSqlParameterSource("now", ts(Instant.now())).addValue("id", id));
            if (n == 0) {
                return false;
            }
            jdbc.update("UPDATE mail_campaign_recipient SET status = 'CANCELLED', updated_at = :now "
                    + "WHERE campaign_id = :id AND status = 'PENDING'", new MapSqlParameterSource("now", ts(Instant.now()))
                    .addValue("id", id));
            return true;
        });
        if (!Boolean.TRUE.equals(ok) && find(id).getStatus() != MailCampaign.Status.CANCELLED) {
            throw invalidState();
        }
        return get(id);
    }

    public CampaignView pause(Long id) {
        MailCampaign c = find(id);
        if (c.getStatus() == MailCampaign.Status.PAUSED) {
            return get(id);
        }
        int n = jdbc.update("UPDATE mail_campaign SET status = 'PAUSED', updated_at = :now WHERE id = :id "
                + "AND status IN ('SCHEDULED', 'SENDING')", new MapSqlParameterSource("now", ts(Instant.now())).addValue("id", id));
        if (n == 0 && find(id).getStatus() != MailCampaign.Status.PAUSED) {
            throw invalidState();
        }
        return get(id);
    }

    /** DURAKLATILDI -> (cozulmusse GONDERILIYOR, degilse ZAMANLANDI). */
    public CampaignView resume(Long id) {
        MailCampaign c = find(id);
        if (c.getStatus() == MailCampaign.Status.SENDING || c.getStatus() == MailCampaign.Status.SCHEDULED) {
            return get(id);
        }
        int n = jdbc.update("UPDATE mail_campaign SET status = CASE WHEN resolved_at IS NULL THEN 'SCHEDULED' ELSE 'SENDING' END, "
                + "updated_at = :now WHERE id = :id AND status = 'PAUSED'", new MapSqlParameterSource("now", ts(Instant.now()))
                .addValue("id", id));
        if (n == 0) {
            throw invalidState();
        }
        return get(id);
    }

    // ---------- yardimcilar ----------

    private void apply(MailCampaign c, CampaignRequest r) {
        MailCustomTemplate t = templates.findById(r.templateId()).orElseThrow(MailCampaignAdminService::templateNotFound);
        if (t.getStatus() != MailCustomTemplate.Status.PUBLISHED) {
            throw new ApiException(HttpStatus.CONFLICT, "MAIL_TEMPLATE_NOT_PUBLISHED", "Şablon yayında değil.");
        }
        Normalized n = resolver.normalize(r.audience());
        c.setName(r.name().trim());
        c.setTemplateId(t.getId());
        c.setTemplateVersion(t.getCurrentVersion());
        c.setAudienceType(n.type());
        c.setAudienceValue(n.value());
        c.setUnmatchedCount(n.unmatched());
        c.setScheduledAt(r.scheduledAt() == null ? null : validWhen(r.scheduledAt()));
    }

    private static Instant validWhen(Instant when) {
        Instant now = Instant.now();
        Instant w = when == null || when.isBefore(now) ? now : when;
        if (w.isAfter(now.plus(MAX_SCHEDULE_AHEAD))) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "MAIL_CAMPAIGN_SCHEDULE_INVALID", "Zamanlama geçersiz.");
        }
        return w;
    }

    MailCampaign find(Long id) {
        return campaigns.findById(id).orElseThrow(() ->
                new ApiException(HttpStatus.NOT_FOUND, "MAIL_CAMPAIGN_NOT_FOUND", "Kampanya bulunamadı."));
    }

    private static ApiException templateNotFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "MAIL_TEMPLATE_NOT_FOUND", "Şablon bulunamadı.");
    }

    private static ApiException notEditable() {
        return new ApiException(HttpStatus.CONFLICT, "MAIL_CAMPAIGN_NOT_EDITABLE", "Yalnızca taslak kampanyalar düzenlenebilir.");
    }

    private static ApiException invalidState() {
        return new ApiException(HttpStatus.CONFLICT, "MAIL_CAMPAIGN_INVALID_STATE", "Kampanya bu işlem için uygun durumda değil.");
    }

    static Timestamp ts(Instant i) {
        return Timestamp.from(i);
    }

    private static Map<String, Integer> emptyLangs() {
        Map<String, Integer> m = new LinkedHashMap<>();
        LANGS.forEach(l -> m.put(l, 0));
        return m;
    }

    private CampaignView view(MailCampaign c, Counters counters) {
        String tplName = templates.findById(c.getTemplateId()).map(MailCustomTemplate::getName).orElse(null);
        AudienceView audience = new AudienceView(c.getAudienceType(),
                c.getAudienceType() == MailCampaign.AudienceType.FILTER ? resolver.parseFilter(c.getAudienceValue()) : null,
                c.getAudienceType() == MailCampaign.AudienceType.USERS || c.getAudienceType() == MailCampaign.AudienceType.EMAILS
                        ? c.getAudienceValue().split(",").length : null,
                c.getUnmatchedCount());
        return new CampaignView(c.getId(), c.getName(), c.getTemplateId(), tplName, c.getTemplateVersion(), c.getStatus(),
                audience, str(c.getScheduledAt()), str(c.getResolvedAt()), str(c.getStartedAt()), str(c.getFinishedAt()),
                c.getCreatedBy(), str(c.getCreatedAt()), str(c.getUpdatedAt()), c.getError(),
                counters == null ? zero() : counters);
    }

    private static Counters zero() {
        return new Counters(0, 0, 0, 0, 0, 0, Map.of(), emptyLangs(), 0, 0);
    }

    private static String str(Instant i) {
        return i == null ? null : i.toString();
    }

    /** Birden fazla kampanyanin sayaclarini tek gruplu sorguyla hesaplar (sayaclar turetilir; sapma olmaz). */
    Map<Long, Counters> counters(Collection<Long> ids) {
        Map<Long, Counters> out = new HashMap<>();
        if (ids.isEmpty()) {
            return out;
        }
        Map<Long, int[]> sums = new HashMap<>(); // pending, queued, skipped, failed, cancelled, fallback
        Map<Long, Map<String, Integer>> reasons = new HashMap<>();
        Map<Long, Map<String, Integer>> langs = new HashMap<>();
        jdbc.query("SELECT campaign_id, status, skip_reason, lang, lang_fallback, COUNT(*) AS n FROM mail_campaign_recipient "
                + "WHERE campaign_id IN (:ids) GROUP BY campaign_id, status, skip_reason, lang, lang_fallback",
                new MapSqlParameterSource("ids", ids), rs -> {
                    long cid = rs.getLong("campaign_id");
                    int n = rs.getInt("n");
                    int[] a = sums.computeIfAbsent(cid, k -> new int[6]);
                    switch (rs.getString("status")) {
                        case "PENDING" -> a[0] += n;
                        case "QUEUED" -> a[1] += n;
                        case "SKIPPED" -> a[2] += n;
                        case "FAILED" -> a[3] += n;
                        default -> a[4] += n;
                    }
                    String reason = rs.getString("skip_reason");
                    if (reason != null) {
                        reasons.computeIfAbsent(cid, k -> new LinkedHashMap<>()).merge(reason, n, Integer::sum);
                    }
                    if (!"SKIPPED".equals(rs.getString("status")) && !"CANCELLED".equals(rs.getString("status"))) {
                        String lang = rs.getString("lang");
                        if (lang != null) {
                            langs.computeIfAbsent(cid, k -> emptyLangs()).merge(lang, n, Integer::sum);
                        }
                        if (rs.getBoolean("lang_fallback")) {
                            a[5] += n;
                        }
                    }
                });
        for (Long id : ids) {
            int[] a = sums.getOrDefault(id, new int[6]);
            int target = a[0] + a[1] + a[2] + a[3] + a[4];
            int done = a[1] + a[2] + a[3] + a[4];
            out.put(id, new Counters(target, a[0], a[1], a[2], a[3], a[4], reasons.getOrDefault(id, Map.of()),
                    langs.getOrDefault(id, emptyLangs()), a[5], target == 0 ? 0 : done * 100 / target));
        }
        return out;
    }

    /** Dagitici icin: yalnizca gonderim aninda gereken durum. */
    String statusOf(Long id) {
        List<String> r = jdbc.queryForList("SELECT status FROM mail_campaign WHERE id = :id", Map.of("id", id), String.class);
        return r.isEmpty() ? null : r.get(0);
    }
}
