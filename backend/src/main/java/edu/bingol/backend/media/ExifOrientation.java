package edu.bingol.backend.media;

/** JPEG APP1/Exif icindeki yon (orientation) etiketini okur; her tur sorunda 1 (donusturme yok) doner. */
final class ExifOrientation {

    private ExifOrientation() {
    }

    static int read(byte[] d) {
        try {
            int p = 2; // SOI sonrasi
            while (p + 4 <= d.length) {
                if ((d[p] & 0xFF) != 0xFF) {
                    return 1;
                }
                int marker = d[p + 1] & 0xFF;
                if (marker == 0xFF) { // dolgu
                    p++;
                    continue;
                }
                if (marker == 0xDA || marker == 0xD9) { // goruntu verisi basladi
                    return 1;
                }
                int len = u16(d, p + 2, false);
                if (len < 2) {
                    return 1;
                }
                if (marker == 0xE1 && len >= 8 && isExif(d, p + 4)) {
                    return fromTiff(d, p + 10, p + 2 + len);
                }
                p += 2 + len;
            }
        } catch (RuntimeException e) {
            // sinir disi okuma = bozuk EXIF; yok say
        }
        return 1;
    }

    private static boolean isExif(byte[] d, int p) {
        return d[p] == 'E' && d[p + 1] == 'x' && d[p + 2] == 'i' && d[p + 3] == 'f' && d[p + 4] == 0 && d[p + 5] == 0;
    }

    private static int fromTiff(byte[] d, int t, int end) {
        if (t + 8 > end) {
            return 1;
        }
        boolean le;
        if (d[t] == 'I' && d[t + 1] == 'I') {
            le = true;
        } else if (d[t] == 'M' && d[t + 1] == 'M') {
            le = false;
        } else {
            return 1;
        }
        long ifd = u32(d, t + 4, le);
        if (ifd < 8 || t + ifd + 2 > end) {
            return 1;
        }
        int q = (int) (t + ifd);
        int n = u16(d, q, le);
        q += 2;
        for (int i = 0; i < n && q + 12 <= end; i++, q += 12) {
            if (u16(d, q, le) == 0x0112) {
                int v = u16(d, q + 8, le);
                return v >= 1 && v <= 8 ? v : 1;
            }
        }
        return 1;
    }

    private static int u16(byte[] d, int p, boolean le) {
        int a = d[p] & 0xFF;
        int b = d[p + 1] & 0xFF;
        return le ? (b << 8) | a : (a << 8) | b;
    }

    private static long u32(byte[] d, int p, boolean le) {
        long r = 0;
        for (int i = 0; i < 4; i++) {
            long b = d[le ? p + 3 - i : p + i] & 0xFF;
            r = (r << 8) | b;
        }
        return r;
    }
}
