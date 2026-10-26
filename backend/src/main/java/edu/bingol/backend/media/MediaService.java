package edu.bingol.backend.media;

import edu.bingol.backend.common.storage.LocalFileStorage;
import edu.bingol.backend.config.MediaProperties;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Duration;
import java.time.Instant;
import java.util.HexFormat;
import java.util.List;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

/**
 * Herkese acik gorsel hatti: dogrula -> yeniden kodla/sikistir -> icerik ozetiyle adlandir -> diske yaz.
 * <pre>
 *   StoredImage img = media.storeImage(file, ImageKind.AVATAR);   // img.url(), img.thumbUrl()
 *   ...DB'ye img.url() yaz...
 *   media.release(eskiUrl);                                       // artik kullanilmiyorsa siler
 * </pre>
 * Ayni icerik ayni dosyadir (tekrar yazilmaz); bu yuzden dosya silme yalniz {@link #release} ile, referans
 * denetimiyle yapilir.
 */
@Service
public class MediaService {

    private static final Logger log = LoggerFactory.getLogger(MediaService.class);
    private static final Pattern PUBLIC_URL = Pattern.compile("/files/([a-z]+)/([A-Za-z0-9\\-]+)\\.(jpg|png)");

    private final ImageProcessor processor;
    private final LocalFileStorage storage;
    private final MediaProperties props;
    private final List<MediaReferenceSource> sources;

    public MediaService(ImageProcessor processor, LocalFileStorage storage, MediaProperties props,
                        List<MediaReferenceSource> sources) {
        this.processor = processor;
        this.storage = storage;
        this.props = props;
        this.sources = sources;
    }

    /**
     * Yuklenen gorseli dogrular, isler ve /files/{tur klasoru}/ altina yazar.
     * @throws edu.bingol.backend.common.ApiException 400 INVALID_FILE | IMAGE_CORRUPT | IMAGE_TOO_MANY_PIXELS,
     *         413 FILE_TOO_LARGE, 422 IMAGE_TOO_COMPLEX, 503 MEDIA_BUSY | STORAGE_UNAVAILABLE
     */
    public StoredImage storeImage(MultipartFile file, ImageKind kind) {
        String folder = kind.publicFolder();
        if (folder == null) {
            throw new IllegalArgumentException(kind + " herkese acik depoya yazilamaz; PrivateMediaStore kullanin");
        }
        byte[] raw = MediaUploads.read(file, props.limits(kind).maxUploadBytes());
        ProcessedImage img = processor.process(raw, kind);
        String hash = sha256(img.data());
        String name = hash + "." + img.ext();
        String thumbName = hash + "-t." + img.ext();
        storage.writeIfAbsent(folder, name, img.data());
        storage.writeIfAbsent(folder, thumbName, img.thumb());
        String base = "/files/" + folder + "/";
        return new StoredImage(base + name, base + thumbName, img.width(), img.height(), img.data().length,
                img.contentType());
    }

    /** Ana dosya URL'sinden kucuk resim URL'si (ad kurali: {@code <ozet>-t.<uzanti>}); gecersizse null. */
    public static String thumbUrlOf(String url) {
        if (url == null) {
            return null;
        }
        var m = PUBLIC_URL.matcher(url);
        if (!m.matches() || m.group(2).endsWith("-t")) {
            return null;
        }
        return "/files/" + m.group(1) + "/" + m.group(2) + "-t." + m.group(3);
    }

    /**
     * Bir URL artik bir kayitta kullanilmiyorsa (DB'de degisiklik FLUSH edildikten sonra cagirin) dosyayi ve
     * kucuk resmini siler. Yeni yazilmis/dokunulmus dosyaya {@code graceSeconds} boyunca dokunmaz (ayni icerigi
     * yuklemekte olan baska bir istekle yarisi onlemek icin); kalan yetimleri zamanlanmis temizlik toplar.
     * Hic exception firlatmaz.
     */
    public void release(String url) {
        try {
            if (url == null) {
                return;
            }
            var m = PUBLIC_URL.matcher(url);
            if (!m.matches() || m.group(2).endsWith("-t")) {
                return;
            }
            Path main = storage.resolveFile(m.group(1), m.group(2) + "." + m.group(3));
            if (main == null || !Files.isRegularFile(main)) {
                return;
            }
            if (Files.getLastModifiedTime(main).toInstant().isAfter(Instant.now().minusSeconds(props.graceSeconds()))) {
                return;
            }
            if (isReferenced(url)) {
                return;
            }
            storage.delete(url);
            storage.delete(thumbUrlOf(url));
        } catch (IOException | RuntimeException e) {
            log.warn("Medya serbest birakilamadi {}: {}", url, e.toString());
        }
    }

    boolean isReferenced(String url) {
        for (MediaReferenceSource s : sources) {
            if (s.isReferenced(url)) {
                return true;
            }
        }
        return false;
    }

    Duration orphanMinAge() {
        return Duration.ofHours(props.orphanMinAgeHours());
    }

    static String sha256(byte[] data) {
        try {
            // 160 bit yeterli; dosya adi kisa kalir
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(data))
                    .substring(0, 40);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    static byte[] utf8(String s) {
        return s.getBytes(StandardCharsets.UTF_8);
    }
}
