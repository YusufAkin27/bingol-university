package edu.bingol.backend.legal;

import java.util.Locale;

/** Sozlesme / metin turleri. */
public enum LegalType {
    TERMS, PRIVACY, KVKK, COMMUNITY_RULES,
    /** Isteğe bagli izinler icin ayri ayri acik riza metni (kayitta zorunlu onay degil). */
    EXPLICIT_CONSENT,
    /** Cerez ve yerel depolama politikasi (bilgilendirme). */
    COOKIES,
    /** 5651 / FSEK icerik bildirimi ve kaldirma usulu (bilgilendirme). */
    CONTENT_REMOVAL,
    /** Kisisel veri saklama ve imha politikasi ozeti (bilgilendirme). */
    RETENTION;

    /** Kayit sirasinda onaylanmasi zorunlu turler; digerleri yalnizca bilgilendirmedir. */
    public boolean isSignupRequired() {
        return this == TERMS || this == PRIVACY || this == KVKK || this == COMMUNITY_RULES;
    }

    /** Buyuk/kucuk harf ve tire/alt cizgi farkini yok sayar ("community-rules"); bilinmiyorsa null. */
    public static LegalType parse(String value) {
        if (value == null) {
            return null;
        }
        String v = value.trim().toUpperCase(Locale.ROOT).replace('-', '_');
        for (LegalType t : values()) {
            if (t.name().equals(v)) {
                return t;
            }
        }
        return null;
    }
}
