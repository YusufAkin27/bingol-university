package edu.bingol.backend.media;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.MediaProperties;
import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Iterator;
import java.util.concurrent.Semaphore;
import java.util.concurrent.TimeUnit;
import javax.imageio.IIOImage;
import javax.imageio.ImageIO;
import javax.imageio.ImageReadParam;
import javax.imageio.ImageReader;
import javax.imageio.ImageWriteParam;
import javax.imageio.ImageWriter;
import javax.imageio.stream.ImageInputStream;
import javax.imageio.stream.MemoryCacheImageOutputStream;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/**
 * Guvenli gorsel isleme: sihirli bayt dogrulama -> baslik okuyup piksel siniri -> cozme -> EXIF yonu uygulama ->
 * kucultme -> YENIDEN KODLAMA (EXIF/GPS/ICC/yorum/eklenen veri atilir) -> kucuk resim.
 * Cikti yalniz JPEG (opak) veya PNG (gercek seffaflik varsa). Hic bir girdi baytı ciktiya aynen gecmez.
 */
@Component
public class ImageProcessor {

    private static final Logger log = LoggerFactory.getLogger(ImageProcessor.class);
    private static final int MIN_QUALITY = 40;
    private static final int MIN_EDGE = 64;
    private static final int MAX_DIMENSION = 30_000;

    private final MediaProperties props;
    private final long maxPixels;
    private final Semaphore slots;

    public ImageProcessor(MediaProperties props) {
        this.props = props;
        this.maxPixels = props.maxPixels();
        this.slots = new Semaphore(props.concurrency(), true);
    }

    /** Baytlari dogrular ve isler. Gecersizse {@link ApiException} (400/413/503) firlatir. */
    public ProcessedImage process(byte[] data, ImageKind kind) {
        return process(data, kind, 0);
    }

    /** `dimCap` > 0 ise uzun kenar bu degerle (ve tur sinirinin kucugu ile) sinirlanir (ornek: video posteri 720 px). */
    public ProcessedImage process(byte[] data, ImageKind kind, int dimCap) {
        String format = detect(data);
        if (format == null) {
            throw MediaUploads.invalid();
        }
        acquire();
        try {
            return doProcess(data, format, kind, dimCap);
        } finally {
            slots.release();
        }
    }

    private void acquire() {
        try {
            if (!slots.tryAcquire(15, TimeUnit.SECONDS)) {
                throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "MEDIA_BUSY",
                        "Görsel işleme şu anda yoğun. Lütfen tekrar deneyin.");
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "MEDIA_BUSY",
                    "Görsel işleme şu anda yoğun. Lütfen tekrar deneyin.");
        }
    }

    /** Sihirli baytlardan biçim: jpeg | png | webp; baska her sey (SVG, GIF, HEIC, HTML...) null. */
    static String detect(byte[] d) {
        if (d == null || d.length < 12) {
            return null;
        }
        if ((d[0] & 0xFF) == 0xFF && (d[1] & 0xFF) == 0xD8 && (d[2] & 0xFF) == 0xFF) {
            return "jpeg";
        }
        if ((d[0] & 0xFF) == 0x89 && d[1] == 'P' && d[2] == 'N' && d[3] == 'G'
                && d[4] == 0x0D && d[5] == 0x0A && d[6] == 0x1A && d[7] == 0x0A) {
            return "png";
        }
        if (d[0] == 'R' && d[1] == 'I' && d[2] == 'F' && d[3] == 'F'
                && d[8] == 'W' && d[9] == 'E' && d[10] == 'B' && d[11] == 'P') {
            return "webp";
        }
        return null;
    }

    private ProcessedImage doProcess(byte[] data, String format, ImageKind kind, int dimCap) {
        ImageReader reader = null;
        try (ImageInputStream in = ImageIO.createImageInputStream(new ByteArrayInputStream(data))) {
            reader = findReader(format, in);
            if (reader == null) {
                log.warn("Gorsel cozucu yok: {}", format);
                throw MediaUploads.invalid();
            }
            reader.setInput(in, true, true);
            int w = reader.getWidth(0);
            int h = reader.getHeight(0);
            if (w <= 0 || h <= 0 || w > MAX_DIMENSION || h > MAX_DIMENSION || (long) w * h > maxPixels) {
                String mp = String.valueOf(maxPixels / 1_000_000);
                throw new ApiException(HttpStatus.BAD_REQUEST, "IMAGE_TOO_MANY_PIXELS",
                        "Görsel çok büyük (en fazla " + mp + " megapiksel).", mp);
            }
            // Cok buyuk goruntuyu cozerken bellek harcamamak icin kaynak ornekleme (hedefin en az 2 kati kalir)
            MediaProperties.Limits lim = props.limits(kind);
            int maxDim = dimCap > 0 ? Math.min(dimCap, lim.maxDimension()) : lim.maxDimension();
            ImageReadParam param = reader.getDefaultReadParam();
            int sub = Math.max(1, Math.max(w, h) / (maxDim * 2));
            if (sub > 1) {
                param.setSourceSubsampling(sub, sub, 0, 0);
            }
            BufferedImage src = reader.read(0, param);
            if (src == null) {
                throw corrupt();
            }
            int orientation = "jpeg".equals(format) ? ExifOrientation.read(data) : 1;
            BufferedImage base = orient(scaleTo(toArgb(src), maxDim), orientation);
            boolean alpha = hasTransparency(base);
            // Sikistirma dongusu: kaliteyi kademeli dusur; sigmazsa boyutu %15 kucult ve yeniden dene
            BufferedImage main = base;
            byte[] out = null;
            for (int round = 0; round < 12 && out == null; round++) {
                for (int q = lim.jpegQuality(); ; q -= 10) {
                    int qq = Math.max(q, MIN_QUALITY);
                    byte[] enc = encode(main, alpha, qq / 100f);
                    if (enc.length <= lim.maxStoredBytes()) {
                        out = enc;
                        break;
                    }
                    if (alpha || qq == MIN_QUALITY) { // PNG'de kalite ayari yok
                        break;
                    }
                }
                if (out == null) {
                    int nw = (int) (main.getWidth() * 0.85);
                    int nh = (int) (main.getHeight() * 0.85);
                    if (Math.min(nw, nh) < MIN_EDGE) {
                        break;
                    }
                    main = scaleTo(main, Math.max(nw, nh));
                }
            }
            if (out == null) {
                throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "IMAGE_TOO_COMPLEX",
                        "Görsel yeterince sıkıştırılamadı. Daha basit veya küçük bir görsel deneyin.");
            }
            BufferedImage thumb = scaleTo(main, props.thumbDimension());
            return new ProcessedImage(out, encode(thumb, alpha, 0.8f), main.getWidth(), main.getHeight(),
                    alpha ? "image/png" : "image/jpeg", alpha ? "png" : "jpg");
        } catch (ApiException e) {
            throw e;
        } catch (IOException | RuntimeException e) {
            // Bozuk/desteklenmeyen (ornek CMYK) dosya: ayrintiyi istemciye sizdirma
            log.debug("Gorsel islenemedi: {}", e.toString());
            throw corrupt();
        } finally {
            if (reader != null) {
                reader.dispose();
            }
        }
    }

    private static ImageReader findReader(String format, ImageInputStream in) {
        Iterator<ImageReader> it = ImageIO.getImageReaders(in);
        while (it.hasNext()) {
            ImageReader r = it.next();
            // Yalniz beklenen biciminin cozucusu: baytlar baska bicim gibi davranamaz
            for (String name : r.getOriginatingProvider().getFormatNames()) {
                if (name.equalsIgnoreCase(format) || (format.equals("jpeg") && name.equalsIgnoreCase("jpg"))) {
                    return r;
                }
            }
            r.dispose();
        }
        return null;
    }

    private static ApiException corrupt() {
        return new ApiException(HttpStatus.BAD_REQUEST, "IMAGE_CORRUPT", "Görsel dosyası okunamadı.");
    }

    private static BufferedImage toArgb(BufferedImage src) {
        if (src.getType() == BufferedImage.TYPE_INT_ARGB) {
            return src;
        }
        BufferedImage out = new BufferedImage(src.getWidth(), src.getHeight(), BufferedImage.TYPE_INT_ARGB);
        Graphics2D g = out.createGraphics();
        g.drawImage(src, 0, 0, null);
        g.dispose();
        return out;
    }

    /** Uzun kenar `edge`den buyukse oranla kucultur (adim adim yariya bolerek: kalite + hiz). */
    static BufferedImage scaleTo(BufferedImage img, int edge) {
        int w = img.getWidth();
        int h = img.getHeight();
        int longest = Math.max(w, h);
        if (longest <= edge) {
            return img;
        }
        double ratio = (double) edge / longest;
        int tw = Math.max(1, (int) Math.round(w * ratio));
        int th = Math.max(1, (int) Math.round(h * ratio));
        BufferedImage cur = img;
        while (cur.getWidth() / 2 >= tw && cur.getHeight() / 2 >= th) {
            cur = resize(cur, cur.getWidth() / 2, cur.getHeight() / 2);
        }
        return resize(cur, tw, th);
    }

    private static BufferedImage resize(BufferedImage src, int w, int h) {
        BufferedImage out = new BufferedImage(w, h, BufferedImage.TYPE_INT_ARGB);
        Graphics2D g = out.createGraphics();
        g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BILINEAR);
        g.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
        g.drawImage(src, 0, 0, w, h, null);
        g.dispose();
        return out;
    }

    /** EXIF yonunu (1..8) piksellere uygular; EXIF atildigi icin foto aksi halde yan donerdi. */
    static BufferedImage orient(BufferedImage src, int o) {
        if (o < 2 || o > 8) {
            return src;
        }
        int w = src.getWidth();
        int h = src.getHeight();
        boolean swap = o >= 5;
        BufferedImage out = new BufferedImage(swap ? h : w, swap ? w : h, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                int dx;
                int dy;
                switch (o) {
                    case 2 -> { dx = w - 1 - x; dy = y; }
                    case 3 -> { dx = w - 1 - x; dy = h - 1 - y; }
                    case 4 -> { dx = x; dy = h - 1 - y; }
                    case 5 -> { dx = y; dy = x; }
                    case 6 -> { dx = h - 1 - y; dy = x; }
                    case 7 -> { dx = h - 1 - y; dy = w - 1 - x; }
                    default -> { dx = y; dy = w - 1 - x; }
                }
                out.setRGB(dx, dy, src.getRGB(x, y));
            }
        }
        return out;
    }

    private static boolean hasTransparency(BufferedImage img) {
        int w = img.getWidth();
        int h = img.getHeight();
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                if ((img.getRGB(x, y) >>> 24) != 0xFF) {
                    return true;
                }
            }
        }
        return false;
    }

    private static byte[] encode(BufferedImage argb, boolean png, float quality) {
        try {
            ByteArrayOutputStream bos = new ByteArrayOutputStream();
            if (png) {
                if (!ImageIO.write(argb, "png", bos)) {
                    throw new IOException("png yazici yok");
                }
                return bos.toByteArray();
            }
            // JPEG seffaflik tasimaz: beyaz zemine yapistir
            BufferedImage rgb = new BufferedImage(argb.getWidth(), argb.getHeight(), BufferedImage.TYPE_INT_RGB);
            Graphics2D g = rgb.createGraphics();
            g.setColor(Color.WHITE);
            g.fillRect(0, 0, rgb.getWidth(), rgb.getHeight());
            g.drawImage(argb, 0, 0, null);
            g.dispose();
            ImageWriter writer = ImageIO.getImageWritersByFormatName("jpeg").next();
            try (MemoryCacheImageOutputStream out = new MemoryCacheImageOutputStream(bos)) {
                ImageWriteParam wp = writer.getDefaultWriteParam();
                wp.setCompressionMode(ImageWriteParam.MODE_EXPLICIT);
                wp.setCompressionQuality(quality);
                writer.setOutput(out);
                // Metaveri verilmez (null): yalniz JFIF basligi yazilir
                writer.write(null, new IIOImage(rgb, null, null), wp);
            } finally {
                writer.dispose();
            }
            return bos.toByteArray();
        } catch (IOException e) {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "STORAGE_UNAVAILABLE",
                    "Dosya şu anda kaydedilemiyor.");
        }
    }
}
