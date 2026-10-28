package edu.bingol.backend.legal;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.legal.LegalDtos.AcceptanceView;
import edu.bingol.backend.legal.LegalDtos.ConsentItem;
import edu.bingol.backend.legal.LegalDtos.PendingConsent;
import edu.bingol.backend.legal.LegalDtos.PublishRequest;
import edu.bingol.backend.legal.LegalDtos.Translation;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import edu.bingol.backend.appinfo.AppSetting;
import edu.bingol.backend.appinfo.AppSettingRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Surumlu sozlesmeler ve kullanici onaylari. Surum ve onay takibi tr belge uzerinden yapilir;
 * diger diller ayni surumun cevirisidir (yoksa tr sunulur).
 */
@Service
public class LegalService {

    private final DocumentRepository docs;
    private final AcceptanceRepository acceptances;
    private final AppSettingRepository settings;

    /** Yer tutucu anahtari -> app_setting anahtari; listede olmayanlar "legal." onekiyle aranir. */
    static final Map<String, String> SETTING_KEYS = Map.of(
            "support.email", "support_email",
            "contact.email", "contact_email");
    private static final long CACHE_MS = 60_000;
    private volatile Map<String, String> cache = Map.of();
    private volatile long cacheAt;

    public LegalService(DocumentRepository docs, AcceptanceRepository acceptances, AppSettingRepository settings) {
        this.docs = docs;
        this.acceptances = acceptances;
        this.settings = settings;
    }

    /** Sunum aninda {{...}} yer tutucularini yonetici ayarlariyla doldurur (veritabanindaki metin degismez). */
    public String render(String text) {
        if (text == null || !text.contains("{{")) {
            return text;
        }
        return LegalTemplate.render(text, placeholderValues());
    }

    /** Ayarlar 60 sn onbellekte tutulur; ayar degisikligi en gec bu sure sonra yansir. */
    private Map<String, String> placeholderValues() {
        long now = System.currentTimeMillis();
        if (now - cacheAt > CACHE_MS) {
            Map<String, String> byKey = new HashMap<>();
            for (AppSetting s : settings.findAll()) {
                byKey.put(s.getKey(), s.getValue());
            }
            Map<String, String> out = new HashMap<>();
            for (Map.Entry<String, String> e : byKey.entrySet()) {
                if (e.getKey().startsWith("legal.")) {
                    out.put(e.getKey().substring("legal.".length()), e.getValue());
                }
            }
            SETTING_KEYS.forEach((ph, key) -> out.put(ph, byKey.get(key)));
            cache = out;
            cacheAt = now;
        }
        return cache;
    }

    /** Her tur icin guncel belge, istenen dilde (yoksa tr). */
    public List<LegalDocument> current(Lang lang) {
        List<LegalDocument> out = new ArrayList<>();
        for (LegalType t : LegalType.values()) {
            findCurrent(t, lang).ifPresent(out::add);
        }
        return out;
    }

    public LegalDocument current(LegalType type, Lang lang) {
        return findCurrent(type, lang)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "LEGAL_NOT_FOUND", "Belge bulunamadı."));
    }

    public List<LegalDocument> versions(LegalType type, Lang lang) {
        return docs.findByTypeAndLangOrderByVersionDesc(type, lang.code());
    }

    /** Kayit sirasinda guncel tum belgeler kabul edilmis sayilir (istemci acceptTerms=true gonderir). */
    @Transactional
    public void recordSignupConsent(Long userId) {
        for (LegalDocument d : baseDocs()) {
            if (d.getType().isSignupRequired()) {
                record(userId, d.getType(), d.getVersion());
            }
        }
    }

    /**
     * Yeniden onay gerektiren ve henuz onaylanmamis guncel belgeler. Guncel surum yalnizca bilgilendirme niteligindeyse
     * (require_reaccept=false) bile, daha once yayimlanmis zorunlu bir surum (ornegin V480) onaylanmadiysa o onay beklenir;
     * bilgilendirme duzeltmesi eski zorunlu onayi dusurmez. Cevaptaki surum her zaman guncel (onaylanabilir) surumdur.
     */
    public List<PendingConsent> pending(Long userId, Lang lang) {
        List<PendingConsent> out = new ArrayList<>();
        for (LegalDocument base : baseDocs()) {
            if (!base.getType().isSignupRequired()) {
                continue;
            }
            int needed = Math.min(base.getVersion(),
                    Math.max(base.isRequireReaccept() ? base.getVersion() : 0, docs.maxReacceptVersion(base.getType())));
            if (needed <= 0) {
                continue;
            }
            boolean accepted = acceptances.existsByUserIdAndDocTypeAndVersion(userId, base.getType(), base.getVersion())
                    || (needed < base.getVersion()
                    && acceptances.existsByUserIdAndDocTypeAndVersionGreaterThanEqual(userId, base.getType(), needed));
            if (!accepted) {
                LegalDocument shown = findCurrent(base.getType(), lang).orElse(base);
                out.add(new PendingConsent(base.getType(), base.getVersion(), shown.getTitle()));
            }
        }
        return out;
    }

    /** Yalnizca guncel (aktif) surum onaylanabilir; eski surum 409 VERSION_OUTDATED. */
    @Transactional
    public void accept(Long userId, List<ConsentItem> items) {
        for (ConsentItem item : items) {
            LegalDocument base = docs.findByTypeAndLangAndActiveTrue(item.type(), Lang.TR.code())
                    .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "LEGAL_NOT_FOUND", "Belge bulunamadı."));
            if (base.getVersion() != item.version()) {
                throw new ApiException(HttpStatus.CONFLICT, "VERSION_OUTDATED",
                        "Bu belgenin yeni bir sürümü yayımlandı. Güncel sürümü onaylayın.");
            }
            record(userId, item.type(), item.version());
        }
    }

    public List<AcceptanceView> mine(Long userId) {
        return acceptances.findByUserIdOrderByAcceptedAtDesc(userId).stream()
                .map(a -> new AcceptanceView(a.getDocType(), a.getVersion(), a.getAcceptedAt().toString())).toList();
    }

    /** Yonetici: yeni surum yayinlar; onceki surumler arsivlenir, tum diller ayni numarayi alir. */
    @Transactional
    public int publish(LegalType type, PublishRequest r) {
        int version = docs.maxVersion(type) + 1;
        docs.deactivate(type);
        boolean reaccept = r.requireReaccept() == null || r.requireReaccept();
        save(type, Lang.TR, version, r.tr(), reaccept);
        if (r.en() != null) {
            save(type, Lang.EN, version, r.en(), reaccept);
        }
        if (r.ar() != null) {
            save(type, Lang.AR, version, r.ar(), reaccept);
        }
        return version;
    }

    public List<LegalDocument> baseDocs() {
        return docs.findByActiveTrue().stream().filter(d -> Lang.TR.code().equals(d.getLang()))
                .sorted(Comparator.comparing(LegalDocument::getType)).toList();
    }

    private java.util.Optional<LegalDocument> findCurrent(LegalType type, Lang lang) {
        return docs.findByTypeAndLangAndActiveTrue(type, lang.code())
                .or(() -> docs.findByTypeAndLangAndActiveTrue(type, Lang.TR.code()));
    }

    private void save(LegalType type, Lang lang, int version, Translation t, boolean reaccept) {
        LegalDocument d = new LegalDocument();
        d.setType(type);
        d.setLang(lang.code());
        d.setVersion(version);
        d.setTitle(t.title().trim());
        d.setContent(t.content().trim());
        d.setRequireReaccept(reaccept);
        d.setActive(true);
        docs.save(d);
    }

    private void record(Long userId, LegalType type, int version) {
        if (!acceptances.existsByUserIdAndDocTypeAndVersion(userId, type, version)) {
            LegalAcceptance a = new LegalAcceptance();
            a.setUserId(userId);
            a.setDocType(type);
            a.setVersion(version);
            acceptances.save(a);
        }
    }
}
