package edu.bingol.backend.media;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.MediaProperties;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

class ImageProcessorTest {

    private final ImageProcessor proc = new ImageProcessor(ImageFixtures.props());

    private static String code(Runnable r) {
        return assertThrows(ApiException.class, r::run).code();
    }

    private static BufferedImage decode(byte[] b) throws Exception {
        return ImageIO.read(new ByteArrayInputStream(b));
    }

    @Test
    void jpegAndPngAreReencodedAndScaled() throws Exception {
        ProcessedImage a = proc.process(ImageFixtures.encode(ImageFixtures.gradient(2000, 1000), "jpg"), ImageKind.AVATAR);
        assertEquals("image/jpeg", a.contentType());
        assertEquals(512, a.width());
        assertEquals(256, a.height());
        assertEquals(320, decode(a.thumb()).getWidth());
        ProcessedImage c = proc.process(ImageFixtures.encode(ImageFixtures.gradient(2000, 1000), "png"), ImageKind.COVER);
        assertEquals(1600, c.width());
        assertTrue(c.data().length <= 400 * 1024);
    }

    @Test
    void transparentPngStaysPng() {
        BufferedImage img = new BufferedImage(40, 40, BufferedImage.TYPE_INT_ARGB);
        img.setRGB(5, 5, 0x80FF0000);
        ProcessedImage p = proc.process(ImageFixtures.encode(img, "png"), ImageKind.AVATAR);
        assertEquals("image/png", p.contentType());
        assertEquals("png", p.ext());
    }

    @Test
    void exifAndGpsAreStrippedAndOrientationApplied() throws Exception {
        byte[] jpeg = ImageFixtures.encode(ImageFixtures.gradient(100, 40), "jpg");
        byte[] withExif = ImageFixtures.withExif(jpeg, 6); // 90 derece saat yonu
        assertTrue(ImageFixtures.contains(withExif, "SECRETGPS"), "fixture gecerli olmali");
        ProcessedImage p = proc.process(withExif, ImageKind.AVATAR);
        assertFalse(ImageFixtures.contains(p.data(), "SECRETGPS"));
        assertFalse(ImageFixtures.contains(p.data(), "Exif"));
        assertFalse(ImageFixtures.contains(p.thumb(), "SECRETGPS"));
        assertEquals(40, p.width()); // yon 6 => genislik/yukseklik yer degistirir
        assertEquals(100, p.height());
        BufferedImage out = decode(p.data());
        assertEquals(40, out.getWidth());
    }

    @Test
    void trailingPayloadAndPolyglotAreDropped() {
        byte[] png = ImageFixtures.encode(ImageFixtures.gradient(30, 30), "png");
        byte[] evil = new byte[png.length + 40];
        System.arraycopy(png, 0, evil, 0, png.length);
        byte[] js = "<script>alert(1)</script><?php evil() ?>".getBytes(StandardCharsets.US_ASCII);
        System.arraycopy(js, 0, evil, png.length, Math.min(js.length, 40));
        ProcessedImage p = proc.process(evil, ImageKind.AVATAR);
        assertFalse(ImageFixtures.contains(p.data(), "<script"));
        assertFalse(ImageFixtures.contains(p.data(), "<?php"));
    }

    @Test
    void nonImageFormatsAreRejectedByMagicBytes() {
        for (String s : new String[] {
                "<svg xmlns=\"http://www.w3.org/2000/svg\"><script>alert(1)</script></svg>",
                "GIF89a\u0001\u0000\u0001\u0000\u0000\u0000\u0000;;;;;;;;",
                "<html><script>alert(1)</script></html>",
                "GIF89a/*<script>alert(1)</script>*/=1;"}) {
            assertEquals("INVALID_FILE", code(() -> proc.process(s.getBytes(StandardCharsets.ISO_8859_1), ImageKind.AVATAR)), s);
        }
        // HEIC (ftyp kutusu)
        byte[] heic = new byte[64];
        System.arraycopy("\0\0\0\u0018ftypheic".getBytes(StandardCharsets.ISO_8859_1), 0, heic, 0, 12);
        assertEquals("INVALID_FILE", code(() -> proc.process(heic, ImageKind.AVATAR)));
        assertEquals("INVALID_FILE", code(() -> proc.process(new byte[3], ImageKind.AVATAR)));
    }

    @Test
    void corruptFileIsRejected() {
        byte[] garbage = new byte[2000];
        new java.util.Random(1).nextBytes(garbage);
        System.arraycopy(new byte[] {(byte) 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A}, 0, garbage, 0, 8);
        assertEquals("IMAGE_CORRUPT", code(() -> proc.process(garbage, ImageKind.AVATAR)));
        byte[] jpeg = ImageFixtures.encode(ImageFixtures.gradient(200, 200), "jpg");
        byte[] cut = java.util.Arrays.copyOf(jpeg, 30); // basliktan sonra kesik
        ApiException e = assertThrows(ApiException.class, () -> proc.process(cut, ImageKind.AVATAR));
        assertEquals(HttpStatus.BAD_REQUEST, e.status());
    }

    @Test
    void pixelBombIsRejectedBeforeDecoding() {
        byte[] bomb = ImageFixtures.pngBomb(20000, 20000); // 400 MP, dosya birkac yuz bayt
        assertTrue(bomb.length < 1000);
        assertEquals("IMAGE_TOO_MANY_PIXELS", code(() -> proc.process(bomb, ImageKind.COVER)));
        // sinir ayardan gelir: dusurulunce makul boyut da reddedilir
        ImageProcessor strict = new ImageProcessor(ImageFixtures.props(1000, null));
        byte[] ok = ImageFixtures.encode(ImageFixtures.gradient(100, 100), "png");
        assertEquals("IMAGE_TOO_MANY_PIXELS", assertThrows(ApiException.class,
                () -> strict.process(ok, ImageKind.AVATAR)).code());
        proc.process(ok, ImageKind.AVATAR);
    }

    @Test
    void webpIsDecodedAndReencoded() throws Exception {
        for (String b64 : new String[] {
                "UklGRhoAAABXRUJQVlA4TA0AAAAvAAAAEAcQERGIiP4HAA==", // kayipsiz 1x1
                "UklGRiIAAABXRUJQVlA4IBYAAAAwAQCdASoBAAEADsD+JaQAA3AAAAAA"}) { // kayipli 1x1
            ProcessedImage p = proc.process(Base64.getDecoder().decode(b64), ImageKind.AVATAR);
            assertEquals(1, p.width());
            assertTrue(p.data()[0] == (byte) 0xFF || p.data()[0] == (byte) 0x89);
        }
    }

    @Test
    void maxStoredBytesChangesBehaviour() throws Exception {
        byte[] src = ImageFixtures.encode(ImageFixtures.noise(512, 512, 7), "png");
        ProcessedImage loose = new ImageProcessor(ImageFixtures.props(0,
                new MediaProperties.Limits(5L << 20, 512, 5L << 20, 85))).process(src, ImageKind.AVATAR);
        ProcessedImage tight = new ImageProcessor(ImageFixtures.props(0,
                new MediaProperties.Limits(5L << 20, 512, 30L << 10, 85))).process(src, ImageKind.AVATAR);
        assertEquals(512, loose.width());
        assertTrue(loose.data().length > 30 * 1024, "gevsek sinirda dosya buyuk kalmali");
        assertTrue(tight.data().length <= 30 * 1024, "siki sinir ihlal edildi: " + tight.data().length);
        assertTrue(tight.width() < 512, "sigmak icin kucultulmeli");
        // hic sigmayacak sinir
        ApiException e = assertThrows(ApiException.class, () -> new ImageProcessor(ImageFixtures.props(0,
                new MediaProperties.Limits(5L << 20, 512, 100, 85))).process(src, ImageKind.AVATAR));
        assertEquals("IMAGE_TOO_COMPLEX", e.code());
        assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, e.status());
    }

    @Test
    void jpegQualityAndDimensionSettingsAreHonoured() {
        byte[] src = ImageFixtures.encode(ImageFixtures.noise(300, 300, 3), "png");
        long q95 = new ImageProcessor(ImageFixtures.props(0, new MediaProperties.Limits(5L << 20, 512, 5L << 20, 95)))
                .process(src, ImageKind.AVATAR).data().length;
        long q30 = new ImageProcessor(ImageFixtures.props(0, new MediaProperties.Limits(5L << 20, 512, 5L << 20, 30)))
                .process(src, ImageKind.AVATAR).data().length;
        assertTrue(q30 < q95);
        ProcessedImage small = new ImageProcessor(ImageFixtures.props(0,
                new MediaProperties.Limits(5L << 20, 128, 5L << 20, 85))).process(src, ImageKind.AVATAR);
        assertEquals(128, small.width());
        assertNotEquals(300, small.width());
    }

    @Test
    void concurrentProcessingIsSafe() throws Exception {
        byte[] src = ImageFixtures.encode(ImageFixtures.noise(600, 400, 9), "jpg");
        ExecutorService ex = Executors.newFixedThreadPool(16);
        List<Future<ProcessedImage>> fs = new ArrayList<>();
        for (int i = 0; i < 32; i++) {
            fs.add(ex.submit(() -> proc.process(src, ImageKind.AVATAR)));
        }
        byte[] first = fs.get(0).get().data();
        for (Future<ProcessedImage> f : fs) {
            assertTrue(java.util.Arrays.equals(first, f.get().data()), "ayni girdi ayni cikti (deterministik)");
        }
        ex.shutdown();
    }
}
