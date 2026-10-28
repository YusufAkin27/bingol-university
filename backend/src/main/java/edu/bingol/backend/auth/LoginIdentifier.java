package edu.bingol.backend.auth;

import edu.bingol.backend.common.ApiException;
import java.util.Locale;
import java.util.regex.Pattern;
import org.springframework.http.HttpStatus;

/**
 * Kimlik alani: tam e-posta ya da yalnizca okul numarasi. Numara, e-posta kullanici adidir
 * (226051015 -> 226051015@bingol.edu.tr). Tum kimlik uclari tek bu yardimciyla normalize eder.
 */
public final class LoginIdentifier {

    /** Okul numarasi alan adi (e-posta alani yalniz numara ise bu alan eklenir). */
    public static final String STUDENT_DOMAIN = "bingol.edu.tr";

    private static final Pattern SEPARATORS = Pattern.compile("[\\s.\\-]");
    private static final Pattern STUDENT_NUMBER = Pattern.compile("[0-9]{6,12}");

    private LoginIdentifier() {
    }

    /**
     * Kirpar, kucuk harfe cevirir; '@' yoksa bosluk/tire/nokta temizlenip 6-12 haneli numara beklenir.
     * Gecersizse 400 VALIDATION_ERROR. E-posta alan adi dogrulamasi cagirana aittir (register).
     */
    public static String normalize(String raw) {
        if (raw == null || raw.isBlank()) {
            throw invalid();
        }
        String s = raw.trim().toLowerCase(Locale.ROOT);
        if (s.indexOf('@') >= 0) {
            return s;
        }
        String digits = SEPARATORS.matcher(s).replaceAll("");
        if (!STUDENT_NUMBER.matcher(digits).matches()) {
            throw invalid();
        }
        return digits + "@" + STUDENT_DOMAIN;
    }

    /** Yerel kisimda `+etiket` var mi (ali+1@bingol.edu.tr)? Kayitta reddedilir (tek kutu = tek hesap). */
    public static boolean hasPlusAlias(String email) {
        int at = email == null ? -1 : email.lastIndexOf('@');
        return at > 0 && email.lastIndexOf('+', at) >= 0;
    }

    /**
     * Hiz siniri/kota anahtari icin kanonik e-posta: `ali+x@bingol.edu.tr` -> `ali@bingol.edu.tr` (eski +etiketli
     * hesaplar ayni sayaci paylasir). YALNIZ anahtar icindir; saklanan/gonderilen adres degismez.
     */
    public static String aliasKey(String email) {
        if (email == null) {
            return "";
        }
        int at = email.lastIndexOf('@');
        if (at <= 0) {
            return email;
        }
        int plus = email.indexOf('+');
        return plus > 0 && plus < at ? email.substring(0, plus) + email.substring(at) : email;
    }

    private static ApiException invalid() {
        return new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz istek.");
    }
}
