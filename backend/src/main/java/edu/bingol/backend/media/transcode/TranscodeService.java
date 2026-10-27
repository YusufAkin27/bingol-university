package edu.bingol.backend.media.transcode;

import edu.bingol.backend.media.ImageKind;
import edu.bingol.backend.media.PrivateMediaStore;
import edu.bingol.backend.post.media.PostMedia;
import edu.bingol.backend.post.media.PostMediaService;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.HexFormat;
import java.util.Optional;
import java.util.stream.Stream;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * Tek bir gonderi videosunun yeniden kodlanmasi (ve eski duz videonun sifrelenmesi). Servis sozlesmesi:
 * hicbir yontem exception sizdirmaz; hata durumunda ORIJINAL video (zaten sifreli/erisilebilir) sunulmaya devam eder.
 */
@Service
public class TranscodeService {

    private static final Logger log = LoggerFactory.getLogger(TranscodeService.class);
    static final int POSTER_MAX_DIM = 720;

    private final PostMediaTranscodeRepository repo;
    private final PrivateMediaStore store;
    private final VideoTranscoder transcoder;
    private final TranscodeProperties props;

    public TranscodeService(PostMediaTranscodeRepository repo, PrivateMediaStore store, VideoTranscoder transcoder,
                            TranscodeProperties props) {
        this.repo = repo;
        this.store = store;
        this.transcoder = transcoder;
        this.props = props;
    }

    /** Sonuc: true = DONE, false = basarisiz (yeniden denenecek ya da FAILED). Satir PROCESSING olmalidir. */
    public boolean process(long mediaId) {
        Path dir = null;
        String newKey = null;
        try {
            PostMedia m = repo.findById(mediaId).orElse(null);
            if (m == null || !m.isVideo()) {
                return false;
            }
            final String oldKey = m.getStorageKey();
            final String oldThumb = m.getThumbKey();
            final long oldBytes = m.getBytes();
            dir = tempDir();
            Path in = dir.resolve("in.mp4");
            Path out = dir.resolve("out.mp4");
            store.readVideoToFile(PostMediaService.BUCKET, oldKey, m.getWrappedDek(), in);

            VideoTranscoder.Probe src = transcoder.probe(in);
            if (!src.hasVideo() || src.durationMs() <= 0) {
                throw new VideoTranscoder.TranscodeException("gecerli video akisi yok", false);
            }
            if (src.durationMs() > props.maxDurationSeconds() * 1000L + 1000) {
                throw new VideoTranscoder.TranscodeException("sure siniri asildi", false);
            }
            transcoder.transcode(in, out);
            VideoTranscoder.Probe res = transcoder.probe(out);
            if (!res.hasVideo() || res.durationMs() <= 0) {
                throw new VideoTranscoder.TranscodeException("cikti gecersiz", false);
            }

            String sha;
            try (InputStream is = Files.newInputStream(out)) {
                sha = sha256Hex(is);
            }
            long bytes = Files.size(out);
            String[] w;
            try (InputStream is = Files.newInputStream(out)) {
                w = store.writeSealedVideo(PostMediaService.BUCKET, is);
            }
            newKey = w[0];
            // Poster video kimligiyle adlanir (delete(video) ikisini birlikte siler): varsa kopyala, yoksa uret
            String thumbKey = null;
            if (oldThumb != null) {
                thumbKey = store.copyPosterFor(PostMediaService.BUCKET, oldThumb, newKey);
            }
            if (thumbKey == null && props.posterEnabled()) {
                try {
                    thumbKey = makePoster(out, dir, newKey);
                } catch (VideoTranscoder.TranscodeException e) {
                    log.info("Poster uretilemedi (media={}): {}", mediaId, e.getMessage()); // poster zorunlu degil
                }
            }
            int rows = repo.complete(mediaId, newKey, w[1], bytes,
                    (int) Math.min(res.durationMs(), Integer.MAX_VALUE), res.width() > 0 ? res.width() : null,
                    res.height() > 0 ? res.height() : null, sha, thumbKey, Instant.now());
            if (rows != 1) { // satir silindi / baska durumda
                store.delete(PostMediaService.BUCKET, newKey); // video + turetilmis poster
                return false;
            }
            store.delete(PostMediaService.BUCKET, oldKey); // eski orijinal + eski poster
            log.info("Video donusturuldu: media={} {} -> {} bayt, {} ms", mediaId, oldBytes, bytes, res.durationMs());
            newKey = null;
            return true;
        } catch (VideoTranscoder.TranscodeException e) {
            log.warn("Video donusturulemedi (media={}): {}{}", mediaId, e.getMessage(), e.isTimeout() ? " [zaman asimi]" : "");
            return failed(mediaId, newKey);
        } catch (IOException | RuntimeException e) {
            log.warn("Video donusturme hatasi (media={}): {}", mediaId, e.toString());
            return failed(mediaId, newKey);
        } finally {
            deleteTree(dir);
        }
    }

    private boolean failed(long mediaId, String newKey) {
        try {
            if (newKey != null) {
                store.delete(PostMediaService.BUCKET, newKey);
            }
            repo.fail(mediaId, props.maxAttempts(), Instant.now());
        } catch (RuntimeException e) {
            log.warn("Donusturme hatasi kaydedilemedi (media={}): {}", mediaId, e.toString());
        }
        return false;
    }

    private String makePoster(Path video, Path dir, String newVideoKey) throws VideoTranscoder.TranscodeException, IOException {
        Path jpg = dir.resolve("poster.jpg");
        transcoder.poster(video, jpg);
        String[] p = store.storePoster(PostMediaService.BUCKET, newVideoKey, Files.readAllBytes(jpg), POSTER_MAX_DIM,
                ImageKind.FEED);
        return p[0];
    }

    /**
     * Eski DUZ videoyu sifreler (yeniden kodlamadan). true = sifrelendi. Satirin kaydi baska yerde degistiyse
     * yeni dosya silinir ve false doner.
     */
    public boolean encryptExisting(long mediaId) {
        Path dir = null;
        String newKey = null;
        try {
            if (!store.sealedAvailable()) {
                return false;
            }
            PostMedia m = repo.findById(mediaId).orElse(null);
            if (m == null || !m.isVideo() || m.isEncrypted()) {
                return false;
            }
            final String oldKey = m.getStorageKey();
            final String oldThumb = m.getThumbKey();
            dir = tempDir();
            Path plain = dir.resolve("plain.mp4");
            store.readVideoToFile(PostMediaService.BUCKET, oldKey, null, plain);
            String[] w;
            try (InputStream is = Files.newInputStream(plain)) {
                w = store.writeSealedVideo(PostMediaService.BUCKET, is);
            }
            newKey = w[0];
            String thumb = oldThumb == null ? null : store.copyPosterFor(PostMediaService.BUCKET, oldThumb, newKey);
            if (repo.sealExisting(mediaId, oldKey, newKey, w[1], thumb) != 1) {
                store.delete(PostMediaService.BUCKET, newKey);
                return false;
            }
            store.delete(PostMediaService.BUCKET, oldKey);
            newKey = null;
            return true;
        } catch (IOException | RuntimeException e) {
            log.warn("Eski video sifrelenemedi (media={}): {}", mediaId, e.toString());
            if (newKey != null) {
                store.delete(PostMediaService.BUCKET, newKey);
            }
            return false;
        } finally {
            deleteTree(dir);
        }
    }

    /**
     * DEK'i eski ana anahtarla sarili videoyu cozup YENI DEK ile (aktif ana anahtar) yeniden yazar.
     * true = yeniden sarildi.
     */
    public boolean reseal(long mediaId) {
        Path dir = null;
        String newKey = null;
        try {
            PostMedia m = repo.findById(mediaId).orElse(null);
            if (m == null || !m.isVideo() || !m.isEncrypted() || m.getWrappedDek() == null) {
                return false;
            }
            final String oldKey = m.getStorageKey();
            final String oldThumb = m.getThumbKey();
            final String oldDek = m.getWrappedDek();
            dir = tempDir();
            Path plain = dir.resolve("plain.mp4");
            store.readVideoToFile(PostMediaService.BUCKET, oldKey, oldDek, plain);
            String[] w;
            try (InputStream is = Files.newInputStream(plain)) {
                w = store.writeSealedVideo(PostMediaService.BUCKET, is);
            }
            newKey = w[0];
            String thumb = oldThumb == null ? null : store.copyPosterFor(PostMediaService.BUCKET, oldThumb, newKey);
            if (repo.reseal(mediaId, oldKey, oldDek, newKey, w[1], thumb) != 1) {
                store.delete(PostMediaService.BUCKET, newKey);
                return false;
            }
            store.delete(PostMediaService.BUCKET, oldKey);
            newKey = null;
            return true;
        } catch (IOException | RuntimeException e) {
            log.warn("Video yeniden sarilamadi (media={}): {}", mediaId, e.toString());
            if (newKey != null) {
                store.delete(PostMediaService.BUCKET, newKey);
            }
            return false;
        } finally {
            deleteTree(dir);
        }
    }

    private Path tempDir() throws IOException {
        String base = props.tempDir();
        if (base != null && !base.isBlank()) {
            Path b = Path.of(base);
            Files.createDirectories(b);
            return Files.createTempDirectory(b, "trn");
        }
        return Files.createTempDirectory("trn");
    }

    static String sha256Hex(InputStream in) throws IOException {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] buf = new byte[1 << 16];
            int n;
            while ((n = in.read(buf)) > 0) {
                md.update(buf, 0, n);
            }
            return HexFormat.of().formatHex(md.digest());
        } catch (java.security.NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    private static void deleteTree(Path dir) {
        if (dir == null) {
            return;
        }
        try (Stream<Path> s = Files.walk(dir)) {
            s.sorted(java.util.Comparator.reverseOrder()).forEach(p -> {
                try {
                    Files.deleteIfExists(p);
                } catch (IOException ignored) {
                    // en iyi caba
                }
            });
        } catch (IOException ignored) {
            // en iyi caba
        }
    }

    Optional<PostMedia> find(long id) {
        return repo.findById(id);
    }
}
