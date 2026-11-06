package edu.bingol.backend.auth.realemail;

import java.util.Locale;
import java.util.Set;

/**
 * Gizli / gecici "role" e-posta adresi tespiti. Apple "E-postami gizle" secenegi {@code xxxx@privaterelay.appleid.com}
 * verir: posta yalniz Apple'in role servisinden gecer, gelistirici alan adlarindan gelen postayi reddedebilir ve adres
 * kullanicinin gercek, aktif adresi degildir. Bu nedenle bu tur adresler hesabin "gercek" e-postasi sayilmaz.
 *
 * <p>Alan adi listesi bilincli olarak KISADIR: yalniz saglayicinin KENDI role alan adlari. {@code icloud.com} gibi
 * gercek posta kutusu alan adlari (iCloud+ "E-postami gizle" takma adlari dahil) role DEGILDIR; onlar teslim edilir.
 * Yeni bir role alan adi ortaya cikarsa buraya (ve {@code docs/OAUTH_SETUP.md} bolum 2.5) eklenir. Apple ayrica kimlik
 * jetonunda {@code is_private_email} bayragi verir; o bayrak {@code OAuthTokenVerifier}'da ayrica okunur.
 */
public final class RelayEmails {

    /** Kucuk harfli role alan adlari. */
    static final Set<String> RELAY_DOMAINS = Set.of("privaterelay.appleid.com");

    private RelayEmails() {
    }

    /** E-posta bilinen bir role alan adina mi ait (buyuk/kucuk harf duyarsiz; bos/gecersiz girdi false). */
    public static boolean isRelay(String email) {
        if (email == null) {
            return false;
        }
        int at = email.lastIndexOf('@');
        if (at < 1 || at == email.length() - 1) {
            return false;
        }
        return RELAY_DOMAINS.contains(email.substring(at + 1).trim().toLowerCase(Locale.ROOT));
    }
}
