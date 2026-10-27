package edu.bingol.backend.messaging.media;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.config.MediaProperties;
import edu.bingol.backend.media.ImageKind;
import edu.bingol.backend.media.MediaUploads;
import edu.bingol.backend.media.MediaUrlSigner;
import edu.bingol.backend.media.PrivateMedia;
import edu.bingol.backend.media.PrivateMediaStore;
import edu.bingol.backend.messaging.Conversation;
import edu.bingol.backend.messaging.ConversationMember;
import edu.bingol.backend.messaging.ConversationMemberRepository;
import edu.bingol.backend.messaging.ConversationRepository;
import edu.bingol.backend.messaging.Message;
import edu.bingol.backend.messaging.MessageRepository;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.moderation.ContentBlocklist;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DataIntegrityViolationException;
import edu.bingol.backend.messaging.dto.MessagingDtos.ViewedEvent;
import edu.bingol.backend.messaging.ws.ChatEventBus;
import edu.bingol.backend.media.Mp4Info;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpRange;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.web.multipart.MultipartFile;

/**
 * Sohbet gorselleri: yukleme, mesaja baglama, yetkili okuma, gizleme/silme. Mesaj tablosuna dokunmaz (T13 ile
 * cakismasin diye ayri tablo). Baytlar T1 ozel deposundadir (diskte sifreli, /files/** disinda).
 * YETKI KURALI TEK YERDE ({@link #accessible}): uye + (grupta katilim sonrasi mesaj) + mesaj/ek gizli degil +
 * engel/askida yukleyen degil. Aksi her durumda ayni 404 (varlik sizmaz).
 */
@Service
public class MessageAttachmentService {

    public static final String BUCKET = "chat";
    private static final Logger log = LoggerFactory.getLogger(MessageAttachmentService.class);

    private final MessageAttachmentRepository repo;
    private final ConversationRepository convs;
    private final ConversationMemberRepository members;
    private final MessageRepository messages;
    private final UserRepository users;
    private final BlockService blocks;
    private final RateLimiter limiter;
    private final PrivateMediaStore store;
    private final MediaUrlSigner signer;
    private final MediaProperties mediaProps;
    private final ContentBlocklist blocklist;
    private final int perMinute;
    private final int perDay;
    private final int maxPerMessage;
    private final int pendingMax;
    private final int linkTtlSeconds;

    public MessageAttachmentService(MessageAttachmentRepository repo, ConversationRepository convs,
                                    ConversationMemberRepository members, MessageRepository messages,
                                    UserRepository users, BlockService blocks, RateLimiter limiter,
                                    PrivateMediaStore store, MediaUrlSigner signer, MediaProperties mediaProps,
                                    ContentBlocklist blocklist,
                                    @Value("${app.chat.media.uploads-per-minute:20}") int perMinute,
                                    @Value("${app.chat.media.uploads-per-day:200}") int perDay,
                                    @Value("${app.chat.media.max-attachments-per-message:${app.chat.media.max-per-message:10}}") int maxPerMessage,
                                    @Value("${app.chat.media.pending-max:30}") int pendingMax,
                                    @Value("${app.chat.media.link-ttl-seconds:300}") int linkTtlSeconds) {
        this.repo = repo;
        this.convs = convs;
        this.members = members;
        this.messages = messages;
        this.users = users;
        this.blocks = blocks;
        this.limiter = limiter;
        this.store = store;
        this.signer = signer;
        this.mediaProps = mediaProps;
        this.blocklist = blocklist;
        this.perMinute = perMinute;
        this.perDay = perDay;
        this.maxPerMessage = maxPerMessage;
        this.pendingMax = pendingMax;
        this.linkTtlSeconds = linkTtlSeconds;
    }

    public int maxPerMessage() {
        return maxPerMessage;
    }

    // Tek gosterimlik destegi (setter enjeksiyonu: yapici imzasi degismesin)
    private MessageAttachmentViewRepository viewsRepo;
    private ChatEventBus bus;
    @Value("${app.chat.media.view-once-ttl-hours:24}")
    private int viewOnceTtlHours = 24;

    // Video mesaj sinirlari (varsayilanlar application.properties ile ayni)
    @Value("${app.chat.media.video-max-bytes:41943040}")
    private long videoMaxBytes = 40L << 20;
    @Value("${app.chat.media.video-max-seconds:60}")
    private int videoMaxSeconds = 60;
    /** Bir mesajdaki tum videolarin bayt toplami ustu (varsayilan 120 MB). */
    @Value("${app.chat.media.video-max-total-bytes-per-message:125829120}")
    private long videoMaxTotalBytes = 120L << 20;
    @Value("${app.chat.media.video-daily-limit:30}")
    private int videoDailyLimit = 30;
    /** Poster (onizleme karesi) uzun kenar siniri. */
    static final int POSTER_MAX_DIM = 720;

    @Autowired(required = false)
    void setViewsRepo(MessageAttachmentViewRepository viewsRepo) {
        this.viewsRepo = viewsRepo;
    }

    @Autowired(required = false)
    void setBus(ChatEventBus bus) {
        this.bus = bus;
    }

    // ------------------------------------------------------------------ yukleme

    public AttachmentView upload(Long userId, Long conversationId, MultipartFile file) {
        return upload(userId, conversationId, file, null);
    }

    /** `file` video/mp4 ise video (istege bagli `poster` ile), degilse gorsel hattidir. */
    public AttachmentView upload(Long userId, Long conversationId, MultipartFile file, MultipartFile poster) {
        if (isVideoUpload(file)) {
            return uploadVideo(userId, conversationId, file, poster);
        }
        limiter.check("chatmedia:min:" + userId, perMinute, Duration.ofMinutes(1));
        limiter.check("chatmedia:day:" + userId, perDay, Duration.ofDays(1));
        requireCanSend(userId, conversationId);
        if (repo.countByUploaderIdAndMessageIdIsNull(userId) >= pendingMax) {
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "CHAT_MEDIA_PENDING_LIMIT",
                    "Gönderilmemiş çok fazla görsel var. Önce mevcut görselleri gönderin.", String.valueOf(pendingMax));
        }
        byte[] raw = MediaUploads.read(file, mediaProps.limits(ImageKind.CHAT).maxUploadBytes());
        // Yasakli icerik: hem yuklenen ham bayt hem yeniden kodlanmis cikti ozeti (yonetici hangisini eklediyse yakalanir)
        rejectIfBlocked(raw);
        PrivateMedia pm = store.store(BUCKET, raw, ImageKind.CHAT, img -> rejectIfBlocked(img.data()));
        try {
            MessageAttachment a = new MessageAttachment();
            a.setConversationId(conversationId);
            a.setUploaderId(userId);
            a.setStorageKey(pm.key());
            a.setThumbKey(pm.thumbKey());
            a.setWidth(pm.width());
            a.setHeight(pm.height());
            a.setBytes(pm.bytes());
            a.setContentType(pm.contentType());
            return AttachmentView.of(repo.save(a));
        } catch (RuntimeException e) {
            store.delete(BUCKET, pm.key());
            throw e;
        }
    }

    private static boolean isVideoUpload(MultipartFile file) {
        if (file == null) {
            return false;
        }
        String type = file.getContentType() == null ? "" : file.getContentType().toLowerCase(java.util.Locale.ROOT);
        String name = file.getOriginalFilename() == null ? "" : file.getOriginalFilename().toLowerCase(java.util.Locale.ROOT);
        return type.startsWith("video/") || name.endsWith(".mp4") || name.endsWith(".mov");
    }

    private AttachmentView uploadVideo(Long userId, Long conversationId, MultipartFile file, MultipartFile poster) {
        limiter.check("chatmedia:min:" + userId, perMinute, Duration.ofMinutes(1));
        limiter.check("chatmedia:day:" + userId, perDay, Duration.ofDays(1));
        limiter.check("chatvideo:day:" + userId, videoDailyLimit, Duration.ofDays(1));
        requireCanSend(userId, conversationId);
        if (repo.countByUploaderIdAndMessageIdIsNull(userId) >= pendingMax) {
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "CHAT_MEDIA_PENDING_LIMIT",
                    "Gönderilmemiş çok fazla görsel var. Önce mevcut görselleri gönderin.", String.valueOf(pendingMax));
        }
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
                : MediaUploads.read(poster, mediaProps.limits(ImageKind.CHAT).maxUploadBytes());
        rejectIfBlocked(raw);
        if (posterRaw != null) {
            rejectIfBlocked(posterRaw);
        }
        String[] st = store.storeVideo(BUCKET, conversationId, raw, posterRaw, POSTER_MAX_DIM,
                img -> rejectIfBlocked(img.data()));
        try {
            MessageAttachment a = new MessageAttachment();
            a.setConversationId(conversationId);
            a.setUploaderId(userId);
            a.setKind("VIDEO");
            a.setStorageKey(st[0]);
            a.setThumbKey(st[1]);
            // Poster varsa onun boyutu (dogru yonelimli kare); yoksa tkhd'den; ikisi de yoksa 0 (gorunumde null)
            a.setWidth(st[1] != null ? Integer.parseInt(st[2]) : info.width());
            a.setHeight(st[1] != null ? Integer.parseInt(st[3]) : info.height());
            a.setBytes(raw.length);
            a.setContentType("video/mp4");
            a.setDurationMs((int) Math.min(info.durationMs(), Integer.MAX_VALUE));
            return AttachmentView.of(repo.save(a));
        } catch (RuntimeException e) {
            store.delete(BUCKET, st[0]);
            throw e;
        }
    }

    /** Content-Type video/mp4, boyut siniri, ftyp imzasi; belleğe yalniz sinirli (video-max-bytes) okunur. */
    private byte[] readVideo(MultipartFile file) {
        String type = file.getContentType() == null ? ""
                : file.getContentType().toLowerCase(java.util.Locale.ROOT).split(";")[0].trim();
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
        } catch (java.io.IOException e) {
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
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "MEDIA_BLOCKED",
                    "Bu görsel yüklenemez.");
        }
    }

    static String sha256Hex(byte[] data) {
        try {
            return java.util.HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(data));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    /** Gonderen uye mi, hesabi aktif mi, birebirde engel/askida karsi taraf var mi. */
    private void requireCanSend(Long userId, Long conversationId) {
        members.findByConversationIdAndUserIdAndLeftAtIsNull(conversationId, userId)
                .orElseThrow(MessageAttachmentService::convNotFound);
        if (users.findById(userId).filter(User::isActive).isEmpty()) {
            throw new ApiException(HttpStatus.FORBIDDEN, "ACCOUNT_SUSPENDED", "Hesabınız askıya alındı.");
        }
        Conversation conv = convs.findById(conversationId).orElseThrow(MessageAttachmentService::convNotFound);
        if (conv.getType() == Conversation.Type.DIRECT) {
            Long peer = members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(conversationId).stream()
                    .map(ConversationMember::getUserId).filter(id -> !id.equals(userId)).findFirst()
                    .orElseThrow(MessageAttachmentService::convNotFound);
            // Golge engel: engel iliskisinde de yukleme serbest (mesaj gonderimde bastirilir; kota yine sayilir)
            if (users.findById(peer).filter(User::isActive).isEmpty()) {
                throw new ApiException(HttpStatus.FORBIDDEN, "USER_UNAVAILABLE", "Bu kullanıcıya mesaj gönderilemez.");
            }
        }
    }

    // ------------------------------------------------------------------ mesaja baglama

    /** Gonderimden once hizli dogrulama (sayi, tekrar, sahiplik). Gecersiz her durumda ayni 400. */
    public List<Long> precheck(Long senderId, Long conversationId, List<Long> ids) {
        return precheck(senderId, conversationId, ids, false);
    }

    /** `viewOnce` icin video reddedilir (VIEW_ONCE_INVALID); mesajdaki video bayt toplami sinirli (MESSAGE_MEDIA_TOO_LARGE). */
    public List<Long> precheck(Long senderId, Long conversationId, List<Long> ids, boolean viewOnce) {
        if (ids == null || ids.isEmpty()) {
            return List.of();
        }
        if (ids.size() > maxPerMessage) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "ATTACHMENT_LIMIT",
                    "Bir mesaja en fazla " + maxPerMessage + " görsel eklenebilir.", String.valueOf(maxPerMessage));
        }
        Set<Long> uniq = new HashSet<>(ids);
        if (uniq.size() != ids.size() || uniq.contains(null)) {
            throw invalid();
        }
        List<MessageAttachment> rows = repo.findAllById(ids);
        boolean ok = rows.size() == ids.size() && rows.stream().allMatch(a -> a.getUploaderId().equals(senderId)
                && a.getConversationId().equals(conversationId) && a.getMessageId() == null && !a.isHidden());
        if (!ok) {
            // Tekrar gonderim (ayni clientId) mesaj zaten baglandiysa servis bunu once yakalar; burada gercek hata
            throw invalid();
        }
        long videos = rows.stream().filter(MessageAttachment::isVideo).count();
        if (viewOnce && videos > 0) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VIEW_ONCE_INVALID",
                    "Tek gösterimlik mesajda tam olarak bir görsel olmalıdır.");
        }
        long videoBytes = rows.stream().filter(MessageAttachment::isVideo).mapToLong(MessageAttachment::getBytes).sum();
        if (videoBytes > videoMaxTotalBytes) {
            long mb = Math.max(1, videoMaxTotalBytes / 1024 / 1024);
            throw new ApiException(HttpStatus.PAYLOAD_TOO_LARGE, "MESSAGE_MEDIA_TOO_LARGE",
                    "Bir mesajdaki videolar toplamda en fazla " + mb + " MB olabilir.", String.valueOf(mb));
        }
        return List.copyOf(ids);
    }

    /** Mesaj kaydiyla AYNI transaction'da cagrilir; yarisan ikinci mesaj sayiyi tutturamaz ve geri alinir. */
    @Transactional
    public void claim(Long messageId, Long senderId, Long conversationId, List<Long> ids) {
        if (ids == null || ids.isEmpty()) {
            return;
        }
        int n = repo.claim(messageId, ids, senderId, conversationId);
        if (n != ids.size()) {
            throw invalid();
        }
    }

    /** Tek gosterimlik mesaj: `claim` + ekleri `viewOnce` isaretler (ayni transaction). */
    @Transactional
    public void claim(Long messageId, Long senderId, Long conversationId, List<Long> ids, boolean viewOnce) {
        claim(messageId, senderId, conversationId, ids);
        if (viewOnce && ids != null && !ids.isEmpty()) {
            repo.markViewOnce(ids);
        }
    }

    /** Mesajin (gizli olmayan) eki var mi; duzenlemede bos metne izin vermek icin. */
    @Transactional(readOnly = true)
    public boolean hasAttachments(Long messageId) {
        return repo.existsByMessageId(messageId);
    }

    /** Mesaj kimligine gore ek gorunumleri (gizlenenler `removed`). */
    @Transactional(readOnly = true)
    public Map<Long, List<AttachmentView>> viewsFor(Collection<Long> messageIds) {
        if (messageIds == null || messageIds.isEmpty()) {
            return Map.of();
        }
        Map<Long, List<AttachmentView>> out = new HashMap<>();
        repo.findByMessageIdIn(messageIds).stream()
                .sorted(java.util.Comparator.comparing(MessageAttachment::getId))
                .forEach(a -> out.computeIfAbsent(a.getMessageId(), k -> new ArrayList<>()).add(AttachmentView.of(a)));
        return out;
    }

    /**
     * Goruntuleyene gore ek gorunumleri: tek gosterimlikte alici icin `viewed` = ben actim mi, gonderen icin
     * en az bir alici acti mi; url/thumbUrl sizdirilmaz ({@link AttachmentView#of(MessageAttachment, Long, boolean)}).
     */
    @Transactional(readOnly = true)
    public Map<Long, List<AttachmentView>> viewsFor(Long viewerId, Collection<Long> messageIds) {
        if (messageIds == null || messageIds.isEmpty()) {
            return Map.of();
        }
        List<MessageAttachment> rows = repo.findByMessageIdIn(messageIds);
        List<Long> once = rows.stream().filter(MessageAttachment::isViewOnce).map(MessageAttachment::getId).toList();
        Set<Long> mine = Set.of();
        Set<Long> any = Set.of();
        if (!once.isEmpty() && viewsRepo != null) {
            mine = new HashSet<>(viewsRepo.viewedBy(viewerId, once));
            any = new HashSet<>(viewsRepo.viewedByAnyone(once));
        }
        Map<Long, List<AttachmentView>> out = new HashMap<>();
        for (MessageAttachment a : rows.stream().sorted(java.util.Comparator.comparing(MessageAttachment::getId)).toList()) {
            boolean viewed = a.isViewOnce()
                    && (a.getUploaderId().equals(viewerId) ? any.contains(a.getId()) : mine.contains(a.getId()));
            out.computeIfAbsent(a.getMessageId(), k -> new ArrayList<>()).add(AttachmentView.of(a, viewerId, viewed));
        }
        return out;
    }

    // ------------------------------------------------------------------ yetkili okuma

    /** Erisebilir ise ek; degilse bos. Hicbir durumda neden sizdirmaz. */
    @Transactional(readOnly = true)
    public Optional<MessageAttachment> accessible(Long userId, Long conversationId, Long attachmentId) {
        if (userId == null || conversationId == null || attachmentId == null) {
            return Optional.empty();
        }
        MessageAttachment a = repo.findById(attachmentId).filter(x -> x.getConversationId().equals(conversationId))
                .orElse(null);
        if (a == null || a.isHidden()) {
            return Optional.empty();
        }
        ConversationMember me = members.findByConversationIdAndUserIdAndLeftAtIsNull(conversationId, userId).orElse(null);
        if (me == null || users.findById(userId).filter(User::isActive).isEmpty()) {
            return Optional.empty();
        }
        boolean mine = a.getUploaderId().equals(userId);
        if (a.getMessageId() == null) {
            return mine ? Optional.of(a) : Optional.empty(); // gonderilmemis yukleme yalniz sahibine
        }
        Message m = messages.findById(a.getMessageId()).orElse(null);
        if (m == null || m.isHidden() || m.isDeleted() || (m.isSuppressed() && !mine)) {
            return Optional.empty();
        }
        Conversation conv = convs.findById(conversationId).orElse(null);
        if (conv == null || m.getId() <= me.getClearedUpToMessageId()) { // "sohbeti sil" oncesi mesajin eki
            return Optional.empty();
        }
        // Gruba sonradan katilan, katilmadan onceki mesajlarin eklerini gormez (gecmisle tutarli)
        if (conv.getType() == Conversation.Type.GROUP && m.getCreatedAt().isBefore(me.getJoinedAt())) {
            return Optional.empty();
        }
        if (!mine) {
            if (blocks.hiddenFrom(userId).contains(a.getUploaderId())
                    || users.findById(a.getUploaderId()).filter(User::isActive).isEmpty()) {
                return Optional.empty();
            }
        }
        return Optional.of(a);
    }

    public MessageAttachment require(Long userId, Long conversationId, Long attachmentId) {
        return accessible(userId, conversationId, attachmentId).orElseThrow(MessageAttachmentService::notFound);
    }

    /** Dogrudan akis (Bearer): no-store + private. */
    public ResponseEntity<Resource> stream(Long userId, Long conversationId, Long attachmentId, boolean thumb) {
        MessageAttachment a = require(userId, conversationId, attachmentId);
        if (a.isViewOnce()) {
            if (thumb) {
                throw notFound(); // onizleme sizdirilmaz
            }
            return openViewOnce(userId, a);
        }
        if (a.isVideo() && !thumb) {
            throw notFound(); // video yalniz Range destekli uctan (serve) akar
        }
        if (thumb && a.getThumbKey() == null) {
            throw notFound(); // posteri olmayan video
        }
        return privateNoStore(store.serve(BUCKET, thumb ? a.getThumbKey() : a.getStorageKey()));
    }

    /**
     * Denetleyici girisi: video govdesi icin HTTP Range (206/416) ile dogrudan `resp`a yazar ve null doner;
     * diger her sey (gorsel, poster) {@link #stream} ile ayni ResponseEntity'dir. Yetki ayni ({@link #accessible}).
     */
    public ResponseEntity<Resource> serve(Long userId, Long conversationId, Long attachmentId, boolean thumb,
                                          String rangeHeader, HttpServletResponse resp) {
        MessageAttachment a = require(userId, conversationId, attachmentId);
        if (a.isVideo() && !thumb) {
            writeVideo(a, rangeHeader, resp);
            return null;
        }
        return stream(userId, conversationId, attachmentId, thumb);
    }

    private void writeVideo(MessageAttachment a, String rangeHeader, HttpServletResponse resp) {
        long len = a.getBytes();
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
        resp.setHeader(HttpHeaders.CACHE_CONTROL, CacheControl.noStore().cachePrivate().getHeaderValue());
        resp.setHeader("X-Content-Type-Options", "nosniff");
        resp.setHeader(HttpHeaders.CONTENT_DISPOSITION, "inline");
        resp.setHeader(HttpHeaders.CONTENT_LENGTH, String.valueOf(end - start + 1));
        if (status == HttpStatus.PARTIAL_CONTENT.value()) {
            resp.setHeader(HttpHeaders.CONTENT_RANGE, "bytes " + start + "-" + end + "/" + len);
        }
        try {
            store.streamVideo(BUCKET, a.getStorageKey(), a.getConversationId(), start, end, resp.getOutputStream());
        } catch (java.io.IOException e) {
            log.debug("Video akisi kesildi (ek {}): {}", a.getId(), e.toString()); // istemci kapatmis olabilir
        } catch (RuntimeException e) {
            log.warn("Video okunamadi (ek {}): {}", a.getId(), e.toString());
        }
    }

    /**
     * Tek gosterimlik acis: gonderen 403; ikinci ve sonraki acis 410. Baytlar once okunur (okunamazsa kayit
     * tuketilmez); (attachment_id, user_id) birincil anahtari eszamanli ikinci istegi eler. Birebirde (ya da tum
     * alicilar acinca) baytlar silinir; yalniz goruntuleme kaydi kalir.
     */
    private ResponseEntity<Resource> openViewOnce(Long userId, MessageAttachment a) {
        if (a.getUploaderId().equals(userId)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "MEDIA_VIEW_ONCE_OWN", "Tek gösterimlik görselinizi açamazsınız.");
        }
        if (a.getPurgedAt() != null || viewsRepo.existsByAttachmentIdAndUserId(a.getId(), userId)) {
            throw expired();
        }
        ResponseEntity<Resource> res = store.serve(BUCKET, a.getStorageKey());
        if (res.getStatusCode().isError()) {
            throw expired(); // bayt yok (silinmis)
        }
        try {
            viewsRepo.saveAndFlush(new MessageAttachmentView(a.getId(), userId));
        } catch (DataIntegrityViolationException e) {
            throw expired(); // eszamanli ikinci istek
        }
        afterViewed(a, userId);
        HttpHeaders h = new HttpHeaders();
        h.putAll(res.getHeaders());
        h.set(HttpHeaders.CACHE_CONTROL, CacheControl.noStore().cachePrivate().getHeaderValue());
        h.set(HttpHeaders.CONTENT_DISPOSITION, "inline");
        return ResponseEntity.status(res.getStatusCode()).headers(h).body(res.getBody());
    }

    /** Gondericiye "viewed" olayi; tum alicilar actiysa baytlar silinir. Hata acisi bozmaz. */
    private void afterViewed(MessageAttachment a, Long viewerId) {
        try {
            long recipients = members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(a.getConversationId())
                    .stream().filter(m -> !m.getUserId().equals(a.getUploaderId())).count();
            if (viewsRepo.countByAttachmentId(a.getId()) >= recipients) {
                purge(a);
            }
            if (bus != null) {
                bus.publish("message-events", List.of(a.getUploaderId()), new ViewedEvent("viewed",
                        a.getConversationId(), a.getMessageId(), a.getId(), viewerId, Instant.now().toString(), null));
            }
        } catch (RuntimeException e) {
            log.warn("Tek gosterimlik acis sonrasi islem basarisiz (ek {}): {}", a.getId(), e.toString());
        }
    }

    /** Baytlari diskten siler, satiri (ve goruntuleme kayitlarini) tutar. Idempotent. */
    void purge(MessageAttachment a) {
        if (a.getPurgedAt() != null) {
            return;
        }
        a.setPurgedAt(Instant.now());
        repo.save(a);
        store.delete(BUCKET, a.getStorageKey());
    }

    /** Suresi dolan (varsayilan 24 sa) tek gosterimlik eklerin baytlarini siler; silinen sayisi doner. */
    public int purgeExpiredViewOnce() {
        int n = 0;
        try {
            Instant before = Instant.now().minus(Duration.ofHours(Math.max(1, viewOnceTtlHours)));
            for (MessageAttachment a : repo.expiredViewOnce(before, PageRequest.of(0, 500))) {
                try {
                    purge(a);
                    n++;
                } catch (RuntimeException e) {
                    log.warn("Tek gosterimlik ek silinemedi {}: {}", a.getId(), e.toString());
                }
            }
        } catch (RuntimeException e) {
            log.warn("Tek gosterimlik temizlik yarim kaldi: {}", e.toString());
        }
        return n;
    }

    /** Yonetici onizlemesi icin: yetki denetimi cagiranda (ADMIN), gizli ekler dahil. */
    public ResponseEntity<Resource> streamForAdmin(Long attachmentId, boolean thumb) {
        return streamForAdmin(attachmentId, thumb, null, null);
    }

    /** Video govdesi `resp`a Range destekli yazilir (null doner); poster/gorsel ResponseEntity. */
    public ResponseEntity<Resource> streamForAdmin(Long attachmentId, boolean thumb, String rangeHeader,
                                                   HttpServletResponse resp) {
        MessageAttachment a = repo.findById(attachmentId).orElseThrow(MessageAttachmentService::notFound);
        if (a.isVideo() && !thumb && resp != null) {
            writeVideo(a, rangeHeader, resp);
            return null;
        }
        if (thumb ? a.getThumbKey() == null : a.isVideo()) {
            throw notFound();
        }
        return privateNoStore(store.serve(BUCKET, thumb ? a.getThumbKey() : a.getStorageKey()));
    }

    private static ResponseEntity<Resource> privateNoStore(ResponseEntity<Resource> r) {
        if (r.getStatusCode().isError()) {
            return ResponseEntity.notFound().build();
        }
        HttpHeaders h = new HttpHeaders();
        h.putAll(r.getHeaders());
        h.set(HttpHeaders.CACHE_CONTROL, CacheControl.noStore().cachePrivate().getHeaderValue());
        return ResponseEntity.status(r.getStatusCode()).headers(h).body(r.getBody());
    }

    /** <img> icin kisa omurlu imzali adresler. Gizleme/silme ANAHTARI degistirdiginden eski adresler olur. */
    public AttachmentView.Link link(Long userId, Long conversationId, Long attachmentId) {
        MessageAttachment a = require(userId, conversationId, attachmentId);
        if (a.isViewOnce()) {
            throw notFound(); // paylasilabilir adres uretilmez
        }
        Duration ttl = Duration.ofSeconds(Math.max(30, linkTtlSeconds));
        Instant exp = Instant.now().plus(ttl.compareTo(Duration.ofHours(1)) > 0 ? Duration.ofHours(1) : ttl);
        String thumbUrl = a.getThumbKey() == null ? null : signer.sign(BUCKET, a.getThumbKey(), ttl);
        // Video govdesi imzali adresle verilmez (Range + konusma anahtari gerekir): url null, yalniz poster adresi
        return new AttachmentView.Link(a.isVideo() ? null : signer.sign(BUCKET, a.getStorageKey(), ttl), thumbUrl,
                exp.getEpochSecond());
    }

    // ------------------------------------------------------------------ silme / gizleme

    /** Yalnizca gonderilmemis kendi yuklemesini siler; mesaja bagli ek icin 409. */
    @Transactional
    public void deleteUnsent(Long userId, Long conversationId, Long attachmentId) {
        MessageAttachment a = repo.findById(attachmentId)
                .filter(x -> x.getConversationId().equals(conversationId) && x.getUploaderId().equals(userId))
                .orElseThrow(MessageAttachmentService::notFound);
        if (a.getMessageId() != null) {
            throw new ApiException(HttpStatus.CONFLICT, "ATTACHMENT_IN_USE", "Mesaja eklenmiş görsel silinemez.");
        }
        remove(a);
    }

    /**
     * Mesaj silindiginde (T13 silme/duzenleme) cagirilir: mesajin tum eklerini ve baytlarini kaldirir.
     * Idempotenttir; exception sizdirmaz.
     */
    @Transactional
    public void purgeForMessage(Long messageId) {
        try {
            repo.findByMessageId(messageId).forEach(this::remove);
        } catch (RuntimeException e) {
            log.warn("Mesaj ekleri silinemedi (mesaj {}): {}", messageId, e.toString());
        }
    }

    /** Hesap silme (KVKK): kullanicinin yukledigi tum ekler ve baytlari kaldirilir. */
    @Transactional
    public int purgeForUser(Long userId) {
        List<MessageAttachment> rows = repo.findByUploaderId(userId);
        rows.forEach(this::remove);
        return rows.size();
    }

    /** Moderasyon gizlemesi: erisim kapanir, bayt yeni anahtara tasinir (eski imzali adresler olur). Idempotent. */
    @Transactional
    public void hide(Long attachmentId) {
        repo.findById(attachmentId).ifPresent(a -> {
            if (a.isHidden()) {
                return;
            }
            String oldKey = a.getStorageKey();
            String[] nk = a.isVideo() ? store.copyVideo(BUCKET, oldKey, a.getThumbKey(), a.getConversationId())
                    : store.copy(BUCKET, oldKey, a.getThumbKey());
            a.setHiddenAt(Instant.now());
            a.setHiddenBy("MODERATION");
            if (nk != null) {
                a.setStorageKey(nk[0]);
                a.setThumbKey(nk[1]);
                // DB commit olmadan eski dosya silinmez; commit olmazsa yeni kopya yetim kalir (temizleyici siler)
                afterCommit(() -> store.delete(BUCKET, oldKey));
            }
            repo.save(a);
        });
    }

    /** Gizlemeyi geri al (itiraz kabulu / rapor reddi). Idempotent. */
    @Transactional
    public void unhide(Long attachmentId) {
        repo.findById(attachmentId).ifPresent(a -> {
            if (a.isHidden()) {
                a.setHiddenAt(null);
                a.setHiddenBy(null);
                repo.save(a);
            }
        });
    }

    private void remove(MessageAttachment a) {
        String key = a.getStorageKey();
        repo.delete(a);
        afterCommit(() -> store.delete(BUCKET, key));
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

    // ------------------------------------------------------------------ temizlik

    /** Baglanmamis ve `maxAge`den eski yuklemeleri siler; ardindan satiri olmayan eski dosyalari tarar. */
    public int cleanup(Duration maxAge) {
        int n = 0;
        try {
            List<MessageAttachment> stale = repo.stale(Instant.now().minus(maxAge), PageRequest.of(0, 500));
            for (MessageAttachment a : stale) {
                try {
                    if (repo.deleteIfUnclaimed(a.getId()) == 1) {
                        store.delete(BUCKET, a.getStorageKey());
                        n++;
                    }
                } catch (RuntimeException e) {
                    log.warn("Yetim ek silinemedi {}: {}", a.getId(), e.toString());
                }
            }
            store.sweep(BUCKET, repo::existsByStorageKey, maxAge);
        } catch (RuntimeException e) {
            log.warn("Sohbet gorseli temizligi yarim kaldi: {}", e.toString());
        }
        return n;
    }

    private static ApiException invalid() {
        return new ApiException(HttpStatus.BAD_REQUEST, "ATTACHMENT_INVALID", "Geçersiz veya kullanılmış görsel eki.");
    }

    private static ApiException expired() {
        return new ApiException(HttpStatus.GONE, "MEDIA_VIEW_ONCE_EXPIRED", "Bu görsel yalnızca bir kez görüntülenebilir.");
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "ATTACHMENT_NOT_FOUND", "Görsel bulunamadı.");
    }

    private static ApiException convNotFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "CONVERSATION_NOT_FOUND", "Konuşma bulunamadı.");
    }
}
