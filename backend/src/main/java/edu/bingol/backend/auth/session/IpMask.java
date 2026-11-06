package edu.bingol.backend.auth.session;

/**
 * Cihaz listesi icin kismen maskelenmis IP: IPv4'te son iki sekiz'li, IPv6'da ilk iki gruptan sonrasi gizlenir
 * ("203.0.*.*", "2001:db8:*"). Sehir/konum bilgisi YOKTUR; ham adres saklanmaz.
 */
public final class IpMask {

    private IpMask() {}

    public static String of(String ip) {
        if (ip == null || ip.isBlank()) {
            return null;
        }
        String v = ip.trim();
        int pct = v.indexOf('%');
        if (pct > 0) {
            v = v.substring(0, pct);
        }
        if (v.contains(":")) {
            String[] g = v.split(":");
            if (g.length >= 2 && !g[0].isEmpty()) {
                return g[0] + ":" + g[1] + ":*";
            }
            return null;
        }
        String[] o = v.split("[.]");
        if (o.length == 4) {
            return o[0] + "." + o[1] + ".*.*";
        }
        return null;
    }
}
