package edu.bingol.backend.forum.share;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.media.PrivateMediaStore;
import edu.bingol.backend.share.ForumShareImageProvider;
import java.time.Duration;
import java.util.List;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.Resource;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * {@code GET /s/f/{id}/img}, {@code /s/fc/{id}/img}: herkese acik forum konusunun ilk gorselinin KUCUK resmi
 * (OpenGraph + bildirim `imageUrl`). Konunun herkese acik oldugunu cagiran ({@code SharePageController} ->
 * {@code ShareService.publicView}) zaten dogrulamistir; burada yalniz medya satiri bir konuya bagli, gizlenmemis ve
 * kucuk resmi var mi bakilir. Ham/tam boyutlu gorsel bu uctan SUNULMAZ. {@code public, max-age=300}.
 */
@Component
public class ForumShareImages implements ForumShareImageProvider {

    /** Forum medya kovasi (A: forum.media). */
    static final String BUCKET = "forum";

    private final JdbcTemplate jdbc;
    private final PrivateMediaStore store;

    public ForumShareImages(JdbcTemplate jdbc, PrivateMediaStore store) {
        this.jdbc = jdbc;
        this.store = store;
    }

    @Override
    public ResponseEntity<Resource> servePublicPreview(long mediaId, String ifNoneMatch) {
        List<String> keys = jdbc.queryForList("""
                SELECT m.thumb_key FROM forum_media m
                 WHERE m.id = ? AND m.hidden_at IS NULL AND m.thumb_key IS NOT NULL
                   AND EXISTS (SELECT 1 FROM forum_topic_image fi WHERE fi.media_id = m.id)""", String.class, mediaId);
        if (keys.isEmpty()) {
            throw notFound();
        }
        String key = keys.get(0);
        String etag = "\"" + key + "\"";
        CacheControl cc = CacheControl.maxAge(Duration.ofSeconds(300)).cachePublic();
        if (ifNoneMatch != null && ifNoneMatch.contains(etag)) {
            return ResponseEntity.status(HttpStatus.NOT_MODIFIED).eTag(etag).cacheControl(cc).build();
        }
        byte[] data = store.read(BUCKET, key);
        if (data == null) {
            throw notFound();
        }
        MediaType type = key.endsWith(".png") ? MediaType.IMAGE_PNG
                : key.endsWith(".webp") ? MediaType.parseMediaType("image/webp") : MediaType.IMAGE_JPEG;
        return ResponseEntity.ok().contentType(type).contentLength(data.length).eTag(etag).cacheControl(cc)
                .header("X-Content-Type-Options", "nosniff")
                .header("Content-Security-Policy", "default-src 'none'")
                .header(HttpHeaders.CONTENT_DISPOSITION, "inline")
                .body(new ByteArrayResource(data));
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "MEDIA_NOT_FOUND", "Görsel bulunamadı.");
    }
}
