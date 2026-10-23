package edu.bingol.backend.common.storage;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.Map;
import org.springframework.core.io.PathResource;
import org.springframework.core.io.Resource;
import org.springframework.http.CacheControl;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

/** Yuklenen gorselleri herkese acik sunar: GET /files/{klasor}/{dosya}. */
@RestController
public class FileController {

    private static final Map<String, MediaType> TYPES = Map.of(
            "jpg", MediaType.IMAGE_JPEG, "png", MediaType.IMAGE_PNG, "webp", MediaType.parseMediaType("image/webp"));

    private final LocalFileStorage storage;

    public FileController(LocalFileStorage storage) {
        this.storage = storage;
    }

    @GetMapping("/files/{folder:[a-z]+}/{name:[A-Za-z0-9\\-]+\\.(?:jpg|png|webp)}")
    public ResponseEntity<Resource> get(@PathVariable String folder, @PathVariable String name) throws IOException {
        Path p = storage.root().resolve(folder).resolve(name).normalize();
        if (!p.startsWith(storage.root()) || !Files.isRegularFile(p)) {
            return ResponseEntity.notFound().build();
        }
        String ext = name.substring(name.lastIndexOf('.') + 1);
        return ResponseEntity.ok()
                .contentType(TYPES.get(ext))
                .cacheControl(CacheControl.maxAge(Duration.ofDays(30)).cachePublic().immutable())
                .header("X-Content-Type-Options", "nosniff")
                .body(new PathResource(p));
    }
}
