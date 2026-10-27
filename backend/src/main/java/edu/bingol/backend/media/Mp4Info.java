package edu.bingol.backend.media;

import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;

/**
 * Minimal MP4/ISO-BMFF ust veri ayristirici (ffmpeg bagimliligi yok). Yalnizca: ilk kutu `ftyp` mi, `moov/mvhd`
 * ile sure (ms), ilk gorsel izin `tkhd` boyutlari. Bozuk / sinir disi yapida {@link Invalid} firlatir.
 * Icerik (codec) DOGRULANMAZ; yalniz kap yapisi denetlenir. Oynatma istemcide yapilir.
 */
public final class Mp4Info {

    /** `width`/`height` bilinmiyorsa 0. */
    public record Info(long durationMs, int width, int height) {}

    public static final class Invalid extends Exception {
        public Invalid(String m) {
            super(m);
        }
    }

    private static final int MAX_DEPTH_BOXES = 4096;

    private Mp4Info() {
    }

    /** Ilk 12 bayt: ??? ?? 'ftyp' (kutu boyutu >= 16). */
    public static boolean hasFtyp(byte[] d) {
        return d != null && d.length >= 16 && d[4] == 'f' && d[5] == 't' && d[6] == 'y' && d[7] == 'p';
    }

    public static Info parse(byte[] d) throws Invalid {
        if (!hasFtyp(d)) {
            throw new Invalid("ftyp yok");
        }
        ByteBuffer b = ByteBuffer.wrap(d);
        long[] moov = findBox(b, 0, d.length, "moov");
        if (moov == null) {
            throw new Invalid("moov yok");
        }
        long[] mvhd = findBox(b, (int) moov[0], (int) moov[1], "mvhd");
        if (mvhd == null) {
            throw new Invalid("mvhd yok");
        }
        int p = (int) mvhd[0];
        int end = (int) mvhd[1];
        if (end - p < 20) {
            throw new Invalid("mvhd kisa");
        }
        int version = b.get(p) & 0xff;
        long timescale;
        long duration;
        if (version == 1) {
            if (end - p < 32) {
                throw new Invalid("mvhd kisa");
            }
            timescale = b.getInt(p + 20) & 0xffffffffL;
            duration = b.getLong(p + 24);
        } else if (version == 0) {
            timescale = b.getInt(p + 12) & 0xffffffffL;
            duration = b.getInt(p + 16) & 0xffffffffL;
        } else {
            throw new Invalid("mvhd surumu");
        }
        if (timescale <= 0 || duration < 0 || duration == Long.MAX_VALUE) {
            throw new Invalid("sure gecersiz");
        }
        long ms = Math.round(duration * 1000.0 / timescale);
        int w = 0;
        int h = 0;
        // Ilk genisligi sifirdan buyuk iz (ses izlerinde 0)
        int pos = (int) moov[0];
        int moovEnd = (int) moov[1];
        int guard = 0;
        while (pos + 8 <= moovEnd && guard++ < MAX_DEPTH_BOXES) {
            long[] box = boxAt(b, pos, moovEnd);
            if (box == null) {
                break;
            }
            if (type(b, pos).equals("trak")) {
                long[] tkhd = findBox(b, (int) box[0], (int) box[1], "tkhd");
                if (tkhd != null) {
                    int t = (int) tkhd[0];
                    int tv = b.get(t) & 0xff;
                    int off = tv == 1 ? 88 : 76;
                    if (tkhd[1] - t >= off + 8) {
                        int tw = b.getInt(t + off) >>> 16;
                        int th = b.getInt(t + off + 4) >>> 16;
                        if (tw > 0 && th > 0) {
                            w = tw;
                            h = th;
                            break;
                        }
                    }
                }
            }
            pos = (int) box[1];
        }
        return new Info(ms, w, h);
    }

    /** [yukBaslangici, kutuSonu] ya da yoksa null. Alt kutu araması `from..to` icinde dolasir. */
    private static long[] findBox(ByteBuffer b, int from, int to, String wanted) throws Invalid {
        int pos = from;
        int guard = 0;
        while (pos + 8 <= to) {
            if (guard++ > MAX_DEPTH_BOXES) {
                throw new Invalid("cok fazla kutu");
            }
            long[] box = boxAt(b, pos, to);
            if (box == null) {
                throw new Invalid("kutu bozuk");
            }
            if (type(b, pos).equals(wanted)) {
                return box;
            }
            pos = (int) box[1];
        }
        return null;
    }

    /** `pos`taki kutunun [yukBaslangici, kutuSonu]; boyut gecersizse null. */
    private static long[] boxAt(ByteBuffer b, int pos, int limit) {
        long size = b.getInt(pos) & 0xffffffffL;
        int header = 8;
        if (size == 1) {
            if (pos + 16 > limit) {
                return null;
            }
            size = b.getLong(pos + 8);
            header = 16;
        } else if (size == 0) {
            size = limit - pos; // sona kadar
        }
        if (size < header || pos + size > limit) {
            return null;
        }
        return new long[] {pos + header, pos + size};
    }

    private static String type(ByteBuffer b, int pos) {
        byte[] t = new byte[4];
        b.get(pos + 4, t);
        return new String(t, StandardCharsets.ISO_8859_1);
    }
}
