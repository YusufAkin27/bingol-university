package edu.bingol.backend.messaging.media;

import java.io.ByteArrayOutputStream;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.Random;

/** Testler icin sentetik, kucuk MP4 kap yapisi: ftyp + mdat (rastgele) + moov(mvhd + trak(tkhd)). Oynatilabilir DEGILDIR. */
public final class Mp4Fixtures {

    private Mp4Fixtures() {
    }

    static byte[] box(String type, byte[] payload) {
        ByteBuffer b = ByteBuffer.allocate(8 + payload.length);
        b.putInt(8 + payload.length).put(type.getBytes(StandardCharsets.US_ASCII)).put(payload);
        return b.array();
    }

    static byte[] cat(byte[]... parts) {
        ByteArrayOutputStream o = new ByteArrayOutputStream();
        for (byte[] p : parts) {
            o.writeBytes(p);
        }
        return o.toByteArray();
    }

    /** `version` 0 ya da 1 mvhd/tkhd; sure = durationTicks / timescale. */
    public static byte[] mp4(int version, long timescale, long durationTicks, int width, int height, int mdatBytes) {
        byte[] ftyp = box("ftyp", cat("isom".getBytes(StandardCharsets.US_ASCII), new byte[4],
                "isomiso2".getBytes(StandardCharsets.US_ASCII)));
        byte[] mdat = new byte[mdatBytes];
        new Random(42).nextBytes(mdat);
        ByteBuffer mv = ByteBuffer.allocate(version == 1 ? 112 : 100);
        mv.put((byte) version).put(new byte[3]);
        if (version == 1) {
            mv.putLong(0).putLong(0).putInt((int) timescale).putLong(durationTicks);
        } else {
            mv.putInt(0).putInt(0).putInt((int) timescale).putInt((int) durationTicks);
        }
        ByteBuffer tk = ByteBuffer.allocate(version == 1 ? 96 : 84);
        tk.put((byte) version).put(new byte[3]);
        if (version == 1) {
            tk.putLong(0).putLong(0).putInt(1).putInt(0).putLong(durationTicks); // 4+8+8+4+4+8 = 36
            tk.position(36 + 8 + 8 + 36); // reserved, layer.., matrix
        } else {
            tk.putInt(0).putInt(0).putInt(1).putInt(0).putInt((int) durationTicks); // 24
            tk.position(24 + 8 + 8 + 36);
        }
        tk.putInt(width << 16).putInt(height << 16);
        byte[] moov = box("moov", cat(box("mvhd", mv.array()), box("trak", box("tkhd", tk.array()))));
        return cat(ftyp, box("mdat", mdat), moov);
    }

    public static byte[] mp4(double seconds, int width, int height, int mdatBytes) {
        return mp4(0, 1000, Math.round(seconds * 1000), width, height, mdatBytes);
    }
}
