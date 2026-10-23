package edu.bingol.backend.i18n;

import java.util.Locale;

/** Desteklenen diller. Kod veritabaninda ve API'de kucuk harfli iki harf (tr, en, ar) olarak gecer. */
public enum Lang {
    TR("tr"), EN("en"), AR("ar");

    public static final Lang DEFAULT = TR;

    private final String code;

    Lang(String code) {
        this.code = code;
    }

    public String code() {
        return code;
    }

    public Locale locale() {
        return Locale.forLanguageTag(code);
    }

    /** "en", "EN", "en-US" gibi degerleri cozer; bilinmeyen veya bos ise varsayilan (tr). */
    public static Lang of(String value) {
        if (value == null) {
            return DEFAULT;
        }
        String v = value.trim().toLowerCase(Locale.ROOT);
        for (Lang l : values()) {
            if (v.equals(l.code) || v.startsWith(l.code + "-") || v.startsWith(l.code + "_")) {
                return l;
            }
        }
        return DEFAULT;
    }

    public static Lang of(Locale locale) {
        return locale == null ? DEFAULT : of(locale.getLanguage());
    }

    /** Kesin eslesme gerektirir; gecersizse null (dogrulama icin). */
    public static Lang parseStrict(String value) {
        if (value == null) {
            return null;
        }
        for (Lang l : values()) {
            if (l.code.equalsIgnoreCase(value.trim())) {
                return l;
            }
        }
        return null;
    }
}
