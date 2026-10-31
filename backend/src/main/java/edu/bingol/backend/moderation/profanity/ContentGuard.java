package edu.bingol.backend.moderation.profanity;

import edu.bingol.backend.common.FieldApiException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/**
 * Herkese acik metin alanlari icin ortak denetim. SOHBET MESAJLARI icin KULLANILMAZ (mesaj govdesi/aciklama serbest;
 * sorun olursa kullanici rapor eder). Ihlalde 422 CONTENT_PROFANITY + `field`; kelime ASLA yankilanmaz.
 */
@Service
public class ContentGuard {

    /** Hangi varlik turu (istatistik icin). */
    public enum Entity { CLUB, EVENT, POST, ANNOUNCEMENT, QUESTION, PROFILE, SUGGESTION, GROUP_TITLE, OTHER }

    private final ProfanityFilter filter;
    private final ProfanityProperties props;
    private final ProfanityHitLogger hits;

    public ContentGuard(ProfanityFilter filter, ProfanityProperties props, ProfanityHitLogger hits) {
        this.filter = filter;
        this.props = props;
        this.hits = hits;
    }

    public void assertClean(String field, String text) {
        assertClean(Entity.OTHER, field, null, text);
    }

    public void assertClean(Entity entity, String field, Long userId, String text) {
        if (!props.enabled() || text == null || text.isBlank()) {
            return;
        }
        ProfanityMatcher.Result res = filter.check(text);
        if (!res.blocked()) {
            return;
        }
        boolean block = props.mode() != ProfanityProperties.Mode.FLAG;
        ProfanityCategory cat = filter.categoryOf(res);
        if (cat == null || cat == ProfanityCategory.PROFANITY) {
            hits.record(entity.name(), field, userId, block ? "BLOCK" : "FLAG");
        } else {
            hits.record(entity.name(), field, userId, block ? "BLOCK" : "FLAG", cat); // T-059: kategori de gunluge
        }
        if (block) {
            throw new FieldApiException(HttpStatus.UNPROCESSABLE_ENTITY, "CONTENT_PROFANITY",
                    "Bu alanda uygunsuz ifade kullanılamaz. Lütfen metni düzenleyin.", field);
        }
    }

    /** PATCH: yalnizca DEGISEN alan denetlenir (mevcut kayit filtreyi gecemese de baska alan guncellenebilir). */
    public void assertChanged(Entity entity, String field, Long userId, String oldValue, String newValue) {
        if (newValue == null) {
            return;
        }
        if (oldValue != null && oldValue.strip().equals(newValue.strip())) {
            return;
        }
        assertClean(entity, field, userId, newValue);
    }

    /** Null-guvenli yardimcilar: eski testler/yapilar guard'siz kurulabildigi icin servisler alani istege bagli tutar. */
    public static void clean(ContentGuard g, Entity entity, String field, Long userId, String text) {
        if (g != null) {
            g.assertClean(entity, field, userId, text);
        }
    }

    public static void changed(ContentGuard g, Entity entity, String field, Long userId, String oldValue, String newValue) {
        if (g != null) {
            g.assertChanged(entity, field, userId, oldValue, newValue);
        }
    }
}
