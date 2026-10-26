package edu.bingol.backend.media;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.MediaProperties;
import edu.bingol.backend.config.StorageProperties;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.time.Instant;
import java.util.UUID;
import java.util.function.Predicate;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.Resource;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;

/**
 * Herkese ACIK OLMAYAN gorsel deposu (sohbet gorselleri vb.). Dosyalar `/files/**` altinda degildir; URL ile
 * dogrudan erisilemez. Kullanim:
 * <pre>
 *   PrivateMedia m = store.store("chat", file, ImageKind.CHAT);     // key'leri mesaj satirina yaz
 *   // okuma: once YETKIYI sen kontrol et (katilimci mi?), sonra
 *   return store.serve("chat", m.key());                            // veya serve(.., thumbKey)
 *   // ya da kisa omurlu imzali URL: signer.sign("chat", m.thumbKey(), Duration.ofMinutes(5))
 * </pre>
 * Adlar rastgele UUID'dir (icerik ozeti yok: ozet-varlik sorgusu sizintisi olmaz, yinelenen yazim yoktur).
 * Diske yazilan baytlar {@link BlobCipher} uzerinden gecer (varsayilan sifrelemez).
 */
@Component
public class PrivateMediaStore {

    private static final Logger log = LoggerFactory.getLogger(PrivateMediaStore.class);
    static final Pattern BUCKET = Pattern.compile("[a-z]{1,20}");
    static final Pattern KEY = Pattern.compile("[A-Za-z0-9\\-]+\\.(?:jpg|png)");

    private final Path root;
    private final ImageProcessor processor;
    private final MediaProperties props;
    private final BlobCipher cipher;

    public PrivateMediaStore(StorageProperties storage, MediaProperties props, ImageProcessor processor,
                             ObjectProvider<BlobCipher> cipher) {
        String dir = props.privateDir();
        this.root = (dir == null || dir.isBlank() ? Path.of(storage.dir(), "_private") : Path.of(dir))
                .toAbsolutePath().normalize();
        this.processor = processor;
        this.props = props;
        this.cipher = cipher.getIfAvailable(NoopBlobCipher::new);
    }

    /** Dogrular, isler ve ozel kovaya yazar. Hata kodlari {@link MediaService#storeImage} ile aynidir. */
    public PrivateMedia store(String bucket, MultipartFile file, ImageKind kind) {
        checkBucket(bucket);
        byte[] raw = MediaUploads.read(file, props.limits(kind).maxUploadBytes());
        return store(bucket, raw, kind);
    }

    /** Ham baytlardan (ornek test) ayni islem. */
    public PrivateMedia store(String bucket, byte[] raw, ImageKind kind) {
        checkBucket(bucket);
        ProcessedImage img = processor.process(raw, kind);
        String id = UUID.randomUUID().toString();
        String key = id + "." + img.ext();
        String thumbKey = id + "-t." + img.ext();
        write(bucket, key, img.data());
        write(bucket, thumbKey, img.thumb());
        return new PrivateMedia(bucket, key, thumbKey, img.width(), img.height(), img.data().length,
                img.contentType());
    }

    /**
     * Dosyayi HTTP cevabi olarak verir (no-store, nosniff, kisitli CSP). YETKI KONTROLU CAGIRANA AITTIR.
     * Yoksa 404.
     */
    public ResponseEntity<Resource> serve(String bucket, String key) {
        byte[] data = read(bucket, key);
        if (data == null) {
            return ResponseEntity.notFound().build();
        }
        MediaType type = key.endsWith(".png") ? MediaType.IMAGE_PNG : MediaType.IMAGE_JPEG;
        return ResponseEntity.ok()
                .contentType(type)
                .contentLength(data.length)
                .cacheControl(CacheControl.noStore())
                .header("X-Content-Type-Options", "nosniff")
                .header("Content-Security-Policy", "default-src 'none'")
                .header("Content-Disposition", "inline")
                .body(new ByteArrayResource(data));
    }

    /** Cozulmus baytlar; yoksa/gecersizse null. */
    public byte[] read(String bucket, String key) {
        Path p = path(bucket, key);
        if (p == null || !Files.isRegularFile(p)) {
            return null;
        }
        try {
            return cipher.decrypt(Files.readAllBytes(p), bucket + "/" + key);
        } catch (IOException | RuntimeException e) {
            log.warn("Ozel medya okunamadi {}/{}: {}", bucket, key, e.toString());
            return null;
        }
    }

    /** Ana dosyayi ve kucuk resmini siler (yoksa sessiz). */
    public void delete(String bucket, String key) {
        deleteOne(bucket, key);
        if (key != null && !key.contains("-t.") && key.lastIndexOf('.') > 0) {
            int dot = key.lastIndexOf('.');
            deleteOne(bucket, key.substring(0, dot) + "-t" + key.substring(dot));
        }
    }

    /**
     * Yetim temizligi (kova sahibi modul zamanlayicidan cagirir): `minAge`den eski ve `referenced` false donen
     * ana dosyalari (+ kucuk resimlerini) siler.
     * @param referenced anahtar (ornek "ab12.jpg") DB'de kullaniliyor mu
     * @return silinen ana dosya sayisi
     */
    public int sweep(String bucket, Predicate<String> referenced, Duration minAge) {
        checkBucket(bucket);
        Path dir = root.resolve(bucket).normalize();
        int n = 0;
        if (!Files.isDirectory(dir)) {
            return 0;
        }
        Instant cutoff = Instant.now().minus(minAge);
        try (var files = Files.newDirectoryStream(dir)) {
            for (Path f : files) {
                String name = f.getFileName().toString();
                if (name.contains("-t.") || !KEY.matcher(name).matches()) {
                    continue;
                }
                if (Files.getLastModifiedTime(f).toInstant().isBefore(cutoff) && !referenced.test(name)) {
                    delete(bucket, name);
                    n++;
                }
            }
        } catch (IOException | RuntimeException e) {
            log.warn("Ozel medya temizligi yarim kaldi {}: {}", bucket, e.toString());
        }
        return n;
    }

    private void write(String bucket, String key, byte[] data) {
        Path p = path(bucket, key);
        try {
            Files.createDirectories(p.getParent());
            Path tmp = p.resolveSibling(".tmp-" + UUID.randomUUID());
            Files.write(tmp, cipher.encrypt(data, bucket + "/" + key));
            Files.move(tmp, p, java.nio.file.StandardCopyOption.REPLACE_EXISTING);
        } catch (IOException e) {
            log.error("Ozel medya yazilamadi: {}", e.toString());
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "STORAGE_UNAVAILABLE",
                    "Dosya şu anda kaydedilemiyor.");
        }
    }

    private void deleteOne(String bucket, String key) {
        Path p = path(bucket, key);
        if (p != null) {
            try {
                Files.deleteIfExists(p);
            } catch (IOException e) {
                log.warn("Ozel medya silinemedi {}/{}: {}", bucket, key, e.toString());
            }
        }
    }

    /** Kova/anahtar kati desenle dogrulanir; yol gezintisi imkansiz. Gecersizse null. */
    private Path path(String bucket, String key) {
        if (bucket == null || key == null || !BUCKET.matcher(bucket).matches() || !KEY.matcher(key).matches()) {
            return null;
        }
        Path p = root.resolve(bucket).resolve(key).normalize();
        return p.startsWith(root) ? p : null;
    }

    private static void checkBucket(String bucket) {
        if (bucket == null || !BUCKET.matcher(bucket).matches()) {
            throw new IllegalArgumentException("gecersiz kova adi");
        }
    }
}
