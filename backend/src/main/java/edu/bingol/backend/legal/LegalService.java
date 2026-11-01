package edu.bingol.backend.legal;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.cache.CacheService;
import edu.bingol.backend.common.cache.CacheTier;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.legal.LegalDtos.AcceptanceView;
import edu.bingol.backend.legal.LegalDtos.BaseDoc;
import edu.bingol.backend.legal.LegalDtos.ConsentItem;
import edu.bingol.backend.legal.LegalDtos.LegalContent;
import edu.bingol.backend.legal.LegalDtos.LegalSummary;
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
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.core.type.TypeReference;

/**
 * Surumlu sozlesmeler ve kullanici onaylari. Surum ve onay takibi tr belge uzerinden yapilir;
 * diger diller ayni surumun cevirisidir (yoksa tr sunulur).
 */
@Service
public class LegalService {

    private final DocumentRepository docs;
    private final AcceptanceRepository acceptances;
    private final AppSettingRepository settings;
    private CacheService readCache = CacheService.passthrough();
    private static final TypeReference<List<LegalSummary>> SUMMARIES = new TypeReference<>() { };
    private static final TypeReference<LegalContent> CONTENT = new TypeReference<>() { };
    private static final TypeReference<List<BaseDoc>> BASES = new TypeReference<>() { };

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

    /** Sunucu onbellegi `legal` ad alani; yeni surum yayini (LegalDocument varlik olaylari) gecersiz kilar. */
    @Autowired(required = false)
    void setCache(CacheService cache) {
        this.readCache = cache;
    }

    /** Herkese acik liste ozeti (dil basina onbellekli). */
    public List<LegalSummary> summaries(Lang lang) {
        return readCache.get("legal", "s:" + lang.code(), CacheTier.STABLE, SUMMARIES,
                () -> current(lang).stream().map(LegalSummary::of).toList());
    }

    /** Herkese acik belge icerigi, yer tutucular DOLDURULMAMIS (dil + tur basina onbellekli); sunumda {@link #render}. */
    public LegalContent content(LegalType type, Lang lang) {
        return readCache.get("legal", "c:" + type.name() + ":" + lang.code(), CacheTier.STABLE, CONTENT,
                () -> LegalContent.of(current(type, lang)));
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

    /** Surum listesi: metin (120-320 KB) okunmaz; dil + tur basina onbellekli, yeni surumde (legal ad alani) yenilenir. */
    public List<LegalSummary> versions(LegalType type, Lang lang) {
        return readCache.get("legal", "v:" + type.name() + ":" + lang.code(), CacheTier.STABLE, SUMMARIES,
                () -> docs.versionHeads(type, lang.code()).stream().map(LegalSummary::of).toList());
    }

    /** Kayit sirasinda guncel tum belgeler kabul edilmis sayilir (istemci acceptTerms=true gonderir). */
    @Transactional
    public void recordSignupConsent(Long userId) {
        for (BaseDoc d : baseDocs()) {
            if (d.type().isSignupRequired()) {
                record(userId, d.type(), d.version());
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
        Map<LegalType, String> titles = null; // yalniz bekleyen onay varsa (ve tr disi dilde) gerekir
        for (BaseDoc base : baseDocs()) {
            if (!base.type().isSignupRequired()) {
                continue;
            }
            int needed = Math.min(base.version(),
                    Math.max(base.requireReaccept() ? base.version() : 0, docs.maxReacceptVersion(base.type())));
            if (needed <= 0) {
                continue;
            }
            boolean accepted = acceptances.existsByUserIdAndDocTypeAndVersion(userId, base.type(), base.version())
                    || (needed < base.version()
                    && acceptances.existsByUserIdAndDocTypeAndVersionGreaterThanEqual(userId, base.type(), needed));
            if (!accepted) {
                if (titles == null) {
                    titles = lang == Lang.TR ? Map.of() : summaryTitles(lang);
                }
                out.add(new PendingConsent(base.type(), base.version(), titles.getOrDefault(base.type(), base.title())));
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

    /**
     * Onay/surum takibinin esas aldigi aktif tr belgelerin baslik satirlari (metinsiz). Her acilista ve
     * (yeniden onay acikken) her yazma isteginde cagrildigindan onbellekli; LegalDocument olayiyla gecersiz kilinir.
     */
    public List<BaseDoc> baseDocs() {
        return readCache.get("legal", "base", CacheTier.STABLE, BASES,
                () -> docs.activeHeads(Lang.TR.code()).stream().map(BaseDoc::of)
                        .sorted(Comparator.comparing(BaseDoc::type)).toList());
    }

    /** Istenen dildeki guncel basliklar (yoksa tr): onbellekli ozet listesinden, tam metin okunmaz. */
    private Map<LegalType, String> summaryTitles(Lang lang) {
        Map<LegalType, String> m = new HashMap<>();
        for (LegalSummary s : summaries(lang)) {
            m.put(s.type(), s.title());
        }
        return m;
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
