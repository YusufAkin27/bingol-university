package edu.bingol.backend.moderation.profanity;

/**
 * Uygunsuz ifade kategorisi (T-059, V992). Siddet sirasi: SELF_HARM > TERROR > HATE > PROFANITY ({@link #severity}).
 * Yerlesik kategori listeleri kaynak dosyalardadir; yonetici kelimeleri ve engelleme gunlugu kategori tasir.
 */
public enum ProfanityCategory {
    /** Kufur/hakaret (mevcut liste ve varsayilan). */
    PROFANITY,
    /** Nefret soylemi / etnik-dini asagilama. */
    HATE,
    /** Teror ovgusu, katilim cagrisi, somut siddet tehdidi. */
    TERROR,
    /** Baskasini kendine zarara / intihara tesvik. */
    SELF_HARM;

    public int severity() {
        return switch (this) {
            case SELF_HARM -> 3;
            case TERROR -> 2;
            case HATE -> 1;
            case PROFANITY -> 0;
        };
    }
}
