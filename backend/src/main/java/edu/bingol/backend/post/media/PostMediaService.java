package edu.bingol.backend.post.media;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.config.MediaProperties;
import edu.bingol.backend.media.ImageKind;
import edu.bingol.backend.media.MediaUploads;
import edu.bingol.backend.media.Mp4Info;
import edu.bingol.backend.media.PrivateMedia;
import edu.bingol.backend.media.PrivateMediaStore;
import edu.bingol.backend.media.transcode.MediaCdnLinks;
import edu.bingol.backend.media.transcode.VideoTranscoder;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.moderation.ContentBlocklist;
import edu.bingol.backend.post.PostDeletedEvent;
import edu.bingol.backend.post.PostDtos.MediaView;
import edu.bingol.backend.post.spi.PostMediaBinder;
import edu.bingol.backend.post.spi.PostMediaLookup;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.HexFormat;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpRange;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.web.multipart.MultipartFile;

/**
 * Gonderi medyasi: yukleme, gonderiye baglama, yetkili sunum (HTTP Range), moderasyon gizlemesi, temizlik.
 * Baytlar ozel depoda (`_private/post/`, /files/** disinda): gorseller {@code BlobCipher} varsa diskte sifreli;
 * videolar konusma DEK'i olmadigindan duz (poster sifreli). Dosya adlari rastgele UUID.
 * YETKI KURALI TEK YERDE ({@link #accessible}): baglanmamis medya yalniz sahibine; baglanmissa gonderi silinmemis,
 * gizlenmemis, medya gizli degil ve yazarla bakan arasinda engel yok. Aksi her durumda ayni 404.
 */
@Service
public class PostMediaService implements PostMediaLookup, PostMediaBinder {

    public static final String BUCKET = "post";
    /** Poster (onizleme karesi) uzun kenar siniri. */
    static final int POSTER_MAX_DIM = 720;
    private static final Logger log = LoggerFactory.getLogger(PostMediaService.class);

    private final PostMediaRepository repo;
    private final PrivateMediaStore store;
    private final MediaProperties mediaProps;
    private final ContentBlocklist blocklist;
    private final BlockService blocks;
    private final RateLimiter limiter;

    @Value("${app.post.media.video-max-bytes:41943040}")
    private long videoMaxBytes = 40L << 20;
    @Value("${app.post.media.video-max-seconds:60}")
    private int videoMaxSeconds = 60;
    @Value("${app.post.media.uploads-per-hour:30}")
    private int uploadsPerHour = 30;
    @Value("${app.post.media.pending-max:30}")
    private int pendingMax = 30;
    @Value("${app.post.media.max-per-post:10}")
    private int maxPerPost = 10;
    @Value("${app.post.media.max-videos-per-post:10}")
    private int maxVideosPerPost = 10;
    /** Silinen gonderinin medyasi kac gun sonra diskten kalkar (0 = hemen). */
    @Value("${app.post.media.deleted-retention-days:30}")
    private int deletedRetentionDays = 30;

    /** Opsiyonel: ffmpeg donusturme (yoksa/kapaliysa video oldugu gibi saklanir) ve CDN imzali yonlendirme. */
    private VideoTranscoder transcoder;
    private MediaCdnLinks cdn;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    public void setTranscoder(VideoTranscoder transcoder) {
        this.transcoder = transcoder;
    }

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    public void setCdn(MediaCdnLinks cdn) {
        this.cdn = cdn;
    }

    public PostMediaService(PostMediaRepository repo, PrivateMediaStore store, MediaProperties mediaProps,
                            ContentBlocklist blocklist, BlockService blocks, RateLimiter limiter) {
        this.repo = repo;
        this.store = store;
        this.mediaProps = mediaProps;
        this.blocklist = blocklist;
        this.blocks = blocks;
        this.limiter = limiter;
    }

    /** Yukleme yaniti. */
    public record Uploaded(Long id, String kind, String url, String thumbUrl, Integer width, Integer height,
                           Integer durationMs, long bytes) {}

    // ------------------------------------------------------------------ yukleme

    /** `file` video/mp4 ise video (istege bagli `poster`), degilse gorsel hattidir. */
    public Uploaded upload(Long userId, MultipartFile file, MultipartFile poster) {
        limiter.check("postmedia:hour:" + userId, uploadsPerHour, Duration.ofHours(1));
        if (repo.countByOwnerIdAndPostIdIsNullAndStoryIdIsNull(userId) >= pendingMax) {
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "POST_MEDIA_PENDING_LIMIT",
                    "Gönderiye eklenmemiş çok fazla medya var. Önce gönderinizi paylaşın.", String.valueOf(pendingMax));
        }
        return isVideoUpload(file) ? uploadVideo(userId, file, poster) : uploadImage(userId, file);
    }

    private Uploaded uploadImage(Long userId, MultipartFile file) {
        byte[] raw = MediaUploads.read(file, mediaProps.limits(ImageKind.FEED).maxUploadBytes());
        // Hem yuklenen ham bayt hem yeniden kodlanmis cikti ozeti denetlenir
        rejectIfBlocked(raw);
        PrivateMedia pm = store.store(BUCKET, raw, ImageKind.FEED, img -> rejectIfBlocked(img.data()));
        try {
            PostMedia m = new PostMedia();
            m.setOwnerId(userId);
            m.setKind(PostMedia.IMAGE);
            m.setStorageKey(pm.key());
            m.setThumbKey(pm.thumbKey());
            m.setContentType(pm.contentType());
            m.setWidth(pm.width());
            m.setHeight(pm.height());
            m.setBytes(pm.bytes());
            m.setSha256(sha256Hex(raw));
            return toUploaded(repo.save(m));
        } catch (RuntimeException e) {
            store.delete(BUCKET, pm.key());
            throw e;
        }
    }

    private Uploaded uploadVideo(Long userId, MultipartFile file, MultipartFile poster) {
        byte[] raw = readVideo(file);
        Mp4Info.Info info;
        try {
            info = Mp4Info.parse(raw);
        } catch (Mp4Info.Invalid | RuntimeException e) {
            throw videoInvalid();
        }
        if (info.durationMs() <= 0) {
            throw videoInvalid();
        }
        if (info.durationMs() > videoMaxSeconds * 1000L) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VIDEO_TOO_LONG",
                    "Video en fazla " + videoMaxSeconds + " saniye olabilir.", String.valueOf(videoMaxSeconds));
        }
        byte[] posterRaw = poster == null || poster.isEmpty() ? null
                : MediaUploads.read(poster, mediaProps.limits(ImageKind.FEED).maxUploadBytes());
        rejectIfBlocked(raw);
        if (posterRaw != null) {
            rejectIfBlocked(posterRaw);
        }
        // Ana anahtar varsa video dosya-basina DEK ile SIFRELI yazilir (yoksa eski duz yol: gelistirme/test)
        boolean sealed = store.sealedAvailable();
        String[] st;
        String wrapped = null;
        if (sealed) {
            st = store.storeVideoSealed(BUCKET, raw, posterRaw, POSTER_MAX_DIM, img -> rejectIfBlocked(img.data()),
                    ImageKind.FEED);
            wrapped = st[4];
        } else {
            st = store.storeVideoPlain(BUCKET, raw, posterRaw, POSTER_MAX_DIM,
                    img -> rejectIfBlocked(img.data()), ImageKind.FEED);
        }
        try {
            PostMedia m = new PostMedia();
            m.setOwnerId(userId);
            m.setKind(PostMedia.VIDEO);
            m.setStorageKey(st[0]);
            m.setThumbKey(st[1]);
            // Poster varsa onun boyutu (dogru yonelimli kare); yoksa tkhd'den; bilinmiyorsa null
            int w = st[1] != null ? Integer.parseInt(st[2]) : info.width();
            int h = st[1] != null ? Integer.parseInt(st[3]) : info.height();
            m.setWidth(w > 0 ? w : null);
            m.setHeight(h > 0 ? h : null);
            m.setBytes(raw.length);
            m.setContentType("video/mp4");
            m.setDurationMs((int) Math.min(info.durationMs(), Integer.MAX_VALUE));
            m.setSha256(sha256Hex(raw));
            m.setWrappedDek(wrapped);
            m.setEncrypted(sealed);
            // ffmpeg varsa arka planda 720p/H.264'e donusturulur; o zamana dek orijinal sunulur
            if (sealed && transcoder != null && transcoder.available()) {
                m.setTranscodeStatus("PENDING");
            }
            return toUploaded(repo.save(m));
        } catch (RuntimeException e) {
            store.delete(BUCKET, st[0]);
            throw e;
        }
    }

    private static boolean isVideoUpload(MultipartFile file) {
        if (file == null) {
            return false;
        }
        String type = file.getContentType() == null ? "" : file.getContentType().toLowerCase(Locale.ROOT);
        String name = file.getOriginalFilename() == null ? "" : file.getOriginalFilename().toLowerCase(Locale.ROOT);
        return type.startsWith("video/") || name.endsWith(".mp4") || name.endsWith(".mov");
    }

    /** Content-Type video/mp4, boyut siniri, ftyp imzasi; belleğe yalniz sinirli okunur. */
    private byte[] readVideo(MultipartFile file) {
        String type = file.getContentType() == null ? ""
                : file.getContentType().toLowerCase(Locale.ROOT).split(";")[0].trim();
        if (file.isEmpty() || !"video/mp4".equals(type)) {
            throw videoInvalid();
        }
        if (file.getSize() > videoMaxBytes) {
            throw videoTooLarge();
        }
        try (java.io.InputStream in = file.getInputStream()) {
            byte[] data = in.readNBytes((int) videoMaxBytes + 1);
            if (data.length > videoMaxBytes) {
                throw videoTooLarge();
            }
            if (!Mp4Info.hasFtyp(data)) {
                throw videoInvalid();
            }
            return data;
        } catch (IOException e) {
            throw videoInvalid();
        }
    }

    private ApiException videoTooLarge() {
        long mb = Math.max(1, videoMaxBytes / 1024 / 1024);
        return new ApiException(HttpStatus.PAYLOAD_TOO_LARGE, "VIDEO_TOO_LARGE",
                "Video en fazla " + mb + " MB olabilir.", String.valueOf(mb));
    }

    private static ApiException videoInvalid() {
        return new ApiException(HttpStatus.BAD_REQUEST, "VIDEO_INVALID", "Geçersiz video dosyası.");
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

    private static Uploaded toUploaded(PostMedia m) {
        MediaView v = view(m);
        return new Uploaded(m.getId(), m.getKind(), v.url(), v.thumbUrl(), m.getWidth(), m.getHeight(),
                m.getDurationMs(), m.getBytes());
    }

    static MediaView view(PostMedia m) {
        String base = "/api/posts/media/" + m.getId();
        return new MediaView(m.getId(), m.getKind(), base, m.getThumbKey() == null ? null : base + "?thumb=true",
                m.getWidth(), m.getHeight(), m.isVideo() ? m.getDurationMs() : null);
    }

    // ------------------------------------------------------------------ baglama / gorunum (SPI)

    @Override
    @Transactional
    public void attach(long postId, long ownerId, List<Long> mediaIds) {
        if (mediaIds == null || mediaIds.isEmpty()) {
            return;
        }
        if (mediaIds.size() > maxPerPost || new HashSet<>(mediaIds).size() != mediaIds.size()
                || mediaIds.stream().anyMatch(java.util.Objects::isNull)) {
            throw invalid();
        }
        List<PostMedia> rows = repo.findAllById(mediaIds);
        boolean ok = rows.size() == mediaIds.size() && rows.stream().allMatch(
                m -> m.getOwnerId().equals(ownerId) && m.getPostId() == null && !m.isHidden());
        if (!ok || rows.stream().filter(PostMedia::isVideo).count() > maxVideosPerPost) {
            throw invalid();
        }
        short pos = 0;
        for (Long id : mediaIds) {
            // Atomik: yarisan ikinci gonderi ayni medyayi baglayamaz
            if (repo.bind(id, ownerId, postId, pos++) != 1) {
                throw invalid();
            }
        }
    }

    @Override
    @Transactional(readOnly = true)
    public List<Long> mediaIdsOf(long postId) {
        return repo.findByPostIdOrderByPositionAscIdAsc(postId).stream().map(PostMedia::getId).toList();
    }

    @Override
    @Transactional(readOnly = true)
    public Map<Long, List<MediaView>> viewsFor(Collection<Long> postIds, Long viewerId) {
        if (postIds == null || postIds.isEmpty()) {
            return Map.of();
        }
        Map<Long, List<MediaView>> out = new HashMap<>();
        repo.findByPostIdIn(postIds).stream()
                .filter(m -> !m.isHidden())
                .sorted(Comparator.comparing(PostMedia::getPostId).thenComparing(PostMedia::getPosition)
                        .thenComparing(PostMedia::getId))
                .forEach(m -> out.computeIfAbsent(m.getPostId(), k -> new ArrayList<>()).add(view(m)));
        return out;
    }

    // ------------------------------------------------------------------ yetkili sunum

    /** Erisebilir ise medya; degilse bos. Hicbir durumda neden sizdirmaz. */
    @Transactional(readOnly = true)
    public Optional<PostMedia> accessible(Long viewerId, Long mediaId) {
        if (viewerId == null || mediaId == null) {
            return Optional.empty();
        }
        PostMedia m = repo.findById(mediaId).orElse(null);
        if (m == null || m.isHidden()) {
            return Optional.empty();
        }
        if (m.getStoryId() != null) {
            return accessibleStory(viewerId, m);
        }
        if (m.getPostId() == null) {
            return m.getOwnerId().equals(viewerId) ? Optional.of(m) : Optional.empty(); // baglanmamis: yalniz sahibi
        }
        PostMediaRepository.PostState p = repo.postState(m.getPostId()).orElse(null);
        if (p == null || p.getDeletedAt() != null || p.getHiddenAt() != null) {
            return Optional.empty();
        }
        if (!p.getAuthorId().equals(viewerId) && blocks.hiddenFrom(viewerId).contains(p.getAuthorId())) {
            return Optional.empty();
        }
        return Optional.of(m);
    }

    /** Hikaye medyasi: suresi dolmamis, silinmemis/gizlenmemis ve engel iliskisi yok (sahibi kendi medyasini hep gorur). */
    private Optional<PostMedia> accessibleStory(Long viewerId, PostMedia m) {
        PostMediaRepository.StoryState s = repo.storyState(m.getStoryId()).orElse(null);
        if (s == null || s.getDeletedAt() != null) {
            return Optional.empty();
        }
        if (s.getAuthorId().equals(viewerId)) {
            return Optional.of(m);
        }
        if (s.getHiddenAt() != null || s.getExpiresAt().isBefore(Instant.now())
                || blocks.hiddenFrom(viewerId).contains(s.getAuthorId())) {
            return Optional.empty();
        }
        return Optional.of(m);
    }

    /**
     * Kullanici sunumu. Video govdesi icin HTTP Range (206/416) ile dogrudan `resp`a yazar ve null doner;
     * digerleri (gorsel, poster, 304) ResponseEntity'dir.
     */
    public ResponseEntity<Resource> serve(Long viewerId, Long mediaId, boolean thumb, String rangeHeader,
                                          String ifNoneMatch, HttpServletResponse resp) {
        PostMedia m = accessible(viewerId, mediaId).orElseThrow(PostMediaService::notFound);
        if (cdn != null && cdn.redirectEnabled() && !(thumb && m.getThumbKey() == null)) {
            // Yetki yukarida dogrulandi; CDN'e yalniz kisa omurlu imzali URL verilir (bkz. docs/DEPLOY.md bolum 10)
            return ResponseEntity.status(HttpStatus.FOUND).header(HttpHeaders.LOCATION, cdn.url(m.getId(), thumb))
                    .cacheControl(CacheControl.noStore()).build();
        }
        return write(m, thumb, rangeHeader, ifNoneMatch, resp, null);
    }

    /**
     * CDN origin sunumu: yetki imzadadir (cagiran imzayi dogruladi). Gizli/silinmis/gonderisi kapali medya 404.
     * Yanit `public, max-age=<imza omru>`: yalniz imzali URL ile onbelleklenir.
     */
    public ResponseEntity<Resource> serveSigned(Long mediaId, boolean thumb, String rangeHeader, String ifNoneMatch,
                                                long maxAgeSeconds, HttpServletResponse resp) {
        PostMedia m = repo.findById(mediaId).filter(x -> !x.isHidden()).orElseThrow(PostMediaService::notFound);
        if (m.getPostId() == null) {
            throw notFound(); // baglanmamis medya CDN'e verilmez
        }
        PostMediaRepository.PostState p = repo.postState(m.getPostId()).orElse(null);
        if (p == null || p.getDeletedAt() != null || p.getHiddenAt() != null) {
            throw notFound();
        }
        return write(m, thumb, rangeHeader, ifNoneMatch, resp, maxAgeSeconds);
    }

    /** Yonetici: yetki denetimi cagiranda (ADMIN); silinmis/gizli/baglanmamis da akar. */
    public ResponseEntity<Resource> serveForAdmin(Long mediaId, boolean thumb, String rangeHeader,
                                                  String ifNoneMatch, HttpServletResponse resp) {
        PostMedia m = repo.findById(mediaId).orElseThrow(PostMediaService::notFound);
        return write(m, thumb, rangeHeader, ifNoneMatch, resp, null);
    }

    /** @param cdnMaxAge null = oturumlu (private) sunum; degilse CDN icin `public, max-age` saniyesi */
    private ResponseEntity<Resource> write(PostMedia m, boolean thumb, String rangeHeader, String ifNoneMatch,
                                           HttpServletResponse resp, Long cdnMaxAge) {
        String key = thumb ? m.getThumbKey() : m.getStorageKey();
        if (key == null) {
            throw notFound(); // posteri olmayan video
        }
        String etag = "\"" + key + "\"";
        boolean ranged = rangeHeader != null && !rangeHeader.isBlank();
        if (!ranged && etagMatches(ifNoneMatch, etag)) {
            return ResponseEntity.status(HttpStatus.NOT_MODIFIED).eTag(etag)
                    .cacheControl(cacheControl(cdnMaxAge)).build();
        }
        if (m.isVideo() && !thumb) {
            writeVideo(m, rangeHeader, etag, resp, cdnMaxAge);
            return null;
        }
        byte[] data = store.read(BUCKET, key);
        if (data == null) {
            throw notFound();
        }
        MediaType type = key.endsWith(".png") ? MediaType.IMAGE_PNG : MediaType.IMAGE_JPEG;
        return ResponseEntity.ok().contentType(type).contentLength(data.length).eTag(etag)
                .cacheControl(cacheControl(cdnMaxAge))
                .header("X-Content-Type-Options", "nosniff")
                .header("Content-Security-Policy", "default-src 'none'")
                .header(HttpHeaders.CONTENT_DISPOSITION, "inline")
                .body(new ByteArrayResource(data));
    }

    /** Oturumlu sunum: private 1 gun. CDN (imzali URL): public, imza omru kadar. */
    private static CacheControl cacheControl(Long cdnMaxAge) {
        return cdnMaxAge == null ? CacheControl.maxAge(Duration.ofDays(1)).cachePrivate()
                : CacheControl.maxAge(Duration.ofSeconds(cdnMaxAge)).cachePublic();
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

    private void writeVideo(PostMedia m, String rangeHeader, String etag, HttpServletResponse resp, Long cdnMaxAge) {
        long len = m.getBytes();
        long start = 0;
        long end = len - 1;
        int status = HttpStatus.OK.value();
        if (rangeHeader != null && !rangeHeader.isBlank()) {
            try {
                List<HttpRange> ranges = HttpRange.parseRanges(rangeHeader);
                if (!ranges.isEmpty()) {
                    start = ranges.get(0).getRangeStart(len);
                    end = ranges.get(0).getRangeEnd(len);
                    status = HttpStatus.PARTIAL_CONTENT.value();
                }
            } catch (IllegalArgumentException e) {
                start = len; // gecersiz aralik: asagida 416
            }
        }
        resp.setHeader(HttpHeaders.ACCEPT_RANGES, "bytes");
        if (len <= 0 || start >= len || start > end) {
            resp.setStatus(HttpStatus.REQUESTED_RANGE_NOT_SATISFIABLE.value());
            resp.setHeader(HttpHeaders.CONTENT_RANGE, "bytes */" + len);
            return;
        }
        resp.setStatus(status);
        resp.setContentType("video/mp4");
        resp.setHeader(HttpHeaders.CACHE_CONTROL, cacheControl(cdnMaxAge).getHeaderValue());
        resp.setHeader(HttpHeaders.ETAG, etag);
        resp.setHeader("X-Content-Type-Options", "nosniff");
        resp.setHeader(HttpHeaders.CONTENT_DISPOSITION, "inline");
        resp.setHeader(HttpHeaders.CONTENT_LENGTH, String.valueOf(end - start + 1));
        if (status == HttpStatus.PARTIAL_CONTENT.value()) {
            resp.setHeader(HttpHeaders.CONTENT_RANGE, "bytes " + start + "-" + end + "/" + len);
        }
        try {
            if (m.isEncrypted() && m.getWrappedDek() != null) {
                store.streamSealedVideo(BUCKET, m.getStorageKey(), m.getWrappedDek(), start, end, resp.getOutputStream());
            } else {
                store.streamVideo(BUCKET, m.getStorageKey(), 0L, start, end, resp.getOutputStream()); // eski duz kayit
            }
        } catch (IOException e) {
            log.debug("Gonderi videosu akisi kesildi ({}): {}", m.getId(), e.toString()); // istemci kapatmis olabilir
        } catch (RuntimeException e) {
            log.warn("Gonderi videosu okunamadi ({}): {}", m.getId(), e.toString());
        }
    }

    // ------------------------------------------------------------------ moderasyon

    /** Moderasyon gizlemesi (E cagirir): gonderinin tum medyasi erisime kapanir. Idempotent. */
    @Transactional
    public void hide(Long postId) {
        repo.hideByPost(postId, Instant.now());
    }

    /** Gizlemeyi geri al. Idempotent. */
    @Transactional
    public void unhide(Long postId) {
        repo.unhideByPost(postId);
    }

    // ------------------------------------------------------------------ silme / KVKK / temizlik

    /**
     * Gonderi silinince (soft): erisim zaten kapanir (gonderi silinmis). Saklama suresi 0 ise baytlar hemen
     * kalkar; aksi halde {@link #sweepDeleted} suresi dolunca temizler.
     */
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void onPostDeleted(PostDeletedEvent ev) {
        if (deletedRetentionDays > 0 || ev.mediaIds() == null || ev.mediaIds().isEmpty()) {
            return;
        }
        try {
            for (PostMedia m : repo.findAllById(ev.mediaIds())) {
                removeNow(m);
            }
        } catch (RuntimeException e) {
            log.warn("Silinen gonderinin medyasi temizlenemedi ({}): {}", ev.postId(), e.toString());
        }
    }

    /** Hesap silme (KVKK, E cagirir): kullanicinin tum medyasi ve baytlari kaldirilir. */
    @Transactional
    public int purgeUser(Long userId) {
        List<PostMedia> rows = repo.findByOwnerId(userId);
        rows.forEach(this::remove);
        return rows.size();
    }

    /** Hikaye temizligi (post.story): verilen hikayelerin medya satirlari ve baytlari kaldirilir. */
    @Transactional
    public int removeStoryMedia(Collection<Long> storyIds) {
        if (storyIds == null || storyIds.isEmpty()) {
            return 0;
        }
        List<PostMedia> rows = repo.findByStoryIdIn(storyIds);
        rows.forEach(this::remove);
        return rows.size();
    }

    /** Yalnizca gonderilmemis kendi yuklemesini siler (yukleme iptali). */
    @Transactional
    public void deleteUnattached(Long userId, Long mediaId) {
        PostMedia m = repo.findById(mediaId).filter(x -> x.getOwnerId().equals(userId)).orElseThrow(
                PostMediaService::notFound);
        if (m.getPostId() != null) {
            throw new ApiException(HttpStatus.CONFLICT, "POST_MEDIA_IN_USE", "Gönderiye eklenmiş medya silinemez.");
        }
        remove(m);
    }

    private void remove(PostMedia m) {
        String key = m.getStorageKey();
        repo.delete(m);
        afterCommit(() -> store.delete(BUCKET, key));
    }

    private void removeNow(PostMedia m) {
        String key = m.getStorageKey();
        repo.delete(m);
        store.delete(BUCKET, key);
    }

    /** Baglanmamis ve `maxAge`den eski yuklemeleri siler; ardindan satiri olmayan eski dosyalari tarar. */
    public int sweepUnattached(Duration maxAge) {
        int n = 0;
        try {
            for (PostMedia m : repo.stale(Instant.now().minus(maxAge), PageRequest.of(0, 500))) {
                try {
                    if (repo.deleteIfUnattached(m.getId()) == 1) {
                        store.delete(BUCKET, m.getStorageKey());
                        n++;
                    }
                } catch (RuntimeException e) {
                    log.warn("Yetim gonderi medyasi silinemedi {}: {}", m.getId(), e.toString());
                }
            }
            store.sweep(BUCKET, repo::existsByStorageKey, maxAge);
        } catch (RuntimeException e) {
            log.warn("Gonderi medyasi temizligi yarim kaldi: {}", e.toString());
        }
        return n;
    }

    /** Silinmesinden bu yana saklama suresi (varsayilan 30 gun) dolan gonderilerin medyasini diskten ve DB'den kaldirir. */
    public int sweepDeleted() {
        int n = 0;
        try {
            Instant before = Instant.now().minus(Duration.ofDays(Math.max(0, deletedRetentionDays)));
            for (PostMedia m : repo.ofPostsDeletedBefore(before, PageRequest.of(0, 500))) {
                try {
                    removeNow(m);
                    n++;
                } catch (RuntimeException e) {
                    log.warn("Silinen gonderinin medyasi temizlenemedi {}: {}", m.getId(), e.toString());
                }
            }
        } catch (RuntimeException e) {
            log.warn("Silinen gonderi medyasi temizligi yarim kaldi: {}", e.toString());
        }
        return n;
    }

    private static void afterCommit(Runnable r) {
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    r.run();
                }
            });
        } else {
            r.run();
        }
    }

    private static ApiException invalid() {
        return new ApiException(HttpStatus.BAD_REQUEST, "POST_MEDIA_INVALID", "Geçersiz veya kullanılmış medya.");
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "POST_MEDIA_NOT_FOUND", "Medya bulunamadı.");
    }

    // Test erisimi
    void setDeletedRetentionDays(int days) {
        this.deletedRetentionDays = days;
    }

    void setVideoLimits(long maxBytes, int maxSeconds) {
        this.videoMaxBytes = maxBytes;
        this.videoMaxSeconds = maxSeconds;
    }

    void setPendingMax(int n) {
        this.pendingMax = n;
    }
}
