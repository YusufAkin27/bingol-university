package edu.bingol.backend.media;

/**
 * Minimal WebM (EBML/Matroska alt kümesi) üst veri ayrıştırıcı (ffmpeg bağımlılığı yok): EBML başlığı + DocType "webm",
 * Segment/Info içinden süre (Duration x TimecodeScale) ve Tracks içinden ilk video izinin boyutları. Süresi bulunamayan
 * (ör. MediaRecorder canlı kaydı) ya da bozuk yapı {@link Mp4Info.Invalid} fırlatır: süre doğrulanamayan video kabul edilmez.
 * İçerik (codec) DOĞRULANMAZ; yalnız kap yapısı denetlenir.
 */
public final class WebmInfo {

    /** `width`/`height` bilinmiyorsa 0. */
    public record Info(long durationMs, int width, int height) {}

    private static final long ID_EBML = 0x1A45DFA3L;
    private static final long ID_DOCTYPE = 0x4282L;
    private static final long ID_SEGMENT = 0x18538067L;
    private static final long ID_INFO = 0x1549A966L;
    private static final long ID_TIMESCALE = 0x2AD7B1L;
    private static final long ID_DURATION = 0x4489L;
    private static final long ID_TRACKS = 0x1654AE6BL;
    private static final long ID_TRACKENTRY = 0xAEL;
    private static final long ID_TRACKTYPE = 0x83L;
    private static final long ID_VIDEO = 0xE0L;
    private static final long ID_PIXELW = 0xB0L;
    private static final long ID_PIXELH = 0xBAL;
    private static final long ID_CLUSTER = 0x1F43B675L;
    private static final int MAX_ELEMENTS = 4096;

    private WebmInfo() {
    }

    /** İlk 4 bayt EBML imzası (1A 45 DF A3). */
    public static boolean hasMagic(byte[] d) {
        return d != null && d.length >= 16 && (d[0] & 0xff) == 0x1A && (d[1] & 0xff) == 0x45
                && (d[2] & 0xff) == 0xDF && (d[3] & 0xff) == 0xA3;
    }

    /** Eleman: kimlik, veri başlangıcı, veri sonu (bilinmeyen boyutta sınır), boyut bilinmiyor mu. */
    private record Elem(long id, int dataStart, int dataEnd, boolean unknown) {}

    public static Info parse(byte[] d) throws Mp4Info.Invalid {
        if (!hasMagic(d)) {
            throw new Mp4Info.Invalid("ebml yok");
        }
        Elem hdr = read(d, 0, d.length);
        if (hdr.id() != ID_EBML || hdr.unknown()) {
            throw new Mp4Info.Invalid("ebml basligi");
        }
        String doc = findString(d, hdr.dataStart(), hdr.dataEnd(), ID_DOCTYPE);
        if (!"webm".equals(doc)) {
            throw new Mp4Info.Invalid("doctype webm degil");
        }
        Elem seg = read(d, hdr.dataEnd(), d.length);
        if (seg.id() != ID_SEGMENT) {
            throw new Mp4Info.Invalid("segment yok");
        }
        long timescale = 1_000_000L;
        double duration = -1;
        int w = 0;
        int h = 0;
        int p = seg.dataStart();
        int end = seg.dataEnd();
        int guard = 0;
        while (p < end && guard++ < MAX_ELEMENTS) {
            Elem e = read(d, p, end);
            if (e.id() == ID_CLUSTER) {
                break; // Info ve Tracks kumelerden once gelir
            }
            if (e.id() == ID_INFO) {
                int q = e.dataStart();
                int g2 = 0;
                while (q < e.dataEnd() && g2++ < MAX_ELEMENTS) {
                    Elem c = read(d, q, e.dataEnd());
                    if (c.id() == ID_TIMESCALE) {
                        timescale = uint(d, c);
                    } else if (c.id() == ID_DURATION) {
                        duration = floating(d, c);
                    }
                    q = c.dataEnd();
                }
            } else if (e.id() == ID_TRACKS && w == 0) {
                int[] wh = firstVideoSize(d, e);
                w = wh[0];
                h = wh[1];
            }
            if (e.unknown()) {
                break; // boyutu bilinmeyen eleman atlanamaz
            }
            p = e.dataEnd();
        }
        if (duration <= 0 || timescale <= 0 || Double.isNaN(duration) || Double.isInfinite(duration)) {
            throw new Mp4Info.Invalid("sure yok");
        }
        long ms = Math.round(duration * timescale / 1_000_000.0);
        if (ms <= 0) {
            throw new Mp4Info.Invalid("sure gecersiz");
        }
        return new Info(ms, w, h);
    }

    private static int[] firstVideoSize(byte[] d, Elem tracks) throws Mp4Info.Invalid {
        int q = tracks.dataStart();
        int g = 0;
        while (q < tracks.dataEnd() && g++ < MAX_ELEMENTS) {
            Elem te = read(d, q, tracks.dataEnd());
            if (te.id() == ID_TRACKENTRY) {
                long type = -1;
                int w = 0;
                int h = 0;
                int r = te.dataStart();
                int g2 = 0;
                while (r < te.dataEnd() && g2++ < MAX_ELEMENTS) {
                    Elem c = read(d, r, te.dataEnd());
                    if (c.id() == ID_TRACKTYPE) {
                        type = uint(d, c);
                    } else if (c.id() == ID_VIDEO) {
                        int s = c.dataStart();
                        int g3 = 0;
                        while (s < c.dataEnd() && g3++ < MAX_ELEMENTS) {
                            Elem v = read(d, s, c.dataEnd());
                            if (v.id() == ID_PIXELW) {
                                w = (int) Math.min(uint(d, v), Integer.MAX_VALUE);
                            } else if (v.id() == ID_PIXELH) {
                                h = (int) Math.min(uint(d, v), Integer.MAX_VALUE);
                            }
                            s = v.dataEnd();
                        }
                    }
                    r = c.dataEnd();
                }
                if (type == 1) {
                    return new int[] {w, h};
                }
            }
            q = te.dataEnd();
        }
        return new int[] {0, 0};
    }

    private static String findString(byte[] d, int from, int to, long id) throws Mp4Info.Invalid {
        int p = from;
        int g = 0;
        while (p < to && g++ < MAX_ELEMENTS) {
            Elem e = read(d, p, to);
            if (e.id() == id) {
                return new String(d, e.dataStart(), e.dataEnd() - e.dataStart(),
                        java.nio.charset.StandardCharsets.US_ASCII);
            }
            p = e.dataEnd();
        }
        return null;
    }

    private static long uint(byte[] d, Elem e) throws Mp4Info.Invalid {
        int len = e.dataEnd() - e.dataStart();
        if (e.unknown() || len < 1 || len > 8) {
            throw new Mp4Info.Invalid("uint");
        }
        long v = 0;
        for (int i = e.dataStart(); i < e.dataEnd(); i++) {
            v = (v << 8) | (d[i] & 0xff);
        }
        return v;
    }

    private static double floating(byte[] d, Elem e) throws Mp4Info.Invalid {
        int len = e.dataEnd() - e.dataStart();
        if (e.unknown() || (len != 4 && len != 8)) {
            throw new Mp4Info.Invalid("float");
        }
        java.nio.ByteBuffer b = java.nio.ByteBuffer.wrap(d, e.dataStart(), len);
        return len == 4 ? b.getFloat() : b.getDouble();
    }

    /** EBML eleman başlığı: kimlik (işaret biti korunur, en çok 4 bayt) + boyut (en çok 8 bayt). */
    private static Elem read(byte[] d, int p, int limit) throws Mp4Info.Invalid {
        if (p < 0 || p >= limit || limit > d.length) {
            throw new Mp4Info.Invalid("sinir");
        }
        int b0 = d[p] & 0xff;
        int idLen = Integer.numberOfLeadingZeros(b0) - 24 + 1;
        if (b0 == 0 || idLen > 4 || p + idLen >= limit) {
            throw new Mp4Info.Invalid("kimlik");
        }
        long id = 0;
        for (int i = 0; i < idLen; i++) {
            id = (id << 8) | (d[p + i] & 0xff);
        }
        int sp = p + idLen;
        int s0 = d[sp] & 0xff;
        int sLen = Integer.numberOfLeadingZeros(s0) - 24 + 1;
        if (s0 == 0 || sLen > 8 || sp + sLen > limit) {
            throw new Mp4Info.Invalid("boyut");
        }
        long size = s0 & (0xff >> sLen);
        boolean allOnes = size == (0xff >> sLen);
        for (int i = 1; i < sLen; i++) {
            int b = d[sp + i] & 0xff;
            size = (size << 8) | b;
            allOnes &= b == 0xff;
        }
        int dataStart = sp + sLen;
        if (allOnes) {
            return new Elem(id, dataStart, limit, true);
        }
        long endL = dataStart + size;
        if (size < 0 || endL > limit) {
            endL = limit; // kesik dosya: sinira kirp (Info/Tracks sigmazsa ayristirma sure bulamaz)
        }
        return new Elem(id, dataStart, (int) endL, false);
    }
}
