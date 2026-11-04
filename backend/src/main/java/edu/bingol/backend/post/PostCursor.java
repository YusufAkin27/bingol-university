package edu.bingol.backend.post;

import edu.bingol.backend.common.ApiException;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Base64;
import org.springframework.http.HttpStatus;

/** Akış imleci: opak Base64url. latest: (createdAt,id); popular: (score,id). */
public record PostCursor(Instant at, double score, long id) {

    public static String latest(Instant at, long id) {
        return enc("L|" + at + "|" + id);
    }

    public static String popular(double score, long id) {
        return enc("P|" + score + "|" + id);
    }

    /** kind: 'L' veya 'P'; boş imleç null döner (ilk sayfa). */
    public static PostCursor decode(String cursor, char kind) {
        if (cursor == null || cursor.isBlank()) {
            return null;
        }
        try {
            String raw = new String(Base64.getUrlDecoder().decode(cursor), StandardCharsets.UTF_8);
            String[] p = raw.split("\\|");
            if (p.length != 3 || p[0].charAt(0) != kind) {
                throw new IllegalArgumentException();
            }
            long id = Long.parseLong(p[2]);
            return kind == 'L' ? new PostCursor(Instant.parse(p[1]), 0, id) : new PostCursor(null, Double.parseDouble(p[1]), id);
        } catch (RuntimeException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "POST_CURSOR_INVALID", "Geçersiz sayfa imleci.");
        }
    }

    /** Kesfet top imleci: (rankScore, id) + hesap surumu (kopya/atlama ipucu icin). */
    public record Top(double score, long id, long version) {}

    public static String top(double score, long id, long version) {
        return enc("T|" + score + "|" + id + "|" + version);
    }

    /** Bos imlec null (ilk sayfa); bozuk imlec 400 POST_CURSOR_INVALID. */
    public static Top decodeTop(String cursor) {
        if (cursor == null || cursor.isBlank()) {
            return null;
        }
        try {
            String[] p = new String(Base64.getUrlDecoder().decode(cursor), StandardCharsets.UTF_8).split("\\|");
            if (p.length != 4 || !"T".equals(p[0])) {
                throw new IllegalArgumentException();
            }
            double s = Double.parseDouble(p[1]);
            if (Double.isNaN(s) || Double.isInfinite(s)) {
                throw new IllegalArgumentException();
            }
            return new Top(s, Long.parseLong(p[2]), Long.parseLong(p[3]));
        } catch (RuntimeException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "POST_CURSOR_INVALID", "Geçersiz sayfa imleci.");
        }
    }

    /**
     * Tekrar (hepsi gorulmus) modu imleci: gorulme damgasi (after, t0) araligindaki sonraki eski gorulmusler.
     * t0 = tekrar modunun basladigi an (bu ana kadar damgali olanlar gezilir; tekrar gosterilenler yeni damga alir ve
     * ayni gezintide yeniden gelmez).
     */
    public record Recycle(long after, long t0) {}

    public static String recycle(long after, long t0) {
        return enc("R|" + after + "|" + t0);
    }

    /** Imlec tekrar modunda degilse null (T imleci / bos); bozuk imlec 400. */
    public static Recycle decodeRecycle(String cursor) {
        if (cursor == null || cursor.isBlank()) {
            return null;
        }
        try {
            String[] p = new String(Base64.getUrlDecoder().decode(cursor), StandardCharsets.UTF_8).split("\\|");
            if (p.length < 1 || !"R".equals(p[0])) {
                return null;
            }
            if (p.length != 3) {
                throw new IllegalArgumentException();
            }
            return new Recycle(Long.parseLong(p[1]), Long.parseLong(p[2]));
        } catch (RuntimeException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "POST_CURSOR_INVALID", "Geçersiz sayfa imleci.");
        }
    }

    /** Reels imleci: oturum kimliği, rastgelelik tohumu, tekrar modu, önceki sayfanın son yazarı (ardışık yazar önleme). */
    public record Reels(String sid, long seed, boolean replay, long lastAuthor) {}

    public static String reels(String sid, long seed, boolean replay, long lastAuthor) {
        return enc("E|" + sid + "|" + seed + "|" + (replay ? 1 : 0) + "|" + lastAuthor);
    }

    /** Boş imleç null (ilk sayfa); bozuk imleç 400 POST_CURSOR_INVALID. */
    public static Reels decodeReels(String cursor) {
        if (cursor == null || cursor.isBlank()) {
            return null;
        }
        try {
            String[] p = new String(Base64.getUrlDecoder().decode(cursor), StandardCharsets.UTF_8).split("\\|");
            if (p.length != 5 || !"E".equals(p[0]) || p[1].isEmpty() || p[1].length() > 40) {
                throw new IllegalArgumentException();
            }
            return new Reels(p[1], Long.parseLong(p[2]), "1".equals(p[3]), Long.parseLong(p[4]));
        } catch (RuntimeException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "POST_CURSOR_INVALID", "Geçersiz sayfa imleci.");
        }
    }

    /** "Senin İçin" imleci: oturum tohumu (sıra aynı oturumda kararlı, yenilemede değişir). */
    public record ForYou(long seed) {}

    public static String forYou(long seed) {
        return enc("F|" + seed);
    }

    public static ForYou decodeForYou(String cursor) {
        if (cursor == null || cursor.isBlank()) {
            return null;
        }
        try {
            String[] p = new String(Base64.getUrlDecoder().decode(cursor), StandardCharsets.UTF_8).split("\\|");
            if (p.length != 2 || !"F".equals(p[0])) {
                throw new IllegalArgumentException();
            }
            return new ForYou(Long.parseLong(p[1]));
        } catch (RuntimeException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "POST_CURSOR_INVALID", "Geçersiz sayfa imleci.");
        }
    }

    private static String enc(String s) {
        return Base64.getUrlEncoder().withoutPadding().encodeToString(s.getBytes(StandardCharsets.UTF_8));
    }
}
