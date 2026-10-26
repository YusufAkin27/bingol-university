package edu.bingol.backend.media;

import edu.bingol.backend.config.MediaProperties;
import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.Random;
import java.util.zip.CRC32;
import java.util.zip.Deflater;
import javax.imageio.ImageIO;

/** Test gorselleri ve saldiri dosyalari uretir. */
final class ImageFixtures {

    private ImageFixtures() {
    }

    static MediaProperties props() {
        return props(0, null);
    }

    /** maxPixels ve avatar sinirlari ezilmis ayarlar. */
    static MediaProperties props(long maxPixels, MediaProperties.Limits avatar) {
        return new MediaProperties(maxPixels, 4, 0, 0, 0, null, null, null, null, true, avatar, null, null, null);
    }

    static BufferedImage gradient(int w, int h) {
        BufferedImage img = new BufferedImage(w, h, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = img.createGraphics();
        for (int x = 0; x < w; x++) {
            g.setColor(new Color(x * 255 / Math.max(1, w - 1), 80, 200 - (x * 100 / Math.max(1, w))));
            g.drawLine(x, 0, x, h);
        }
        g.dispose();
        return img;
    }

    /** Sikistirilmasi zor gurultulu gorsel. */
    static BufferedImage noise(int w, int h, long seed) {
        Random r = new Random(seed);
        BufferedImage img = new BufferedImage(w, h, BufferedImage.TYPE_INT_RGB);
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                img.setRGB(x, y, r.nextInt(0xFFFFFF));
            }
        }
        return img;
    }

    static byte[] encode(BufferedImage img, String fmt) {
        try {
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            ImageIO.write(img, fmt, out);
            return out.toByteArray();
        } catch (IOException e) {
            throw new IllegalStateException(e);
        }
    }

    /** JPEG'e SOI'den hemen sonra APP1/Exif ekler: yon etiketi + "SECRETGPS" bicimli sahte GPS metni. */
    static byte[] withExif(byte[] jpeg, int orientation) {
        byte[] marker = "SECRETGPS-41.0082N-28.9784E".getBytes(StandardCharsets.US_ASCII);
        ByteBuffer tiff = ByteBuffer.allocate(8 + 2 + 12 + 4 + marker.length);
        tiff.put((byte) 'M').put((byte) 'M').putShort((short) 42).putInt(8);
        tiff.putShort((short) 1);
        tiff.putShort((short) 0x0112).putShort((short) 3).putInt(1).putShort((short) orientation).putShort((short) 0);
        tiff.putInt(0);
        tiff.put(marker);
        byte[] t = tiff.array();
        ByteBuffer app1 = ByteBuffer.allocate(2 + 2 + 6 + t.length);
        app1.put((byte) 0xFF).put((byte) 0xE1).putShort((short) (2 + 6 + t.length));
        app1.put(new byte[] {'E', 'x', 'i', 'f', 0, 0}).put(t);
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        out.write(jpeg, 0, 2);
        out.writeBytes(app1.array());
        out.write(jpeg, 2, jpeg.length - 2);
        return out.toByteArray();
    }

    /** Yalnizca baslik + bos (gri) veri iceren PNG: ilan edilen boyut buyuk, dosya kucuk (boyut bombasi). */
    static byte[] pngBomb(int w, int h) {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        out.writeBytes(new byte[] {(byte) 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A});
        ByteBuffer ihdr = ByteBuffer.allocate(13).putInt(w).putInt(h).put((byte) 8).put((byte) 0)
                .put((byte) 0).put((byte) 0).put((byte) 0);
        chunk(out, "IHDR", ihdr.array());
        Deflater d = new Deflater(9);
        d.setInput(new byte[1024]);
        d.finish();
        byte[] buf = new byte[2048];
        int n = d.deflate(buf);
        byte[] z = new byte[n];
        System.arraycopy(buf, 0, z, 0, n);
        chunk(out, "IDAT", z);
        chunk(out, "IEND", new byte[0]);
        return out.toByteArray();
    }

    private static void chunk(ByteArrayOutputStream out, String type, byte[] data) {
        byte[] t = type.getBytes(StandardCharsets.US_ASCII);
        out.writeBytes(ByteBuffer.allocate(4).putInt(data.length).array());
        out.writeBytes(t);
        out.writeBytes(data);
        CRC32 crc = new CRC32();
        crc.update(t);
        crc.update(data);
        out.writeBytes(ByteBuffer.allocate(4).putInt((int) crc.getValue()).array());
    }

    static boolean contains(byte[] hay, String needle) {
        byte[] n = needle.getBytes(StandardCharsets.US_ASCII);
        outer:
        for (int i = 0; i <= hay.length - n.length; i++) {
            for (int j = 0; j < n.length; j++) {
                if (hay[i + j] != n[j]) {
                    continue outer;
                }
            }
            return true;
        }
        return false;
    }
}
