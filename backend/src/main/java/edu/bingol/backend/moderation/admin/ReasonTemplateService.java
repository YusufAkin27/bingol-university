package edu.bingol.backend.moderation.admin;

import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.moderation.DecisionReason;
import edu.bingol.backend.moderation.admin.ModAdminDtos.TemplatePage;
import edu.bingol.backend.moderation.admin.ModAdminDtos.TemplateRequest;
import edu.bingol.backend.moderation.admin.ModAdminDtos.TemplateView;
import edu.bingol.backend.moderation.dto.ModerationDtos.ReasonTemplate;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Karar nedeni sablonlari (P11): tablo `moderation_reason_template` (V730 sabit {@link DecisionReason} listesini
 * tohumlar). Tablo bossa (ya da hic satir yoksa) eski sabit liste gecerlidir: geriye uyum. En cok {@value #MAX} sablon.
 */
@Service
public class ReasonTemplateService {

    public static final String KIND = "DECISION";
    public static final int MAX = 50;

    private final ModerationReasonTemplateRepository repo;
    private final I18n i18n;

    public ReasonTemplateService(ModerationReasonTemplateRepository repo, I18n i18n) {
        this.repo = repo;
        this.i18n = i18n;
    }

    // --- okuma (karar akisi + eski salt-okunur uc) ---

    /** Etkin sablonlar; tablo bossa sabit liste. Eski uc ile ayni bicim. */
    @Transactional(readOnly = true)
    public List<ReasonTemplate> activeForResolve() {
        List<ModerationReasonTemplate> rows = repo.findByKindOrderBySortOrderAscIdAsc(KIND);
        List<ReasonTemplate> out = new ArrayList<>();
        if (rows.isEmpty()) {
            for (DecisionReason r : DecisionReason.values()) {
                Map<String, String> texts = new LinkedHashMap<>();
                for (Lang l : Lang.values()) {
                    texts.put(l.code(), i18n.msg(r.messageKey(), l));
                }
                out.add(new ReasonTemplate(r.name(), i18n.current(r.messageKey()), texts));
            }
            return out;
        }
        Lang cur = Lang.of(org.springframework.context.i18n.LocaleContextHolder.getLocale());
        for (ModerationReasonTemplate t : rows) {
            if (!t.isActive()) {
                continue;
            }
            Map<String, String> texts = new LinkedHashMap<>();
            for (Lang l : Lang.values()) {
                texts.put(l.code(), textOf(t, l));
            }
            out.add(new ReasonTemplate(t.getCode(), textOf(t, cur), texts));
        }
        return out;
    }

    /** Gecerli (etkin) sablon kodu ise buyuk harfli kod; degilse bos. Tablo bossa sabit liste. */
    @Transactional(readOnly = true)
    public Optional<String> validCode(String code) {
        if (code == null || code.isBlank()) {
            return Optional.empty();
        }
        String c = code.trim().toUpperCase(Locale.ROOT);
        if (repo.countByKind(KIND) == 0) {
            return DecisionReason.parse(c).map(Enum::name);
        }
        return repo.findByKindAndCode(KIND, c).filter(ModerationReasonTemplate::isActive).map(ModerationReasonTemplate::getCode);
    }

    /** Alici dilinde sablon metni; sablon yoksa (silinmis/eski) sabit listedeki metin, o da yoksa null. */
    @Transactional(readOnly = true)
    public String text(String code, Lang lang) {
        if (code == null || code.isBlank()) {
            return null;
        }
        String c = code.trim().toUpperCase(Locale.ROOT);
        Optional<ModerationReasonTemplate> t = repo.findByKindAndCode(KIND, c);
        if (t.isPresent()) {
            return textOf(t.get(), lang);
        }
        return DecisionReason.parse(c).map(r -> i18n.msg(r.messageKey(), lang)).orElse(null);
    }

    private static String textOf(ModerationReasonTemplate t, Lang lang) {
        String v = switch (lang) {
            case EN -> t.getTextEn();
            case AR -> t.getTextAr();
            default -> t.getTextTr();
        };
        return v == null || v.isBlank() ? t.getTextTr() : v;
    }

    // --- yonetim (CRUD) ---

    @Transactional(readOnly = true)
    public TemplatePage list() {
        return new TemplatePage(repo.findByKindOrderBySortOrderAscIdAsc(KIND).stream().map(TemplateView::of).toList(), MAX);
    }

    @Transactional
    public TemplateView create(TemplateRequest r) {
        if (r.code() == null || r.code().isBlank()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "REASON_TEMPLATE_INVALID", "Şablon kodu zorunludur.");
        }
        String code = r.code().trim().toUpperCase(Locale.ROOT);
        if (repo.countByKind(KIND) >= MAX) {
            throw new ApiException(HttpStatus.CONFLICT, "REASON_TEMPLATE_LIMIT",
                    "En fazla " + MAX + " sebep şablonu olabilir.", String.valueOf(MAX));
        }
        if (repo.findByKindAndCode(KIND, code).isPresent()) {
            throw new ApiException(HttpStatus.CONFLICT, "REASON_TEMPLATE_EXISTS", "Bu kodla bir şablon zaten var.");
        }
        ModerationReasonTemplate t = new ModerationReasonTemplate();
        t.setKind(KIND);
        t.setCode(code);
        apply(t, r);
        if (r.sortOrder() == null) { // sona ekle
            List<ModerationReasonTemplate> all = repo.findByKindOrderBySortOrderAscIdAsc(KIND);
            t.setSortOrder(all.isEmpty() ? 10 : all.get(all.size() - 1).getSortOrder() + 10);
        }
        t = repo.save(t);
        AuditContext.target("REASON_TEMPLATE", t.getId()).summary("ekle " + code);
        return TemplateView.of(t);
    }

    @Transactional
    public TemplateView update(Long id, TemplateRequest r) {
        ModerationReasonTemplate t = find(id);
        apply(t, r);
        t = repo.save(t);
        AuditContext.target("REASON_TEMPLATE", t.getId()).summary("güncelle " + t.getCode());
        return TemplateView.of(t);
    }

    @Transactional
    public void delete(Long id) {
        ModerationReasonTemplate t = find(id);
        repo.delete(t);
        AuditContext.target("REASON_TEMPLATE", id).summary("sil " + t.getCode());
    }

    private void apply(ModerationReasonTemplate t, TemplateRequest r) {
        String tr = r.textTr() == null ? "" : r.textTr().trim();
        if (tr.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "REASON_TEMPLATE_INVALID", "Türkçe metin zorunludur.");
        }
        t.setTextTr(tr);
        t.setTextEn(blankToNull(r.textEn()));
        t.setTextAr(blankToNull(r.textAr()));
        if (r.active() != null) {
            t.setActive(r.active());
        }
        if (r.sortOrder() != null) {
            t.setSortOrder(Math.max(0, Math.min(r.sortOrder(), 10_000)));
        }
        t.setUpdatedAt(Instant.now());
    }

    private ModerationReasonTemplate find(Long id) {
        return repo.findById(id).filter(t -> KIND.equals(t.getKind())).orElseThrow(() ->
                new ApiException(HttpStatus.NOT_FOUND, "REASON_TEMPLATE_NOT_FOUND", "Sebep şablonu bulunamadı."));
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }
}
