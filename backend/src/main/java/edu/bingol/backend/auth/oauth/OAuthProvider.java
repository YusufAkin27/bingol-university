package edu.bingol.backend.auth.oauth;

import java.util.Locale;

/** Desteklenen harici kimlik saglayicilari. {@code name()} DB'de ve API'de saklanan degerdir. */
public enum OAuthProvider {
    GOOGLE, APPLE;

    /** "google" / "GOOGLE" -> GOOGLE; taninmayan deger null. */
    public static OAuthProvider parse(String raw) {
        if (raw == null) {
            return null;
        }
        try {
            return valueOf(raw.trim().toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException e) {
            return null;
        }
    }
}
