package edu.bingol.backend.media;

import java.io.ByteArrayOutputStream;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;

/** Testler için sentetik, küçük WebM kabı: EBML(DocType) + Segment(Info(süre) + Tracks(video) + Cluster). Oynatılabilir DEĞİLDİR. */
public final class WebmFixtures {

    private WebmFixtures() {
    }

    private static byte[] cat(byte[]... parts) {
        ByteArrayOutputStream o = new ByteArrayOutputStream();
        for (byte[] p : parts) {
            o.writeBytes(p);
        }
        return o.toByteArray();
    }

    private static byte[] id(long v) {
        int len = v > 0xFFFFFFL ? 4 : v > 0xFFFFL ? 3 : v > 0xFFL ? 2 : 1;
        byte[] b = new byte[len];
        for (int i = 0; i < len; i++) {
            b[i] = (byte) (v >> (8 * (len - 1 - i)));
        }
        return b;
    }

    /** Sekiz baytlık boyut: 0x01 + 7 bayt. */
    private static byte[] size(long n) {
        ByteBuffer b = ByteBuffer.allocate(8);
        b.putLong(n | (1L << 56));
        return b.array();
    }

    static byte[] el(long id, byte[] payload) {
        return cat(id(id), size(payload.length), payload);
    }

    private static byte[] uint(long id, long v) {
        return el(id, ByteBuffer.allocate(8).putLong(v).array());
    }

    /** Süre ms (TimecodeScale 1.000.000 ns); duration false ise Info'da süre yoktur (canlı kayıt benzeri). */
    public static byte[] webm(double seconds, int width, int height, int clusterBytes, boolean duration,
                              String docType) {
        byte[] header = el(0x1A45DFA3L, el(0x4282, docType.getBytes(StandardCharsets.US_ASCII)));
        byte[] info = duration
                ? el(0x1549A966L, cat(uint(0x2AD7B1L, 1_000_000L),
                        el(0x4489, ByteBuffer.allocate(8).putDouble(seconds * 1000.0).array())))
                : el(0x1549A966L, uint(0x2AD7B1L, 1_000_000L));
        byte[] video = el(0xE0, cat(uint(0xB0, width), uint(0xBA, height)));
        byte[] tracks = el(0x1654AE6BL, el(0xAE, cat(uint(0x83, 1), video)));
        byte[] cluster = el(0x1F43B675L, new byte[clusterBytes]);
        return cat(header, el(0x18538067L, cat(info, tracks, cluster)));
    }

    public static byte[] webm(double seconds, int width, int height, int clusterBytes) {
        return webm(seconds, width, height, clusterBytes, true, "webm");
    }
}
