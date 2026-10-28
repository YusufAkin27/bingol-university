package edu.bingol.backend.mail.campaign;

import edu.bingol.backend.admin.AdminDtos.PageResponse;
import edu.bingol.backend.admin.UserFilter;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.mail.MailRenderer;
import edu.bingol.backend.mail.MailService;
import edu.bingol.backend.mail.MailTemplate;
import edu.bingol.backend.mail.campaign.CustomMailRenderer.Content;
import edu.bingol.backend.mail.campaign.CustomMailRenderer.Resolved;
import edu.bingol.backend.mail.campaign.MailAdminDtos.ContentView;
import edu.bingol.backend.mail.campaign.MailAdminDtos.LangContentRequest;
import edu.bingol.backend.mail.campaign.MailAdminDtos.PreviewView;
import edu.bingol.backend.mail.campaign.MailAdminDtos.TemplateRequest;
import edu.bingol.backend.mail.campaign.MailAdminDtos.TemplateRow;
import edu.bingol.backend.mail.campaign.MailAdminDtos.TemplateView;
import edu.bingol.backend.mail.campaign.MailAdminDtos.TestSendView;
import edu.bingol.backend.mail.campaign.MailAdminDtos.VariableInfo;
import edu.bingol.backend.mail.campaign.MailAdminDtos.VariablesView;
import edu.bingol.backend.mail.campaign.MailAdminDtos.VersionRow;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Yonetici e-posta sablonlari: olustur/guncelle (surumlu) / yayinla / arsivle / sil / onizleme / test gonderimi. */
@Service
public class MailTemplateAdminService {

    private static final Map<String, String> VARIABLE_HELP = Map.of(
            "ad", "Alicinin gorunen adi",
            "eposta", "Alicinin e-posta adresi",
            "bolum", "Alicinin bolumu (bos olabilir)",
            "fakulte", "Alicinin fakultesi (bos olabilir)",
            "sinif", "Alicinin sinifi (bos olabilir)",
            "uygulamaUrl", "Uygulamanin herkese acik adresi",
            "abonelikCikUrl", "Abonelikten cik baglantisi (her e-postanin sonuna otomatik eklenir)");

    private final MailCustomTemplateRepository templates;
    private final MailCustomTemplateVersionRepository versions;
    private final MailCampaignRepository campaigns;
    private final CustomMailRenderer renderer;
    private final MailService mail;
    private final UserRepository users;
    private final NamedParameterJdbcTemplate jdbc;
    private final MailCampaignSupport support;

    public MailTemplateAdminService(MailCustomTemplateRepository templates,
                                    MailCustomTemplateVersionRepository versions, MailCampaignRepository campaigns,
                                    CustomMailRenderer renderer, MailService mail, UserRepository users,
                                    NamedParameterJdbcTemplate jdbc, MailCampaignSupport support) {
        this.templates = templates;
        this.versions = versions;
        this.campaigns = campaigns;
        this.renderer = renderer;
        this.mail = mail;
        this.users = users;
        this.jdbc = jdbc;
        this.support = support;
    }

    public VariablesView variables() {
        List<VariableInfo> list = new ArrayList<>();
        for (String v : MailTemplateSanitizer.VARIABLES) {
            list.add(new VariableInfo(v, "{{" + v + "}}", VARIABLE_HELP.get(v), v.equals("abonelikCikUrl")));
        }
        return new VariablesView(list, MailTemplateSanitizer.MAX_HTML, MailTemplateSanitizer.MAX_SUBJECT);
    }

    // ---------- liste / detay ----------

    public PageResponse<TemplateRow> list(MailCustomTemplate.Status status, String q, int page, int size) {
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
            params.addValue("q", "%" + UserFilter.escapeLike(q.trim().toLowerCase()) + "%");
        }
        Long total = jdbc.queryForObject("SELECT COUNT(*) FROM mail_template_custom" + where, params, Long.class);
        params.addValue("lim", s).addValue("off", (long) p * s);
        List<Long> ids = jdbc.queryForList("SELECT id FROM mail_template_custom" + where
                + " ORDER BY id DESC LIMIT :lim OFFSET :off", params, Long.class);
        List<TemplateRow> rows = new ArrayList<>();
        for (Long id : ids) {
            MailCustomTemplate t = templates.findById(id).orElse(null);
            if (t != null) {
                rows.add(row(t, currentVersion(t)));
            }
        }
        return PageResponse.of(rows, p, s, total == null ? 0 : total);
    }

    public TemplateView get(Long id) {
        MailCustomTemplate t = find(id);
        return view(t, currentVersion(t));
    }

    public List<VersionRow> versions(Long id) {
        find(id);
        return versions.findByTemplateIdOrderByVersionDesc(id).stream()
                .map(v -> new VersionRow(v.getVersion(), v.getCreatedBy(), v.getCreatedAt().toString())).toList();
    }

    // ---------- yazma ----------

    @Transactional
    public TemplateView create(Long adminId, TemplateRequest r) {
        MailCustomTemplateVersion v = buildVersion(r, adminId);
        MailCustomTemplate t = new MailCustomTemplate();
        t.setName(r.name().trim());
        t.setDescription(blankToNull(r.description()));
        t.setCreatedBy(adminId);
        t.setCurrentVersion(1);
        t = templates.save(t);
        v.setTemplateId(t.getId());
        v.setVersion(1);
        versions.save(v);
        return view(t, v);
    }

    /** Ad/aciklama her zaman; icerik degistiyse yeni surum olusur (eski surumlere sabitli kampanyalar etkilenmez). */
    @Transactional
    public TemplateView update(Long adminId, Long id, TemplateRequest r) {
        MailCustomTemplate t = find(id);
        if (t.getStatus() == MailCustomTemplate.Status.ARCHIVED) {
            throw new ApiException(HttpStatus.CONFLICT, "MAIL_TEMPLATE_NOT_EDITABLE", "Arşivlenmiş şablon düzenlenemez.");
        }
        MailCustomTemplateVersion cur = currentVersion(t);
        MailCustomTemplateVersion next = buildVersion(r, adminId);
        t.setName(r.name().trim());
        t.setDescription(blankToNull(r.description()));
        t.setUpdatedAt(Instant.now());
        if (sameContent(cur, next)) {
            templates.save(t);
            return view(t, cur);
        }
        next.setTemplateId(t.getId());
        next.setVersion(t.getCurrentVersion() + 1);
        t.setCurrentVersion(next.getVersion());
        templates.save(t);
        versions.save(next);
        return view(t, next);
    }

    @Transactional
    public TemplateView publish(Long id) {
        MailCustomTemplate t = find(id);
        MailCustomTemplateVersion v = currentVersion(t);
        Content tr = CustomMailRenderer.contentOf(v, Lang.TR);
        if (!tr.complete()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "MAIL_TEMPLATE_INVALID", "Şablon geçersiz.", "tr");
        }
        if (t.getStatus() != MailCustomTemplate.Status.PUBLISHED) {
            t.setStatus(MailCustomTemplate.Status.PUBLISHED);
            t.setUpdatedAt(Instant.now());
            templates.save(t);
        }
        return view(t, v);
    }

    @Transactional
    public TemplateView archive(Long id) {
        MailCustomTemplate t = find(id);
        if (t.getStatus() != MailCustomTemplate.Status.ARCHIVED) {
            t.setStatus(MailCustomTemplate.Status.ARCHIVED);
            t.setUpdatedAt(Instant.now());
            templates.save(t);
        }
        return view(t, currentVersion(t));
    }

    /** Kampanyada kullanilmis sablon silinemez (arsivlenir). */
    @Transactional
    public void delete(Long id) {
        MailCustomTemplate t = find(id);
        if (campaigns.existsByTemplateId(id)) {
            throw new ApiException(HttpStatus.CONFLICT, "MAIL_TEMPLATE_IN_USE", "Şablon kampanyalarda kullanıldığı için silinemez.");
        }
        templates.delete(t);
    }

    // ---------- onizleme / test ----------

    public PreviewView previewStored(Long id, String lang, Integer version) {
        MailCustomTemplate t = find(id);
        MailCustomTemplateVersion v = version == null ? currentVersion(t)
                : versions.findByTemplateIdAndVersion(id, version).orElseThrow(MailTemplateAdminService::notFound);
        Lang want = Lang.of(lang);
        Resolved r = CustomMailRenderer.resolve(v, want);
        return render(r, want, support.sampleVariables());
    }

    /** Kaydetmeden onizleme: icerik dogrulanir ve temizlenir, ayni sarmalayici ile cizilir. */
    public PreviewView previewDraft(String lang, LangContentRequest content) {
        Content c = clean(content, "tr");
        Lang want = Lang.of(lang);
        return render(new Resolved(c, want, false), want, support.sampleVariables());
    }

    /** Test e-postasi yalnizca isteyen yoneticinin kendi adresine gider; konu basina [TEST] eklenir. */
    public TestSendView test(Long adminId, Long id, String lang) {
        MailCustomTemplate t = find(id);
        MailCustomTemplateVersion v = currentVersion(t);
        User admin = users.findById(adminId)
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "Giriş gerekli."));
        Lang want = Lang.of(lang);
        Resolved r = CustomMailRenderer.resolve(v, want);
        Map<String, String> vars = support.recipientVars(admin.getId(), admin.getEmail(), admin.getDisplayName(),
                admin.getDepartment(), admin.getFaculty(), admin.getClassYear(), r.used());
        vars.put("tplId", String.valueOf(t.getId()));
        vars.put("tplVer", String.valueOf(v.getVersion()));
        vars.put("subjectPrefix", "[TEST] ");
        mail.enqueue(admin.getEmail(), MailTemplate.CUSTOM, r.used(), vars);
        return new TestSendView(true, want.code(), r.used().code(), support.mask(admin.getEmail()));
    }

    // ---------- yardimcilar ----------

    private PreviewView render(Resolved r, Lang want, Map<String, String> sample) {
        if (!r.content().complete()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "MAIL_TEMPLATE_INVALID", "Şablon geçersiz.", "tr");
        }
        MailRenderer.Rendered out = renderer.renderContent(r.content(), r.used(), sample, "");
        return new PreviewView(want.code(), r.used().code(), r.fallback(), out.subject(), out.html(), out.text(), sample);
    }

    private MailCustomTemplateVersion buildVersion(TemplateRequest r, Long adminId) {
        MailCustomTemplateVersion v = new MailCustomTemplateVersion();
        v.setCreatedBy(adminId);
        Content tr = clean(r.tr(), "tr");
        v.setSubjectTr(tr.subject());
        v.setHtmlTr(tr.html());
        v.setTextTr(tr.text());
        Content en = cleanOptional(r.en(), "en");
        if (en != null) {
            v.setSubjectEn(en.subject());
            v.setHtmlEn(en.html());
            v.setTextEn(en.text());
        }
        Content ar = cleanOptional(r.ar(), "ar");
        if (ar != null) {
            v.setSubjectAr(ar.subject());
            v.setHtmlAr(ar.html());
            v.setTextAr(ar.text());
        }
        return v;
    }

    private static Content cleanOptional(LangContentRequest c, String lang) {
        if (c == null || (isBlank(c.subject()) && isBlank(c.html()) && isBlank(c.text()))) {
            return null;
        }
        return clean(c, lang);
    }

    private static Content clean(LangContentRequest c, String lang) {
        if (c == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "MAIL_TEMPLATE_INVALID", "Şablon geçersiz.", lang);
        }
        String subject = MailTemplateSanitizer.cleanSubject(c.subject());
        String html = MailTemplateSanitizer.cleanHtml(c.html());
        String text = MailTemplateSanitizer.cleanText(c.text(), html);
        return new Content(subject, html, text);
    }

    private static boolean sameContent(MailCustomTemplateVersion a, MailCustomTemplateVersion b) {
        return java.util.Objects.equals(a.getSubjectTr(), b.getSubjectTr()) && java.util.Objects.equals(a.getHtmlTr(), b.getHtmlTr())
                && java.util.Objects.equals(a.getTextTr(), b.getTextTr()) && java.util.Objects.equals(a.getSubjectEn(), b.getSubjectEn())
                && java.util.Objects.equals(a.getHtmlEn(), b.getHtmlEn()) && java.util.Objects.equals(a.getTextEn(), b.getTextEn())
                && java.util.Objects.equals(a.getSubjectAr(), b.getSubjectAr()) && java.util.Objects.equals(a.getHtmlAr(), b.getHtmlAr())
                && java.util.Objects.equals(a.getTextAr(), b.getTextAr());
    }

    MailCustomTemplate find(Long id) {
        return templates.findById(id).orElseThrow(MailTemplateAdminService::notFound);
    }

    MailCustomTemplateVersion currentVersion(MailCustomTemplate t) {
        return versions.findByTemplateIdAndVersion(t.getId(), t.getCurrentVersion())
                .orElseThrow(MailTemplateAdminService::notFound);
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "MAIL_TEMPLATE_NOT_FOUND", "Şablon bulunamadı.");
    }

    private static List<String> languages(MailCustomTemplateVersion v) {
        List<String> l = new ArrayList<>();
        for (Lang lang : Lang.values()) {
            if (CustomMailRenderer.contentOf(v, lang).complete()) {
                l.add(lang.code());
            }
        }
        return l;
    }

    private static TemplateRow row(MailCustomTemplate t, MailCustomTemplateVersion v) {
        return new TemplateRow(t.getId(), t.getName(), t.getDescription(), t.getCategory(), t.getStatus(),
                t.getCurrentVersion(), languages(v), t.getUpdatedAt().toString());
    }

    private static TemplateView view(MailCustomTemplate t, MailCustomTemplateVersion v) {
        Set<String> used = new LinkedHashSet<>();
        for (Lang lang : Lang.values()) {
            Content c = CustomMailRenderer.contentOf(v, lang);
            used.addAll(MailTemplateSanitizer.usedVariables(c.subject()));
            used.addAll(MailTemplateSanitizer.usedVariables(c.html()));
        }
        return new TemplateView(t.getId(), t.getName(), t.getDescription(), t.getCategory(), t.getStatus(),
                t.getCurrentVersion(), cv(v, Lang.TR), cv(v, Lang.EN), cv(v, Lang.AR), languages(v),
                new ArrayList<>(used), t.getCreatedBy(), t.getCreatedAt().toString(), t.getUpdatedAt().toString());
    }

    private static ContentView cv(MailCustomTemplateVersion v, Lang lang) {
        Content c = CustomMailRenderer.contentOf(v, lang);
        return c.complete() ? new ContentView(c.subject(), c.html(), c.text()) : null;
    }

    private static boolean isBlank(String s) {
        return s == null || s.isBlank();
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }
}
