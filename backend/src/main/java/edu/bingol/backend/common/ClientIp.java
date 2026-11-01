package edu.bingol.backend.common;

import jakarta.servlet.http.HttpServletRequest;
import java.net.InetAddress;
import java.util.ArrayList;
import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Istemci IP'sini cozer. X-Forwarded-For yalnizca baglantiyi kuran es guvenilir bir proxy ise dikkate alinir
 * (aksi halde sahte baslikla rate limit atlatilir). Zincir sagdan sola yurunur; guvenilir olmayan ilk adres istemcidir.
 * Guvenilir proxy'ler `app.security.trusted-proxies` (virgullu IP/CIDR) ile verilir; varsayilan: loopback + ozel agler
 * (docker/nginx). Proxy sunucu disaridan dogrudan erisilemeyecek sekilde konumlanmalidir.
 */
@Component
public class ClientIp {

    private final List<Cidr> trusted;

    public ClientIp(@Value("${app.security.trusted-proxies:127.0.0.0/8,::1/128,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,fc00::/7}") String trustedProxies) {
        List<Cidr> list = new ArrayList<>();
        for (String s : trustedProxies.split(",")) {
            if (!s.isBlank()) {
                list.add(Cidr.parse(s.trim()));
            }
        }
        this.trusted = List.copyOf(list);
    }

    public String of(HttpServletRequest req) {
        return resolve(req.getRemoteAddr(), req.getHeader("X-Forwarded-For"));
    }

    /**
     * Hiz siniri anahtari icin IP: IPv6 /64 onekine indirgenir (bir kullaniciya /64 verilir; adres dondurerek limit
     * atlatilamasin), IPv4-eslenik (::ffff:a.b.c.d) IPv4'e cevrilir, IPv4 oldugu gibi kalir. Log/denetim tam adresi
     * kullanmaya devam eder ({@link #of}).
     */
    public String limitKey(HttpServletRequest req) {
        return limitKey(of(req));
    }

    public static String limitKey(String ip) {
        if (ip == null || ip.isBlank()) {
            return "unknown";
        }
        if (ip.indexOf(':') < 0 || !isLiteralIp(ip)) {
            return ip;
        }
        try {
            byte[] b = InetAddress.getByName(ip).getAddress();
            if (b.length == 4) { // Java IPv4-eslenik IPv6'yi zaten Inet4Address'e cevirir
                return InetAddress.getByAddress(b).getHostAddress();
            }
            StringBuilder sb = new StringBuilder("v6:");
            for (int i = 0; i < 8; i++) {
                sb.append(String.format("%02x", b[i] & 0xff));
                if (i % 2 == 1 && i < 7) {
                    sb.append(':');
                }
            }
            return sb.append("::/64").toString();
        } catch (Exception e) {
            return ip;
        }
    }

    public String resolve(String remoteAddr, String xForwardedFor) {
        if (remoteAddr == null) {
            return "unknown";
        }
        if (xForwardedFor == null || xForwardedFor.isBlank() || !isTrusted(remoteAddr)) {
            return remoteAddr;
        }
        String[] parts = xForwardedFor.split(",");
        for (int i = parts.length - 1; i >= 0; i--) {
            String p = parts[i].trim();
            if (!isLiteralIp(p)) {
                return remoteAddr; // bozuk/sahte deger: guvenme
            }
            if (!isTrusted(p)) {
                return p;
            }
        }
        return remoteAddr;
    }

    private boolean isTrusted(String ip) {
        for (Cidr c : trusted) {
            if (c.contains(ip)) {
                return true;
            }
        }
        return false;
    }

    /**
     * DNS cozumlemesi yapmadan yalnizca sayisal IPv4/IPv6 metnini kabul eder. Yalniz hex karakterli ana makine adlari
     * (ornek {@code fade}, {@code bad.bad}) ve {@code 999.1.1.1} gibi bozuk dortlular reddedilir: {@code getByName}
     * bunlari ad cozumlemesine gonderirdi.
     */
    private static boolean isLiteralIp(String s) {
        return parseLiteral(s) != null;
    }

    private static final java.util.regex.Pattern IPV4 =
            java.util.regex.Pattern.compile("(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})");

    /** Sayisal IP'nin baytlari; sayisal degilse null. Hic ag/DNS erisimi yapmaz. */
    private static byte[] parseLiteral(String s) {
        if (s == null || s.isEmpty() || s.length() > 45) {
            return null;
        }
        java.util.regex.Matcher m = IPV4.matcher(s);
        if (m.matches()) {
            byte[] b = new byte[4];
            for (int i = 0; i < 4; i++) {
                int v = Integer.parseInt(m.group(i + 1));
                if (v > 255) {
                    return null;
                }
                b[i] = (byte) v;
            }
            return b;
        }
        // IPv6: en az iki ':' (tek ':' ya da hic yok = ana makine adi/port); yalniz hex, ':' ve gomulu IPv4 icin '.'
        int colons = 0;
        for (int i = 0; i < s.length(); i++) {
            char ch = s.charAt(i);
            if (ch == ':') {
                colons++;
            } else if (!(Character.digit(ch, 16) >= 0 || ch == '.')) {
                return null;
            }
        }
        if (colons < 2) {
            return null;
        }
        try {
            // ':' iceren metin IPv6 sabiti olarak ayristirilir; ad cozumlemesi yapilmaz
            return InetAddress.getByName(s).getAddress();
        } catch (Exception e) {
            return null;
        }
    }

    private record Cidr(byte[] net, int bits) {
        static Cidr parse(String s) {
            try {
                String[] p = s.split("/");
                byte[] a = InetAddress.getByName(p[0]).getAddress();
                int bits = p.length > 1 ? Integer.parseInt(p[1]) : a.length * 8;
                return new Cidr(a, bits);
            } catch (Exception e) {
                throw new IllegalArgumentException("Gecersiz guvenilir proxy: " + s, e);
            }
        }

        boolean contains(String ip) {
            byte[] b = parseLiteral(ip);
            if (b == null) {
                return false;
            }
            try {
                if (b.length != net.length) {
                    return false;
                }
                for (int i = 0; i < bits; i++) {
                    int mask = 0x80 >> (i % 8);
                    if ((b[i / 8] & mask) != (net[i / 8] & mask)) {
                        return false;
                    }
                }
                return true;
            } catch (Exception e) {
                return false;
            }
        }
    }
}
