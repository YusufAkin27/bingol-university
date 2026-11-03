package edu.bingol.backend.auth;

import edu.bingol.backend.common.ApiException;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.text.Normalizer;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;
import org.springframework.http.HttpStatus;

/**
 * Parola politikasi (T-005, K-09 varsayilani): en az {@code minLength} karakter (yoneticiler icin daha uzun),
 * yaygin parola listesinde olmama ({@code auth/common-passwords.txt}; sonuna rakam/sembol eklenmis kok kelimeler
 * dahil), tek karakter tekrari / rakam dizisi olmama ve kisisel veri icermeme (e-posta kullanici adi, okul numarasi,
 * gorunen ad sozcukleri). Karakter sinifi zorunlulugu YOKTUR (NIST). Hata: 400 PASSWORD_TOO_WEAK.
 * Giris (login) bu kurallara baglanmaz: eski hesaplar girebilir, yalniz yeni/degisen parola denetlenir.
 */
public final class PasswordPolicy {

    public static final int DEFAULT_MIN = 10;
    public static final int DEFAULT_ADMIN_MIN = 12;
    /** Kok kelime karsilastirmasi icin en kisa kok (kisa kelimeler yanlis pozitif uretir). */
    private static final int MIN_STEM = 4;

    private static final Set<String> COMMON = load();

    private PasswordPolicy() {
    }

    /** Kisisel veri baglami: e-posta (tam), gorunen ad; ikisi de bos olabilir. */
    public record Context(String email, String displayName) {
        public static final Context NONE = new Context(null, null);
    }

    /** Zayifsa 400 PASSWORD_TOO_WEAK; guclu ise sessizce doner. {@code minLength}: bu hesap icin gecerli en az uzunluk. */
    public static void require(String password, int minLength, Context ctx) {
        if (!isStrong(password, minLength, ctx == null ? Context.NONE : ctx)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "PASSWORD_TOO_WEAK",
                    "Bu şifre çok zayıf veya tahmin edilebilir.", String.valueOf(minLength));
        }
    }

    static boolean isStrong(String password, int minLength, Context ctx) {
        if (password == null || password.codePointCount(0, password.length()) < minLength) {
            return false;
        }
        String folded = fold(password);
        if (COMMON.contains(folded) || repeatedOrSequential(folded)) {
            return false;
        }
        // "galatasaray1905", "Sifre1234!" gibi: sondaki rakam/sembolleri atip kok kelimeye bak
        String stem = stripTail(folded);
        if (stem.length() >= MIN_STEM && !stem.equals(folded) && COMMON.contains(stem)) {
            return false;
        }
        return !containsPersonal(folded, ctx);
    }

    /** Kucuk harf, aksansiz (Turkce dahil): ı->i, ş->s, ğ->g, ü->u, ö->o, ç->c. */
    static String fold(String s) {
        String d = Normalizer.normalize(s.toLowerCase(Locale.ROOT), Normalizer.Form.NFD);
        StringBuilder sb = new StringBuilder(d.length());
        d.codePoints().forEach(cp -> {
            if (Character.getType(cp) == Character.NON_SPACING_MARK) {
                return;
            }
            sb.appendCodePoint(cp == 'ı' ? 'i' : cp);
        });
        return sb.toString();
    }

    private static String stripTail(String s) {
        int end = s.length();
        while (end > 0 && !Character.isLetter(s.codePointBefore(end))) {
            end -= Character.charCount(s.codePointBefore(end));
        }
        return s.substring(0, end);
    }

    /** Tek karakter tekrari (aaaaaaaaaa) ya da yalniz artan/azalan rakam-harf dizisi (1234567890, abcdefghij). */
    private static boolean repeatedOrSequential(String s) {
        if (s.chars().distinct().count() == 1) {
            return true;
        }
        if (s.length() < 6) {
            return false;
        }
        boolean up = true;
        boolean down = true;
        for (int i = 1; i < s.length(); i++) {
            int diff = s.charAt(i) - s.charAt(i - 1);
            // 9 -> 0 dongusu
            boolean wrapUp = s.charAt(i - 1) == '9' && s.charAt(i) == '0';
            boolean wrapDown = s.charAt(i - 1) == '0' && s.charAt(i) == '9';
            up &= diff == 1 || wrapUp;
            down &= diff == -1 || wrapDown;
        }
        return up || down;
    }

    private static boolean containsPersonal(String folded, Context ctx) {
        if (ctx.email() != null) {
            String e = fold(ctx.email());
            int at = e.indexOf('@');
            String local = at < 0 ? e : e.substring(0, at);
            int plus = local.indexOf('+');
            if (plus > 0) {
                local = local.substring(0, plus);
            }
            String compact = local.replace(".", "").replace("_", "").replace("-", "");
            // Okul numarasi (6-12 hane) ya da >= 4 harfli kullanici adi parolanin icinde gecemez
            if (compact.length() >= 4 && folded.replace(".", "").replace("_", "").replace("-", "").contains(compact)) {
                return true;
            }
            if (local.length() >= 4 && folded.contains(local)) {
                return true;
            }
        }
        if (ctx.displayName() != null) {
            for (String token : fold(ctx.displayName()).split("[^\\p{L}\\p{N}]+")) {
                if (token.length() >= 4 && folded.contains(token)) {
                    return true;
                }
            }
        }
        return false;
    }

    private static Set<String> load() {
        Set<String> out = new HashSet<>(32768);
        try (InputStream in = PasswordPolicy.class.getResourceAsStream("/auth/common-passwords.txt")) {
            if (in == null) {
                throw new IllegalStateException("auth/common-passwords.txt bulunamadi");
            }
            try (BufferedReader r = new BufferedReader(new InputStreamReader(in, StandardCharsets.UTF_8))) {
                String line;
                while ((line = r.readLine()) != null) {
                    line = line.strip();
                    if (!line.isEmpty() && line.charAt(0) != '#') {
                        out.add(line);
                    }
                }
            }
        } catch (IOException e) {
            throw new IllegalStateException("Yaygin parola listesi okunamadi", e);
        }
        return Set.copyOf(out);
    }
}
