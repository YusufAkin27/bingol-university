package edu.bingol.backend.profile.onboarding;

import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.regex.Pattern;

/**
 * Kullanici adi kurallari: 3-24 karakter, yalniz {@code [a-z0-9._]}, harfle baslar, nokta/alt cizgi ardisik olamaz ve
 * ile bitemez. Buyuk-kucuk harf duyarsiz: girdi KUCUK HARFE cevrilip saklanir (benzersiz indeks bu degerdedir).
 * Ayrilmis kelimeler (yonetim/destek/marka taklidi) "iskelet" (nokta ve alt cizgisiz) uzerinden denetlenir.
 * Uygunsuz ifade denetimi servis katmaninda {@code ContentGuard} ile yapilir.
 */
public final class UsernamePolicy {

    public static final int MIN_LEN = 3;
    public static final int MAX_LEN = 24;

    public enum Result { OK, INVALID, RESERVED }

    /** Normallestirilmis ad + sonuc. */
    public record Checked(String username, Result result) {
        public boolean ok() {
            return result == Result.OK;
        }
    }

    private static final Pattern FORMAT = Pattern.compile("^[a-z][a-z0-9._]{2,23}$");
    private static final Pattern SEPARATOR_RUN = Pattern.compile("[._]{2}");

    /** Tek basina yasak (iskelet bicimiyle). */
    static final Set<String> RESERVED = Set.of("admin", "administrator", "root", "system", "sistem", "support", "destek",
            "moderator", "mod", "yonetici", "yonetim", "rektor", "rektorluk", "official", "resmi", "staff", "team",
            "security", "guvenlik", "help", "yardim", "info", "noreply", "null", "undefined", "api", "www", "me", "you",
            "settings", "bukampus", "bingol", "bingoluniversitesi", "buproject", "kampus", "universite");

    /** Iskeletin bu oneklerle baslamasi yasak (taklit: admin1, bukampus_destek ...). */
    static final List<String> RESERVED_PREFIXES = List.of("admin", "bukampus", "moderator", "support", "destek",
            "yonetici", "bingoluniversitesi");

    private UsernamePolicy() {
    }

    public static Checked check(String raw) {
        if (raw == null) {
            return new Checked("", Result.INVALID);
        }
        String u = raw.trim().toLowerCase(Locale.ROOT);
        if (u.length() < MIN_LEN || u.length() > MAX_LEN || !FORMAT.matcher(u).matches()
                || SEPARATOR_RUN.matcher(u).find() || u.endsWith(".") || u.endsWith("_")) {
            return new Checked(u, Result.INVALID);
        }
        String skeleton = u.replace(".", "").replace("_", "");
        if (RESERVED.contains(skeleton) || RESERVED_PREFIXES.stream().anyMatch(skeleton::startsWith)) {
            return new Checked(u, Result.RESERVED);
        }
        return new Checked(u, Result.OK);
    }
}
