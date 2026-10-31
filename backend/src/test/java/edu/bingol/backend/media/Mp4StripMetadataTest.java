package edu.bingol.backend.media;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.ByteArrayOutputStream;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.Test;

/** T-038: sohbet videosundaki GPS/cihaz meta kutulari etkisizlestirilir; boyut ve sure degismez. */
class Mp4StripMetadataTest {

    private static byte[] box(String type, byte[]... payload) {
        int len = 8;
        for (byte[] p : payload) {
            len += p.length;
        }
        ByteBuffer b = ByteBuffer.allocate(len);
        b.putInt(len);
        b.put(type.getBytes(StandardCharsets.ISO_8859_1));
        for (byte[] p : payload) {
            b.put(p);
        }
        return b.array();
    }

    private static byte[] cat(byte[]... parts) {
        ByteArrayOutputStream o = new ByteArrayOutputStream();
        for (byte[] p : parts) {
            o.writeBytes(p);
        }
        return o.toByteArray();
    }

    private static byte[] mvhd() {
        ByteBuffer b = ByteBuffer.allocate(100);
        b.putInt(0);        // surum + bayraklar
        b.putInt(0);        // olusturma
        b.putInt(0);        // degistirme
        b.putInt(1000);     // timescale
        b.putInt(5000);     // sure = 5 sn
        return box("mvhd", b.array());
    }

    private static byte[] sample(boolean metaFirst) {
        byte[] gps = "+39.9208+032.8541/".getBytes(StandardCharsets.ISO_8859_1);
        byte[] xyz = box("©xyz", gps);
        byte[] udta = box("udta", xyz);
        byte[] meta = box("meta", new byte[] {0, 0, 0, 0}, "com.apple.quicktime.location.ISO6709".getBytes(StandardCharsets.ISO_8859_1));
        byte[] trak = box("trak", box("udta", "model=Pixel".getBytes(StandardCharsets.ISO_8859_1)));
        byte[] moov = box("moov", mvhd(), udta, meta, trak);
        byte[] ftyp = box("ftyp", "isom".getBytes(StandardCharsets.ISO_8859_1), new byte[] {0, 0, 2, 0},
                "isom".getBytes(StandardCharsets.ISO_8859_1));
        byte[] mdat = box("mdat", "VIDEODATA".getBytes(StandardCharsets.ISO_8859_1));
        byte[] xmp = box("uuid", "XMPDATAXMPDATA".getBytes(StandardCharsets.ISO_8859_1));
        return metaFirst ? cat(ftyp, moov, mdat, xmp) : cat(ftyp, mdat, moov, xmp);
    }

    private static boolean contains(byte[] hay, String needle) {
        return new String(hay, StandardCharsets.ISO_8859_1).contains(needle);
    }

    @Test
    void gpsAndDeviceBoxesAreWipedWhileSizeAndDurationStay() throws Exception {
        for (boolean moovFirst : new boolean[] {true, false}) {
            byte[] in = sample(moovFirst);
            assertTrue(contains(in, "+39.9208"));
            assertTrue(contains(in, "Pixel"));

            Mp4Info.Stripped out = Mp4Info.stripMetadata(in);

            assertEquals(in.length, out.data().length); // chunk ofsetleri kaymaz
            assertFalse(contains(out.data(), "+39.9208"));
            assertFalse(contains(out.data(), "Pixel"));
            assertFalse(contains(out.data(), "ISO6709"));
            assertFalse(contains(out.data(), "XMPDATA"));
            assertTrue(contains(out.data(), "VIDEODATA")); // medya verisi korunur
            assertTrue(out.wiped() >= 4); // udta, meta, trak/udta, uuid
            Mp4Info.Info info = Mp4Info.parse(out.data()); // hala gecerli: sure okunur
            assertEquals(5000, info.durationMs());
        }
    }

    @Test
    void inputIsNotMutatedAndBrokenInputPassesThrough() {
        byte[] in = sample(true);
        byte[] copy = in.clone();
        Mp4Info.stripMetadata(in);
        assertArrayEquals(copy, in);

        byte[] junk = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
        assertEquals(0, Mp4Info.stripMetadata(junk).wiped());
    }
}
