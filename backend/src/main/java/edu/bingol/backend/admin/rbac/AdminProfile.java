package edu.bingol.backend.admin.rbac;

import java.util.Locale;

/** Yonetici profili (P16): yalniz role=ADMIN hesaplar icin anlamlidir. Izinleri {@link PermissionMatrix} belirler. */
public enum AdminProfile {
    FULL, MODERATOR, SUPPORT, EDITOR, VIEWER;

    /** Gecersiz/bos metin icin null. */
    public static AdminProfile parse(String s) {
        if (s == null || s.isBlank()) {
            return null;
        }
        try {
            return valueOf(s.trim().toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException e) {
            return null;
        }
    }
}
