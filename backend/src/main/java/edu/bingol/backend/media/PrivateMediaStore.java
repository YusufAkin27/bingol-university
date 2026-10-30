package edu.bingol.backend.media;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.MediaProperties;
import edu.bingol.backend.config.StorageProperties;
import java.io.BufferedInputStream;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.Arrays;
import java.util.function.Consumer;
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
    static final Pattern KEY = Pattern.compile("[A-Za-z0-9\\-]+\\.(?:jpg|png|mp4)");

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

    /** Video baytlari icin akisli (parcali) sifreleme; yoksa video diske duz yazilir. */
    private edu.bingol.backend.crypto.BlobCipher streamCipher;
    private static final byte[] STREAM_MAGIC = {'B', 'U', 'B', '1'};

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    public void setStreamCipher(edu.bingol.backend.crypto.BlobCipher streamCipher) {
        this.streamCipher = streamCipher;
    }

    /** {@link #streamVideo} istenen araligin sonuna gelince akisi keser (hata degil). */
    private static final class RangeDone extends IOException {
        RangeDone() {
            super("aralik tamam");
        }
    }

    /** Cozulmus akisin [start, end] (dahil) araligini `out`a aktarir; oncesini atar, sonrasinda durur. */
    private static final class RangeOut extends OutputStream {
        private final OutputStream out;
        private final long start;
        private final long end;
        private long pos;

        RangeOut(OutputStream out, long start, long end) {
            this.out = out;
            this.start = start;
            this.end = end;
        }

        @Override
        public void write(int b) throws IOException {
            write(new byte[] {(byte) b}, 0, 1);
        }

        @Override
        public void write(byte[] b, int off, int len) throws IOException {
            long from = Math.max(pos, start);
            long to = Math.min(pos + len - 1, end);
            if (to >= from) {
                out.write(b, off + (int) (from - pos), (int) (to - from + 1));
            }
            pos += len;
            if (pos > end) {
                throw new RangeDone();
            }
        }
    }

    private static byte[] ctx(String bucket, String key) {
        return (bucket + "/" + key).getBytes(java.nio.charset.StandardCharsets.UTF_8);
    }

    /**
     * Video baytlarini ozel kovaya yazar (`<uuid>.mp4`); parcali AES-GCM varsa sifreli. Poster varsa ayri
     * (`<uuid>-t.jpg|png`, uzun kenari en fazla `posterMaxDim` px, yeniden kodlanir; EXIF atilir).
     * @return {videoAnahtari, posterAnahtari|null, posterGenislik, posterYukseklik}
     */
    public String[] storeVideo(String bucket, long conversationId, byte[] video, byte[] poster, int posterMaxDim,
                               Consumer<ProcessedImage> posterInspector) {
        return storeVideo0(bucket, Long.valueOf(conversationId), video, poster, posterMaxDim, posterInspector,
                ImageKind.CHAT);
    }

    /**
     * Konusmasiz video (genel gonderi): konusma DEK'i olmadigindan video baytlari duz yazilir (ozel dizinde,
     * /files/** disinda; poster ise {@link BlobCipher} ile sifreli). Okuma {@link #streamVideo} ile aynidir.
     */
    public String[] storeVideoPlain(String bucket, byte[] video, byte[] poster, int posterMaxDim,
                                    Consumer<ProcessedImage> posterInspector, ImageKind posterKind) {
        return storeVideo0(bucket, null, video, poster, posterMaxDim, posterInspector, posterKind);
    }

    private String[] storeVideo0(String bucket, Long conversationId, byte[] video, byte[] poster, int posterMaxDim,
                                 Consumer<ProcessedImage> posterInspector, ImageKind posterKind) {
        checkBucket(bucket);
        ProcessedImage img = null;
        if (poster != null) {
            img = processor.process(poster, posterKind, posterMaxDim);
            if (posterInspector != null) {
                posterInspector.accept(img);
            }
        }
        String id = UUID.randomUUID().toString();
        String key = id + ".mp4";
        writeVideo(bucket, key, conversationId, video);
        String posterKey = null;
        if (img != null) {
            posterKey = id + "-t." + img.ext();
            try {
                write(bucket, posterKey, img.data());
            } catch (RuntimeException e) {
                delete(bucket, key);
                throw e;
            }
        }
        return new String[] {key, posterKey, img == null ? "0" : String.valueOf(img.width()),
                img == null ? "0" : String.valueOf(img.height())};
    }

    private void writeVideo(String bucket, String key, Long conversationId, byte[] data) {
        Path p = path(bucket, key);
        try {
            Files.createDirectories(p.getParent());
            Path tmp = p.resolveSibling(".tmp-" + UUID.randomUUID());
            try (OutputStream o = Files.newOutputStream(tmp)) {
                if (streamCipher != null && conversationId != null) {
                    streamCipher.encrypt(conversationId, ctx(bucket, key), new ByteArrayInputStream(data), o);
                } else {
                    o.write(data);
                }
            } catch (IOException | RuntimeException e) {
                Files.deleteIfExists(tmp);
                throw e;
            }
            Files.move(tmp, p, java.nio.file.StandardCopyOption.REPLACE_EXISTING);
        } catch (IOException e) {
            log.error("Ozel video yazilamadi: {}", e.toString());
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "STORAGE_UNAVAILABLE",
                    "Dosya şu anda kaydedilemiyor.");
        }
    }

    /**
     * Videonun [start, end] (dahil) bayt araligini cozerek `out`a yazar. Tum dosya bellege alinmaz: sifreliyse
     * parca parca cozulur (basa kadar atlanir, aralik bitince durulur), duzse dogrudan konumlanilir.
     */
    public void streamVideo(String bucket, String key, long conversationId, long start, long end, OutputStream out)
            throws IOException {
        Path p = path(bucket, key);
        if (p == null || !Files.isRegularFile(p)) {
            throw new FileNotFoundException(key);
        }
        try (BufferedInputStream in = new BufferedInputStream(Files.newInputStream(p), 1 << 16)) {
            in.mark(8);
            byte[] head = in.readNBytes(4);
            in.reset();
            if (Arrays.equals(head, STREAM_MAGIC)) {
                if (streamCipher == null) {
                    throw new IOException("sifreli video ama sifre cozucu yok");
                }
                try {
                    streamCipher.decrypt(conversationId, ctx(bucket, key), in, new RangeOut(out, start, end));
                } catch (RangeDone done) {
                    // istenen aralik tamamlandi
                }
            } else {
                in.skipNBytes(start);
                long left = end - start + 1;
                byte[] buf = new byte[1 << 16];
                while (left > 0) {
                    int n = in.read(buf, 0, (int) Math.min(buf.length, left));
                    if (n < 0) {
                        break;
                    }
                    out.write(buf, 0, n);
                    left -= n;
                }
            }
        }
    }

    // ------------------------------------------------------------------ gonderi videosu: dosya-basina-DEK ile sifreli

    private PostVideoCipher postCipher;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    public void setPostCipher(PostVideoCipher postCipher) {
        this.postCipher = postCipher;
    }

    /** Dosya-basina-anahtarli sifreleme kullanilabilir mi (ana anahtar yapilandirildi mi). */
    public boolean sealedAvailable() {
        return postCipher != null;
    }

    private static String sealCtx(String bucket, String key) {
        return bucket + "/" + key;
    }

    /**
     * Videoyu `in` akisindan okuyup yeni rastgele anahtarla (`<uuid>.mp4`) SIFRELI yazar; bellekte tutmaz.
     * @param plainLength duz bayt sayisi (yalniz tutarlilik icin; sinir degil)
     * @return {anahtar, sariliDek}
     */
    public String[] writeSealedVideo(String bucket, InputStream in) {
        checkBucket(bucket);
        if (postCipher == null) {
            throw new IllegalStateException("sifreleme yapilandirilmadi");
        }
        String key = UUID.randomUUID() + ".mp4";
        String ctx = sealCtx(bucket, key);
        PostVideoCipher.Dek dek = postCipher.newDek(ctx);
        Path p = path(bucket, key);
        try {
            Files.createDirectories(p.getParent());
            Path tmp = p.resolveSibling(".tmp-" + UUID.randomUUID());
            try (OutputStream o = new java.io.BufferedOutputStream(Files.newOutputStream(tmp), 1 << 16)) {
                postCipher.encrypt(dek.key(), ctx, in, o);
            } catch (IOException | RuntimeException e) {
                Files.deleteIfExists(tmp);
                throw e;
            }
            Files.move(tmp, p, java.nio.file.StandardCopyOption.REPLACE_EXISTING);
        } catch (IOException e) {
            log.error("Sifreli video yazilamadi: {}", e.toString());
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "STORAGE_UNAVAILABLE",
                    "Dosya şu anda kaydedilemiyor.");
        }
        return new String[] {key, dek.wrapped()};
    }

    /**
     * {@link #storeVideoPlain} ile ayni sozlesme, ama video dosya-basina DEK ile SIFRELI yazilir.
     * @return {videoAnahtari, posterAnahtari|null, posterGenislik, posterYukseklik, sariliDek}
     */
    public String[] storeVideoSealed(String bucket, byte[] video, byte[] poster, int posterMaxDim,
                                     Consumer<ProcessedImage> posterInspector, ImageKind posterKind) {
        checkBucket(bucket);
        ProcessedImage img = null;
        if (poster != null) {
            img = processor.process(poster, posterKind, posterMaxDim);
            if (posterInspector != null) {
                posterInspector.accept(img);
            }
        }
        String[] w = writeSealedVideo(bucket, new ByteArrayInputStream(video));
        String posterKey = null;
        if (img != null) {
            posterKey = w[0].substring(0, w[0].length() - 4) + "-t." + img.ext();
            try {
                write(bucket, posterKey, img.data());
            } catch (RuntimeException e) {
                delete(bucket, w[0]);
                throw e;
            }
        }
        return new String[] {w[0], posterKey, img == null ? "0" : String.valueOf(img.width()),
                img == null ? "0" : String.valueOf(img.height()), w[1]};
    }

    /** {@link #writeSealedVideo} ile yazilan videonun [start, end] (dahil) araligini cozerek yazar. */
    public void streamSealedVideo(String bucket, String key, String wrappedDek, long start, long end,
                                  OutputStream out) throws IOException {
        Path p = path(bucket, key);
        if (p == null || !Files.isRegularFile(p)) {
            throw new FileNotFoundException(key);
        }
        if (postCipher == null) {
            throw new IOException("sifreli video ama sifre cozucu yok");
        }
        postCipher.decryptRange(p, postCipher.unwrap(wrappedDek, sealCtx(bucket, key)), sealCtx(bucket, key),
                start, end, out);
    }

    /**
     * Videonun DUZ halini `target` dosyasina yazar (ffmpeg girdisi). `wrappedDek` null ise eski (duz) kayittir.
     */
    public void readVideoToFile(String bucket, String key, String wrappedDek, Path target) throws IOException {
        try (OutputStream o = new java.io.BufferedOutputStream(Files.newOutputStream(target), 1 << 16)) {
            if (wrappedDek != null) {
                streamSealedVideo(bucket, key, wrappedDek, 0, Long.MAX_VALUE - 1, o);
            } else {
                streamVideo(bucket, key, 0L, 0, Long.MAX_VALUE - 1, o);
            }
        }
    }

    /**
     * Poster/kucuk resim baytlarini isleyip (yeniden kodlama, EXIF temizligi) ozel kovaya yazar.
     * @return {anahtar, genislik, yukseklik}
     */
    public String[] storePoster(String bucket, String videoKey, byte[] raw, int maxDim, ImageKind kind) {
        checkBucket(bucket);
        ProcessedImage img = processor.process(raw, kind, maxDim);
        // Poster adi videonun kimligini tasir: delete(videoKey) ikisini birlikte siler
        String key = videoKey.substring(0, videoKey.length() - 4) + "-t." + img.ext();
        write(bucket, key, img.data());
        return new String[] {key, String.valueOf(img.width()), String.valueOf(img.height())};
    }

    /** Var olan posteri yeni videonun kimligiyle adlandirarak kopyalar; kaynak yoksa null. */
    public String copyPosterFor(String bucket, String oldThumbKey, String newVideoKey) {
        byte[] data = read(bucket, oldThumbKey);
        if (data == null) {
            return null;
        }
        String ext = oldThumbKey.substring(oldThumbKey.lastIndexOf('.'));
        String key = newVideoKey.substring(0, newVideoKey.length() - 4) + "-t" + ext;
        write(bucket, key, data);
        return key;
    }

    /** Dosya boyutu (diskte), yoksa -1. Sifreli boyut bilgisi icin. */
    public long diskSize(String bucket, String key) {
        Path p = path(bucket, key);
        try {
            return p != null && Files.isRegularFile(p) ? Files.size(p) : -1;
        } catch (IOException e) {
            return -1;
        }
    }

    /** Moderasyon gizlemesi: videoyu (+ posteri) yeni rastgele anahtarlara kopyalar; eskileri silmez. Basarisizsa null. */
    public String[] copyVideo(String bucket, String key, String posterKey, long conversationId) {
        ByteArrayOutputStream bos = new ByteArrayOutputStream();
        try {
            streamVideo(bucket, key, conversationId, 0, Long.MAX_VALUE - 1, bos);
        } catch (IOException | RuntimeException e) {
            log.warn("Video kopyalanamadi {}/{}: {}", bucket, key, e.toString());
            return null;
        }
        byte[] poster = posterKey == null ? null : read(bucket, posterKey);
        if (posterKey != null && poster == null) {
            return null;
        }
        String id = UUID.randomUUID().toString();
        String nk = id + ".mp4";
        writeVideo(bucket, nk, conversationId, bos.toByteArray());
        String np = null;
        if (poster != null) {
            np = id + "-t" + posterKey.substring(posterKey.lastIndexOf('.'));
            write(bucket, np, poster);
        }
        return new String[] {nk, np};
    }

    /** Dogrular, isler ve ozel kovaya yazar. Hata kodlari {@link MediaService#storeImage} ile aynidir. */
    public PrivateMedia store(String bucket, MultipartFile file, ImageKind kind) {
        checkBucket(bucket);
        byte[] raw = MediaUploads.read(file, props.limits(kind).maxUploadBytes());
        return store(bucket, raw, kind);
    }

    /** Ham baytlardan (ornek test) ayni islem. */
    public PrivateMedia store(String bucket, byte[] raw, ImageKind kind) {
        return store(bucket, raw, kind, null);
    }

    /**
     * Islenmis (yeniden kodlanmis) cikti diske yazilmadan ONCE {@code inspector}a verilir; exception firlatirsa
     * hicbir sey yazilmaz (ornek: yasakli icerik ozeti denetimi).
     */
    public PrivateMedia store(String bucket, byte[] raw, ImageKind kind,
                              java.util.function.Consumer<ProcessedImage> inspector) {
        checkBucket(bucket);
        ProcessedImage img = processor.process(raw, kind);
        if (inspector != null) {
            inspector.accept(img);
        }
        String id = UUID.randomUUID().toString();
        String key = id + "." + img.ext();
        String thumbKey = id + "-t." + img.ext();
        write(bucket, key, img.data());
        write(bucket, thumbKey, img.thumb());
        return new PrivateMedia(bucket, key, thumbKey, img.width(), img.height(), img.data().length,
                img.contentType(), img.thumbEdge());
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

    /**
     * Ana dosya + kucuk resmi YENI rastgele anahtarlarla kopyalar (eski anahtarlari SILMEZ; cagiran DB guncellenip
     * commit edildikten sonra siler). Eski imzali URL'ler boylece gecersiz olur. Kaynak yoksa/okunamazsa null.
     * @return {anahtar, kucukResimAnahtari}
     */
    public String[] copy(String bucket, String key, String thumbKey) {
        byte[] main = read(bucket, key);
        byte[] thumb = read(bucket, thumbKey);
        if (main == null || thumb == null) {
            return null;
        }
        String ext = key.substring(key.lastIndexOf('.') + 1);
        String id = UUID.randomUUID().toString();
        String nk = id + "." + ext;
        String nt = id + "-t." + thumbKey.substring(thumbKey.lastIndexOf('.') + 1);
        write(bucket, nk, main);
        write(bucket, nt, thumb);
        return new String[] {nk, nt};
    }

    /** Ana dosyayi ve kucuk resmini siler (yoksa sessiz). */
    public void delete(String bucket, String key) {
        deleteOne(bucket, key);
        if (key != null && key.endsWith(".mp4")) { // video: poster `<id>-t.jpg|png`
            String base = key.substring(0, key.length() - 4);
            deleteOne(bucket, base + "-t.jpg");
            deleteOne(bucket, base + "-t.png");
            return;
        }
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
