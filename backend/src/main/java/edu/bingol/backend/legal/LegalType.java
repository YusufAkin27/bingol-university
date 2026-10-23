package edu.bingol.backend.legal;

import java.util.Locale;

/** Sozlesme / metin turleri. */
public enum LegalType {
    TERMS, PRIVACY, KVKK, COMMUNITY_RULES;

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
