package edu.bingol.backend.admin;

import jakarta.servlet.http.HttpServletRequest;
import java.nio.charset.StandardCharsets;
import org.springframework.web.util.UriUtils;

/**
 * /api/admin/** icin TEK yol cozumleyicisi (T-010). `getRequestURI()` ham (cozulmemis) yoldur; Spring MVC ise her
 * segmenti cozerek eslestirir (`/%63onversations` -> `/conversations`). Izin, gerekce/hiz ve denetim kararlari ham yola
 * bakarsa kodlu segment ile atlatilir. Bu yuzden TUM yonetici interceptor/filtreleri yolu buradan alir: baglam yolu
 * atilir, `;param` icerigi atilir, her segment UTF-8 olarak cozulur (Spring'in eslestirmesiyle ayni anlam).
 * Cozulemeyen (bozuk %) segment oldugu gibi birakilir: hicbir ozel kurala eslesmez, yani en siki varsayilan (FULL) uygulanir.
 */
public final class AdminPaths {

    /** Yonetici uclarinin oneki (sonunda egik cizgi yok). */
    public static final String PREFIX = "/api/admin";

    private AdminPaths() {}

    /** Istegin uygulama-ici yolu, segmentleri cozulmus (sorgu dizgesi yok). */
    public static String of(HttpServletRequest req) {
        String uri = req.getRequestURI();
        String ctx = req.getContextPath();
        if (ctx != null && !ctx.isEmpty() && uri.startsWith(ctx)) {
            uri = uri.substring(ctx.length());
        }
        return decode(uri);
    }

    /** Ham yolu (zaten baglamsiz) cozer; birim testleri de bunu dogrudan kullanir. */
    public static String decode(String rawPath) {
        if (rawPath == null) {
            return "";
        }
        String p = rawPath;
        int q = p.indexOf('?');
        if (q >= 0) {
            p = p.substring(0, q);
        }
        if (p.indexOf('%') < 0 && p.indexOf(';') < 0) {
            return p;
        }
        String[] segs = p.split("/", -1);
        StringBuilder out = new StringBuilder(p.length());
        for (int i = 0; i < segs.length; i++) {
            if (i > 0) {
                out.append('/');
            }
            out.append(decodeSegment(segs[i]));
        }
        return out.toString();
    }

    private static String decodeSegment(String seg) {
        String s = seg;
        int semi = s.indexOf(';');
        if (semi >= 0) {
            s = s.substring(0, semi);
        }
        if (s.indexOf('%') < 0) {
            return s;
        }
        try {
            String d = UriUtils.decode(s, StandardCharsets.UTF_8);
            // Kodlu '/' veya '\' ya da NUL segmenti bolemez: etkisiz karaktere cevrilir (eslesmeyi degistirmesin)
            return d.replace('/', '_').replace('\\', '_').replace('\u0000', '_');
        } catch (IllegalArgumentException e) {
            return s;
        }
    }

    /** Cozulmus yol /api/admin ya da altinda mi. */
    public static boolean isAdmin(String decodedPath) {
        return decodedPath != null
                && (decodedPath.equals(PREFIX) || decodedPath.startsWith(PREFIX + "/"));
    }

    /**
     * Ham yolda `%40` (e-posta '@') disinda yuzde-kodlu karakter var mi. Yonetici yollarinda baska kodlamaya ihtiyac
     * yoktur; kodlu harf segmentleri (`%63`) yetki atlatmanin yoludur, bu yuzden bunlar 400 ile reddedilir.
     */
    public static boolean hasUnsafeEncoding(String rawPath) {
        if (rawPath == null) {
            return false;
        }
        int i = rawPath.indexOf('%');
        while (i >= 0) {
            boolean at = i + 2 < rawPath.length() &&rawPath.charAt(i + 1) == '4' && rawPath.charAt(i + 2) == '0';
            if (!at) {
                return true;
            }
            i = rawPath.indexOf('%', i + 3);
        }
        return false;
    }
}
