package edu.bingol.backend.accessban;

import java.net.InetAddress;
import java.util.Arrays;
import java.util.List;

/**
 * IPv4/IPv6 adres ve CIDR islemleri. Her adres 128 bite (iki long) acilir; IPv4, ::ffff:a.b.c.d olarak eslenir,
 * boylece tek yapi iki ailede de calisir. DNS cozumlemesi YAPILMAZ (yalniz sayisal metin kabul edilir).
 */
public final class IpRanges {

    private IpRanges() {}

    /** Kapali aralik [start, end] (128 bit, isaretsiz karsilastirilir) ve kanonik metni. */
    public record Range(long sHi, long sLo, long eHi, long eLo, String canonical, boolean single) {
        public boolean contains(long hi, long lo) {
            return cmp(hi, lo, sHi, sLo) >= 0 && cmp(hi, lo, eHi, eLo) <= 0;
        }

        /** Iki aralik kesisiyor mu. */
        public boolean overlaps(Range o) {
            return cmp(sHi, sLo, o.eHi, o.eLo) <= 0 && cmp(o.sHi, o.sLo, eHi, eLo) <= 0;
        }

        /** Bu aralik `o` icinde tamamen yer aliyor mu. */
        public boolean within(Range o) {
            return cmp(sHi, sLo, o.sHi, o.sLo) >= 0 && cmp(eHi, eLo, o.eHi, o.eLo) <= 0;
        }
    }

    static int cmp(long aHi, long aLo, long bHi, long bLo) {
        int c = Long.compareUnsigned(aHi, bHi);
        return c != 0 ? c : Long.compareUnsigned(aLo, bLo);
    }

    /** Tek adres ya da CIDR; gecersizse IllegalArgumentException. */
    public static Range parse(String text) {
        if (text == null) {
            throw new IllegalArgumentException("bos");
        }
        String s = text.trim();
        int slash = s.indexOf('/');
        String addr = slash < 0 ? s : s.substring(0, slash);
        byte[] b = literal(addr);
        if (b == null) {
            throw new IllegalArgumentException("gecersiz adres");
        }
        boolean v4 = b.length == 4;
        int maxBits = v4 ? 32 : 128;
        int bits = maxBits;
        if (slash >= 0) {
            String p = s.substring(slash + 1);
            if (p.isEmpty() || p.length() > 3 || !p.chars().allMatch(Character::isDigit)) {
                throw new IllegalArgumentException("gecersiz onek");
            }
            bits = Integer.parseInt(p);
            if (bits > maxBits) {
                throw new IllegalArgumentException("gecersiz onek");
            }
        }
        long[] k = key(b);
        int p128 = v4 ? 96 + bits : bits;
        long mHi = p128 == 0 ? 0 : (p128 <= 64 ? -1L << (64 - p128) : -1L);
        long mLo = p128 <= 64 ? 0 : -1L << (128 - p128);
        long sHi = k[0] & mHi;
        long sLo = k[1] & mLo;
        long eHi = sHi | ~mHi;
        long eLo = sLo | ~mLo;
        boolean single = bits == maxBits;
        String canon = text(sHi, sLo) + (single ? "" : "/" + bits);
        return new Range(sHi, sLo, eHi, eLo, canon, single);
    }

    /** Tek adresin 128 bit anahtari {hi, lo}; gecersizse null. */
    public static long[] keyOf(String ip) {
        byte[] b = literal(ip == null ? null : ip.trim());
        return b == null ? null : key(b);
    }

    /** Anahtari kanonik metne cevirir (IPv4-eslenik -> noktali, aksi halde tam IPv6 gosterimi). */
    public static String text(long hi, long lo) {
        if (hi == 0 && (lo >>> 32) == 0xFFFFL) {
            long v = lo & 0xFFFFFFFFL;
            return ((v >> 24) & 255) + "." + ((v >> 16) & 255) + "." + ((v >> 8) & 255) + "." + (v & 255);
        }
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < 8; i++) {
            long w = i < 4 ? (hi >>> (48 - 16 * i)) & 0xFFFF : (lo >>> (48 - 16 * (i - 4))) & 0xFFFF;
            if (i > 0) {
                sb.append(':');
            }
            sb.append(Long.toHexString(w));
        }
        return sb.toString();
    }

    public static int family(long hi, long lo) {
        return hi == 0 && (lo >>> 32) == 0xFFFFL ? 4 : 6;
    }

    private static long[] key(byte[] b) {
        byte[] f = new byte[16];
        if (b.length == 4) {
            f[10] = (byte) 0xFF;
            f[11] = (byte) 0xFF;
            System.arraycopy(b, 0, f, 12, 4);
        } else {
            System.arraycopy(b, 0, f, 0, 16);
        }
        long hi = 0;
        long lo = 0;
        for (int i = 0; i < 8; i++) {
            hi = (hi << 8) | (f[i] & 0xFF);
            lo = (lo << 8) | (f[8 + i] & 0xFF);
        }
        return new long[] {hi, lo};
    }

    /** Yalniz sayisal IPv4/IPv6 metni (DNS yok); gecersizse null. */
    private static byte[] literal(String s) {
        if (s == null || s.isEmpty() || s.length() > 45) {
            return null;
        }
        boolean colon = false;
        for (int i = 0; i < s.length(); i++) {
            char ch = s.charAt(i);
            if (ch == ':') {
                colon = true;
            } else if (!(Character.digit(ch, 16) >= 0 || ch == '.')) {
                return null;
            }
        }
        if (!colon && !s.matches("\\d{1,3}(\\.\\d{1,3}){3}")) {
            return null; // "1.2.3" gibi kisaltmalar InetAddress'te genisler; kabul etmeyiz
        }
        try {
            return InetAddress.getByName(s).getAddress();
        } catch (Exception e) {
            return null;
        }
    }

    /** Cakisabilir aralik kumesi icin O(log n) arama (sirali baslangic + onek-maksimum bitis). */
    public static final class RangeSet {

        public static final RangeSet EMPTY = new RangeSet(new Range[0], new long[0]);

        private final Range[] r;
        private final long[] ids;
        private final long[] maxHi;
        private final long[] maxLo;

        private RangeSet(Range[] sorted, long[] ids) {
            this.r = sorted;
            this.ids = ids;
            this.maxHi = new long[sorted.length];
            this.maxLo = new long[sorted.length];
            for (int i = 0; i < sorted.length; i++) {
                long h = sorted[i].eHi();
                long l = sorted[i].eLo();
                if (i > 0 && cmp(maxHi[i - 1], maxLo[i - 1], h, l) > 0) {
                    h = maxHi[i - 1];
                    l = maxLo[i - 1];
                }
                maxHi[i] = h;
                maxLo[i] = l;
            }
        }

        public record Entry(Range range, long id) {}

        public static RangeSet of(List<Entry> entries) {
            Entry[] a = entries.toArray(new Entry[0]);
            Arrays.sort(a, (x, y) -> cmp(x.range().sHi(), x.range().sLo(), y.range().sHi(), y.range().sLo()));
            Range[] rs = new Range[a.length];
            long[] ids = new long[a.length];
            for (int i = 0; i < a.length; i++) {
                rs[i] = a[i].range();
                ids[i] = a[i].id();
            }
            return new RangeSet(rs, ids);
        }

        public int size() {
            return r.length;
        }

        /** Adresi iceren bir aralik varsa onun kimligi, yoksa -1. */
        public long find(long hi, long lo) {
            int l = 0;
            int h = r.length - 1;
            int idx = -1;
            while (l <= h) {
                int m = (l + h) >>> 1;
                if (cmp(r[m].sHi(), r[m].sLo(), hi, lo) <= 0) {
                    idx = m;
                    l = m + 1;
                } else {
                    h = m - 1;
                }
            }
            for (int j = idx; j >= 0; j--) {
                if (cmp(maxHi[j], maxLo[j], hi, lo) < 0) {
                    break;
                }
                if (cmp(r[j].eHi(), r[j].eLo(), hi, lo) >= 0) {
                    return ids[j];
                }
            }
            return -1;
        }

        public boolean contains(String ip) {
            long[] k = keyOf(ip);
            return k != null && find(k[0], k[1]) >= 0;
        }

        public boolean overlaps(Range range) {
            for (Range x : r) {
                if (x.overlaps(range)) {
                    return true;
                }
            }
            return false;
        }
    }

    /** Engellenemez aglar: loopback + ozel agler (CGNAT 100.64/10 HARIC: paylasimli genel adres olabilir). */
    public static final List<String> PRIVATE = List.of("127.0.0.0/8", "::1/128", "10.0.0.0/8", "172.16.0.0/12",
            "192.168.0.0/16", "169.254.0.0/16", "fc00::/7", "fe80::/10");

    public static RangeSet setOf(List<String> cidrs) {
        long[] n = {1};
        return RangeSet.of(cidrs.stream().filter(s -> !s.isBlank())
                .map(s -> new RangeSet.Entry(parse(s), n[0]++)).toList());
    }
}
