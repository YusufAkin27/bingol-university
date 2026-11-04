package edu.bingol.backend.media;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import org.junit.jupiter.api.Test;

/** WebM ve ftyp marka denetimi (saf birim testleri). */
class WebmInfoTest {

    @Test
    void parsesDurationAndSize() throws Exception {
        WebmInfo.Info i = WebmInfo.parse(WebmFixtures.webm(12.5, 640, 360, 100));
        assertEquals(12_500, i.durationMs());
        assertEquals(640, i.width());
        assertEquals(360, i.height());
    }

    @Test
    void rejectsNonWebmAndBrokenStructures() {
        assertFalse(WebmInfo.hasMagic(new byte[32]));
        assertFalse(WebmInfo.hasMagic(null));
        assertThrows(Mp4Info.Invalid.class, () -> WebmInfo.parse(new byte[64]));
        // DocType matroska: kabul edilmez (yalniz webm)
        assertThrows(Mp4Info.Invalid.class, () -> WebmInfo.parse(WebmFixtures.webm(5, 320, 240, 10, true, "matroska")));
        // sure yok (ornegin MediaRecorder canli kaydi): sure dogrulanamaz -> ret
        assertThrows(Mp4Info.Invalid.class, () -> WebmInfo.parse(WebmFixtures.webm(5, 320, 240, 10, false, "webm")));
        // kesik dosya: Info/Tracks sigmaz
        byte[] full = WebmFixtures.webm(5, 320, 240, 10);
        assertThrows(Mp4Info.Invalid.class, () -> WebmInfo.parse(Arrays.copyOf(full, 40)));
    }

    @Test
    void neverThrowsUnexpectedlyOnGarbageAfterMagic() {
        byte[] g = new byte[256];
        Arrays.fill(g, (byte) 0xFF);
        g[0] = 0x1A;
        g[1] = 0x45;
        g[2] = (byte) 0xDF;
        g[3] = (byte) 0xA3;
        // yalniz Mp4Info.Invalid ya da basarili sonuc; baska istisna (tasma vb.) olmamali
        try {
            WebmInfo.parse(g);
        } catch (Mp4Info.Invalid expected) {
            assertTrue(true);
        }
    }

    @Test
    void ftypBrandsSeparateVideoFromImagesAndAudio() {
        assertTrue(Mp4Info.isVideoBrand(ftyp("isom")));
        assertTrue(Mp4Info.isVideoBrand(ftyp("mp42")));
        assertTrue(Mp4Info.isVideoBrand(ftyp("qt  ")));
        assertFalse(Mp4Info.isVideoBrand(ftyp("heic")), "HEIC bir goruntudur");
        assertFalse(Mp4Info.isVideoBrand(ftyp("avif")));
        assertFalse(Mp4Info.isVideoBrand(ftyp("M4A ")), "M4A ses");
        assertEquals("qt  ", Mp4Info.majorBrand(ftyp("qt  ")));
    }

    private static byte[] ftyp(String brand) {
        byte[] d = new byte[24];
        d[3] = 24;
        System.arraycopy("ftyp".getBytes(StandardCharsets.US_ASCII), 0, d, 4, 4);
        System.arraycopy(brand.getBytes(StandardCharsets.US_ASCII), 0, d, 8, 4);
        return d;
    }
}
