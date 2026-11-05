package edu.bingol.backend.forum.media;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.config.MediaProperties;
import edu.bingol.backend.forum.topic.ForumPermissions;
import edu.bingol.backend.forum.topic.spi.ForumTopicLookup;
import edu.bingol.backend.media.ImageKind;
import edu.bingol.backend.media.MediaUploads;
import edu.bingol.backend.media.PrivateMedia;
import edu.bingol.backend.media.PrivateMediaStore;
import edu.bingol.backend.media.UploadGuard;
import edu.bingol.backend.moderation.ContentBlocklist;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Duration;
import java.time.Instant;
import java.util.HashSet;
import java.util.HexFormat;
import java.util.List;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.Resource;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

/**
 * Forum gorselleri: yukleme (tur/boyut dogrulama, yeniden kodlama, EXIF temizligi: {@link PrivateMediaStore}),
 * konuya atomik baglama ve yetkili sunum. Baytlar ozel depoda ({@value #BUCKET} kovasi, /files/** disi).
 * YETKI KURALI TEK YERDE ({@link #accessible}): baglanmamis gorsel yalniz sahibine (ve moderatore); baglanmissa konu
 * bakana gorunur olmali (silinmis/kaldirilmis/engelli/sessize alinmis = 404). Aksi her durumda ayni 404.
 */
@Service
public class ForumMediaService {

    public static final String BUCKET = "forum";
    /** Konu basina en cok gorsel. */
    public static final int MAX_PER_TOPIC = 4;
    private static final Logger log = LoggerFactory.getLogger(ForumMediaService.class);
    private static final long MAX_UPLOAD_BYTES = 10L << 20;

    private final ForumMediaRepository repo;
    private final PrivateMediaStore store;
    private final MediaProperties mediaProps;
    private final ContentBlocklist blocklist;
    private final ForumTopicLookup lookup;
    private final JdbcTemplate jdbc;
    private final ObjectProvider<UploadGuard> uploadGuard;

    @Value("${app.forum.media.pending-max:12}")
    private int pendingMax = 12;
    /** Silinen konunun gorselleri kac gun sonra diskten kalkar. */
    @Value("${app.forum.media.deleted-retention-days:30}")
    private int deletedRetentionDays = 30;

    public ForumMediaService(ForumMediaRepository repo, PrivateMediaStore store, MediaProperties mediaProps,
                             ContentBlocklist blocklist, ForumTopicLookup lookup, JdbcTemplate jdbc,
                             ObjectProvider<UploadGuard> uploadGuard) {
        this.repo = repo;
        this.store = store;
        this.mediaProps = mediaProps;
        this.blocklist = blocklist;
        this.lookup = lookup;
        this.jdbc = jdbc;
        this.uploadGuard = uploadGuard;
    }

    /** Yukleme yaniti (API: {@code {id,url,thumbUrl,width,height}}). */
    public record Uploaded(Long id, String url, String thumbUrl, Integer width, Integer height) {}

    // ------------------------------------------------------------------ yukleme

    public Uploaded upload(Long userId, MultipartFile file) {
        UploadGuard guard = uploadGuard.getIfAvailable();
        try (UploadGuard.Permit ignored = guard == null ? null : guard.acquire(userId, false)) {
            if (repo.countUnattached(userId) >= pendingMax) {
                throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "FORUM_MEDIA_PENDING_LIMIT",
                        "Konuya eklenmemiş çok fazla görsel var. Önce konunuzu paylaşın.");
            }
            long max = Math.min(MAX_UPLOAD_BYTES, mediaProps.limits(ImageKind.FEED).maxUploadBytes());
            byte[] raw = MediaUploads.read(file, max);
            if (guard != null) {
                guard.charge(userId, raw.length);
            }
            rejectIfBlocked(raw);
            PrivateMedia pm = store.store(BUCKET, raw, ImageKind.FEED, img -> rejectIfBlocked(img.data()));
            try {
                ForumMedia m = new ForumMedia();
                m.setOwnerId(userId);
                m.setStorageKey(pm.key());
                m.setThumbKey(pm.thumbKey());
                m.setContentType(pm.contentType());
                m.setWidth(pm.width());
                m.setHeight(pm.height());
                m.setBytes(pm.bytes());
                m.setSha256(sha256Hex(raw));
                m = repo.save(m);
                return new Uploaded(m.getId(), urlOf(m.getId(), false), urlOf(m.getId(), true), m.getWidth(), m.getHeight());
            } catch (RuntimeException e) {
                store.delete(BUCKET, pm.key());
                throw e;
            }
        }
    }

    public static String urlOf(Long mediaId, boolean thumb) {
        return "/api/forum/media/" + mediaId + (thumb ? "?thumb=true" : "");
    }

    private void rejectIfBlocked(byte[] data) {
        if (blocklist.isBlocked(sha256Hex(data))) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "MEDIA_BLOCKED", "Bu görsel yüklenemez.");
        }
    }

    static String sha256Hex(byte[] data) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(data));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    // ------------------------------------------------------------------ baglama

    /**
     * Konu olusturan islemin ICINDE cagrilir. Kimlikler benzersiz, en cok 4 ve hepsi bu kullanicinin baglanmamis
     * gorseli olmali; her biri atomik baglanir (yarisan ikinci konu ayni gorseli alamaz). Hata = 400 FORUM_MEDIA_INVALID.
     */
    @Transactional
    public void attach(Long topicId, Long ownerId, List<Long> mediaIds) {
        if (mediaIds == null || mediaIds.isEmpty()) {
            return;
        }
        if (mediaIds.size() > MAX_PER_TOPIC) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "FORUM_TOO_MANY_IMAGES",
                    "Bir konuya en çok " + MAX_PER_TOPIC + " görsel eklenebilir.", String.valueOf(MAX_PER_TOPIC));
        }
        if (new HashSet<>(mediaIds).size() != mediaIds.size() || mediaIds.stream().anyMatch(Objects::isNull)) {
            throw invalid();
        }
        short pos = 0;
        try {
            for (Long id : mediaIds) {
                int n = jdbc.update("INSERT INTO forum_topic_image (topic_id, media_id, position) "
                        + "SELECT CAST(? AS BIGINT), m.id, CAST(? AS SMALLINT) FROM forum_media m "
                        + "WHERE m.id = ? AND m.owner_id = ? AND m.hidden_at IS NULL AND NOT EXISTS "
                        + "(SELECT 1 FROM forum_topic_image i WHERE i.media_id = m.id)", topicId, pos++, id, ownerId);
                if (n != 1) {
                    throw invalid();
                }
            }
        } catch (DataIntegrityViolationException e) {
            throw invalid();
        }
    }

    // ------------------------------------------------------------------ sunum

    /** Erisebilir ise gorsel; degilse bos. Hicbir durumda neden sizdirmaz. */
    @Transactional(readOnly = true)
    public Optional<ForumMedia> accessible(Long viewerId, Long mediaId) {
        if (viewerId == null || mediaId == null) {
            return Optional.empty();
        }
        ForumMedia m = repo.findById(mediaId).orElse(null);
        if (m == null || m.getHiddenAt() != null) {
            return Optional.empty();
        }
        Long topicId = repo.attachedTopic(mediaId).orElse(null);
        if (topicId == null) {
            boolean ok = m.getOwnerId().equals(viewerId) || ForumPermissions.canModerate();
            return ok ? Optional.of(m) : Optional.empty();
        }
        if (ForumPermissions.canModerate()) {
            return Optional.of(m); // moderator kaldirilmis konunun gorselini de gorur
        }
        return lookup.visibleTopic(topicId, viewerId).isPresent() ? Optional.of(m) : Optional.empty();
    }

    public ResponseEntity<Resource> serve(Long viewerId, Long mediaId, boolean thumb, String ifNoneMatch) {
        ForumMedia m = accessible(viewerId, mediaId).orElseThrow(ForumMediaService::notFound);
        String key = thumb && m.getThumbKey() != null ? m.getThumbKey() : m.getStorageKey();
        String etag = "\"" + key + "\"";
        if (etagMatches(ifNoneMatch, etag)) {
            return ResponseEntity.status(HttpStatus.NOT_MODIFIED).eTag(etag)
                    .cacheControl(CacheControl.maxAge(Duration.ofDays(1)).cachePrivate()).build();
        }
        byte[] data = store.read(BUCKET, key);
        if (data == null) {
            throw notFound();
        }
        MediaType type = key.endsWith(".png") ? MediaType.IMAGE_PNG
                : key.endsWith(".webp") ? MediaType.parseMediaType("image/webp") : MediaType.IMAGE_JPEG;
        return ResponseEntity.ok().contentType(type).contentLength(data.length).eTag(etag)
                .cacheControl(CacheControl.maxAge(Duration.ofDays(1)).cachePrivate())
                .header("X-Content-Type-Options", "nosniff")
                .header("Content-Security-Policy", "default-src 'none'")
                .header(HttpHeaders.CONTENT_DISPOSITION, "inline")
                .body(new ByteArrayResource(data));
    }

    private static boolean etagMatches(String header, String etag) {
        if (header == null || header.isBlank()) {
            return false;
        }
        for (String part : header.split(",")) {
            String t = part.trim();
            if (t.startsWith("W/")) {
                t = t.substring(2);
            }
            if (t.equals(etag) || t.equals("*")) {
                return true;
            }
        }
        return false;
    }

    // ------------------------------------------------------------------ silme / temizlik

    /** Yalnizca konuya eklenmemis kendi yuklemesini siler (yukleme iptali). */
    @Transactional
    public void deleteUnattached(Long userId, Long mediaId) {
        ForumMedia m = repo.findById(mediaId).filter(x -> x.getOwnerId().equals(userId))
                .orElseThrow(ForumMediaService::notFound);
        if (repo.deleteIfUnattached(m.getId()) != 1) {
            throw new ApiException(HttpStatus.CONFLICT, "FORUM_MEDIA_INVALID", "Geçersiz veya kullanılmış görsel.");
        }
        String key = m.getStorageKey();
        afterCommit(() -> store.delete(BUCKET, key));
    }

    /** Hesap silme (KVKK): kullanicinin tum gorselleri ve baytlari. */
    @Transactional
    public int purgeUser(Long userId) {
        List<ForumMedia> rows = repo.findByOwnerId(userId);
        if (rows.isEmpty()) {
            return 0;
        }
        List<Long> ids = rows.stream().map(ForumMedia::getId).toList();
        jdbc.update("DELETE FROM forum_topic_image WHERE media_id IN (SELECT id FROM forum_media WHERE owner_id = ?)",
                userId);
        repo.deleteAll(rows);
        List<String> keys = rows.stream().map(ForumMedia::getStorageKey).toList();
        afterCommit(() -> keys.forEach(k -> store.delete(BUCKET, k)));
        return ids.size();
    }

    /** Baglanmamis ve {@code maxAge}den eski yuklemeleri siler; ardindan satiri olmayan eski dosyalari tarar. */
    public int sweepUnattached(Duration maxAge) {
        int n = 0;
        try {
            for (ForumMedia m : repo.staleUnattached(Instant.now().minus(maxAge), PageRequest.of(0, 500))) {
                try {
                    if (repo.deleteIfUnattached(m.getId()) == 1) {
                        store.delete(BUCKET, m.getStorageKey());
                        n++;
                    }
                } catch (RuntimeException e) {
                    log.warn("Yetim forum gorseli silinemedi {}: {}", m.getId(), e.toString());
                }
            }
            Set<String> known = new HashSet<>();
            boolean[] loaded = {false};
            store.sweep(BUCKET, key -> {
                if (!loaded[0]) {
                    loadKeys(known);
                    loaded[0] = true;
                }
                return known.contains(key);
            }, maxAge);
        } catch (RuntimeException e) {
            log.warn("Forum gorsel temizligi yarim kaldi: {}", e.toString());
        }
        return n;
    }

    private void loadKeys(Set<String> into) {
        long after = 0;
        while (true) {
            List<Object[]> page = repo.keysAfter(after, PageRequest.of(0, 5000));
            for (Object[] r : page) {
                into.add((String) r[1]);
                after = Math.max(after, ((Number) r[0]).longValue());
            }
            if (page.size() < 5000) {
                return;
            }
        }
    }

    /** Silinmesinden bu yana saklama suresi dolan konularin gorselleri diskten ve DB'den kalkar. */
    public int sweepDeleted() {
        int n = 0;
        try {
            Instant before = Instant.now().minus(Duration.ofDays(Math.max(0, deletedRetentionDays)));
            List<Object[]> rows = jdbc.query("SELECT m.id, m.storage_key FROM forum_media m JOIN forum_topic_image i "
                    + "ON i.media_id = m.id JOIN forum_topic t ON t.id = i.topic_id WHERE t.deleted_at IS NOT NULL "
                    + "AND t.deleted_at < ? ORDER BY m.id LIMIT 500",
                    (rs, i) -> new Object[] {rs.getLong(1), rs.getString(2)}, java.sql.Timestamp.from(before));
            for (Object[] r : rows) {
                try {
                    jdbc.update("DELETE FROM forum_topic_image WHERE media_id = ?", r[0]);
                    jdbc.update("DELETE FROM forum_media WHERE id = ?", r[0]);
                    store.delete(BUCKET, (String) r[1]);
                    n++;
                } catch (RuntimeException e) {
                    log.warn("Silinen konunun gorseli temizlenemedi {}: {}", r[0], e.toString());
                }
            }
        } catch (RuntimeException e) {
            log.warn("Silinen forum gorseli temizligi yarim kaldi: {}", e.toString());
        }
        return n;
    }

    private static void afterCommit(Runnable r) {
        edu.bingol.backend.common.AfterCommit.run(r);
    }

    private static ApiException invalid() {
        return new ApiException(HttpStatus.BAD_REQUEST, "FORUM_MEDIA_INVALID", "Geçersiz veya kullanılmış görsel.");
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "FORUM_MEDIA_NOT_FOUND", "Görsel bulunamadı.");
    }
}
