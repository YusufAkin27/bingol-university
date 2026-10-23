package edu.bingol.backend.common.storage;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.StorageProperties;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;

@Component
public class LocalFileStorage implements FileStorage {

    private static final Logger log = LoggerFactory.getLogger(LocalFileStorage.class);
    private static final Map<String, String> EXT = Map.of(
            "image/jpeg", "jpg", "image/png", "png", "image/webp", "webp");

    private final Path root;

    public LocalFileStorage(StorageProperties props) {
        this.root = Path.of(props.dir()).toAbsolutePath().normalize();
    }

    public Path root() {
        return root;
    }

    @Override
    public String save(String folder, MultipartFile file, Set<String> allowed, long maxBytes) {
        String type = file.getContentType();
        if (file.isEmpty() || type == null || !allowed.contains(type) || !EXT.containsKey(type)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_FILE", "Geçersiz dosya türü.");
        }
        if (file.getSize() > maxBytes) {
            throw new ApiException(HttpStatus.PAYLOAD_TOO_LARGE, "FILE_TOO_LARGE",
                    "Dosya en fazla " + (maxBytes / 1024 / 1024) + " MB olabilir.");
        }
        // Klasor adi koddan gelir, dosya adini biz uretiriz (yol enjeksiyonu yok).
        Path dir = root.resolve(folder).normalize();
        if (!dir.startsWith(root)) {
            throw new IllegalArgumentException("gecersiz klasor");
        }
        String name = UUID.randomUUID() + "." + EXT.get(type);
        try (InputStream in = file.getInputStream()) {
            Files.createDirectories(dir);
            Files.copy(in, dir.resolve(name), StandardCopyOption.REPLACE_EXISTING);
        } catch (IOException e) {
            log.error("Dosya kaydedilemedi: {}", e.toString());
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "STORAGE_UNAVAILABLE",
                    "Dosya şu anda kaydedilemiyor.");
        }
        return "/files/" + folder + "/" + name;
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
