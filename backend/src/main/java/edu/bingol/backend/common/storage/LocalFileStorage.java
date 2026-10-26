package edu.bingol.backend.common.storage;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.MediaProperties;
import edu.bingol.backend.config.StorageProperties;
import edu.bingol.backend.media.ImageKind;
import edu.bingol.backend.media.ImageProcessor;
import edu.bingol.backend.media.MediaUploads;
import edu.bingol.backend.media.ProcessedImage;
import java.io.IOException;
import java.nio.file.AtomicMoveNotSupportedException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.nio.file.attribute.FileTime;
import java.util.Set;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;

/**
 * Yerel disk deposu (`app.storage.dir`; Docker'da volume). Eski {@link #save} yolu da artik gorsel hattindan
 * gecer (dogrula + yeniden kodla + sikistir); yeni kod {@code MediaService} kullanmalidir.
 */
@Component
public class LocalFileStorage implements FileStorage {

    private static final Logger log = LoggerFactory.getLogger(LocalFileStorage.class);

    private final Path root;
    private final ImageProcessor processor;
    private final MediaProperties media;

    public LocalFileStorage(StorageProperties props, ImageProcessor processor, MediaProperties media) {
        this.root = Path.of(props.dir()).toAbsolutePath().normalize();
        this.processor = processor;
        this.media = media;
    }

    public Path root() {
        return root;
    }

    @Override
    public String save(String folder, MultipartFile file, Set<String> allowed, long maxBytes) {
        ImageKind kind = switch (folder) {
            case "avatars" -> ImageKind.AVATAR;
            case "posts" -> ImageKind.POST;
            default -> ImageKind.COVER;
        };
        byte[] raw = MediaUploads.read(file, Math.min(maxBytes, media.limits(kind).maxUploadBytes()));
        ProcessedImage img = processor.process(raw, kind);
        String name = UUID.randomUUID() + "." + img.ext();
        writeIfAbsent(folder, name, img.data());
        return "/files/" + folder + "/" + name;
    }

    /** Dosya yoksa atomik yazar (gecici dosya + tasima); varsa yalniz mtime'ini yeniler. @return yeni yazildi mi */
    public boolean writeIfAbsent(String folder, String name, byte[] data) {
        Path dir = resolveDir(folder);
        Path target = dir.resolve(name).normalize();
        if (!target.startsWith(dir)) {
            throw new IllegalArgumentException("gecersiz dosya adi");
        }
        try {
            Files.createDirectories(dir);
            if (Files.isRegularFile(target)) {
                Files.setLastModifiedTime(target, FileTime.fromMillis(System.currentTimeMillis()));
                return false;
            }
            Path tmp = dir.resolve(".tmp-" + UUID.randomUUID());
            Files.write(tmp, data);
            try {
                Files.move(tmp, target, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING);
            } catch (AtomicMoveNotSupportedException e) {
                Files.move(tmp, target, StandardCopyOption.REPLACE_EXISTING);
            }
            return true;
        } catch (IOException e) {
            log.error("Dosya kaydedilemedi: {}", e.toString());
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "STORAGE_UNAVAILABLE",
                    "Dosya şu anda kaydedilemiyor.");
        }
    }

    public Path resolveFile(String folder, String name) {
        Path dir = resolveDir(folder);
        Path p = dir.resolve(name).normalize();
        return p.startsWith(dir) ? p : null;
    }

    private Path resolveDir(String folder) {
        // Klasor adi koddan gelir, dosya adini biz uretiriz (yol enjeksiyonu yok).
        Path dir = root.resolve(folder).normalize();
        if (!dir.startsWith(root) || dir.equals(root)) {
            throw new IllegalArgumentException("gecersiz klasor");
        }
        return dir;
    }

    @Override
    public void delete(String url) {
        if (url == null || !url.startsWith("/files/")) {
            return;
        }
        Path p = root.resolve(url.substring("/files/".length())).normalize();
        if (p.startsWith(root)) {
            try {
                Files.deleteIfExists(p);
            } catch (IOException e) {
                log.warn("Dosya silinemedi {}: {}", url, e.toString());
            }
        }
    }
}
