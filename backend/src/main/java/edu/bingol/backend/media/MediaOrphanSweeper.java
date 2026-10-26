package edu.bingol.backend.media;

import edu.bingol.backend.common.storage.LocalFileStorage;
import edu.bingol.backend.config.MediaProperties;
import java.io.IOException;
import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** Hicbir kayitta kullanilmayan (ve yeterince eski) herkese acik gorselleri ve artik gecici dosyalari siler. */
@Component
public class MediaOrphanSweeper {

    private static final Logger log = LoggerFactory.getLogger(MediaOrphanSweeper.class);

    private final LocalFileStorage storage;
    private final MediaService media;
    private final MediaProperties props;

    public MediaOrphanSweeper(LocalFileStorage storage, MediaService media, MediaProperties props) {
        this.storage = storage;
        this.media = media;
        this.props = props;
    }

    @Scheduled(cron = "${app.media.sweep-cron:0 30 3 * * *}", zone = "Europe/Istanbul")
    public void scheduled() {
        if (props.sweepEnabled()) {
            int n = sweepOnce();
            log.info("Medya yetim temizligi: {} dosya silindi", n);
        }
    }

    /** @return silinen dosya sayisi. Hic exception firlatmaz. */
    public int sweepOnce() {
        int deleted = 0;
        Instant cutoff = Instant.now().minus(media.orphanMinAge());
        for (String folder : props.sweepFolders()) {
            Path dir = storage.resolveFile(folder, "");
            if (dir == null || !Files.isDirectory(dir)) {
                continue;
            }
            try (DirectoryStream<Path> files = Files.newDirectoryStream(dir)) {
                for (Path f : files) {
                    try {
                        deleted += sweepFile(folder, f, cutoff);
                    } catch (IOException | RuntimeException e) {
                        log.warn("Temizlik atlandi {}: {}", f, e.toString());
                    }
                }
            } catch (IOException | RuntimeException e) {
                log.warn("Klasor taranamadi {}: {}", folder, e.toString());
            }
        }
        return deleted;
    }

    private int sweepFile(String folder, Path f, Instant cutoff) throws IOException {
        if (!Files.isRegularFile(f) || Files.getLastModifiedTime(f).toInstant().isAfter(cutoff)) {
            return 0;
        }
        String name = f.getFileName().toString();
        if (name.startsWith(".tmp-")) {
            return Files.deleteIfExists(f) ? 1 : 0;
        }
        int dot = name.lastIndexOf('.');
        if (dot < 0) {
            return 0;
        }
        String stem = name.substring(0, dot);
        String ext = name.substring(dot);
        if (stem.endsWith("-t")) { // kucuk resim: ana dosyasi yoksa yetim
            Path main = storage.resolveFile(folder, stem.substring(0, stem.length() - 2) + ext);
            return main != null && !Files.exists(main) && Files.deleteIfExists(f) ? 1 : 0;
        }
        String url = "/files/" + folder + "/" + name;
        if (media.isReferenced(url)) {
            return 0;
        }
        int n = Files.deleteIfExists(f) ? 1 : 0;
        String thumb = MediaService.thumbUrlOf(url);
        if (thumb != null) {
            Path t = storage.resolveFile(folder, thumb.substring(thumb.lastIndexOf('/') + 1));
            if (t != null && Files.deleteIfExists(t)) {
                n++;
            }
        }
        return n;
    }
}
