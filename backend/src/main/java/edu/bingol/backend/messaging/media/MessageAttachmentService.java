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
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
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
                                    @Value("${app.chat.media.uploads-per-minute:10}") int perMinute,
                                    @Value("${app.chat.media.uploads-per-day:200}") int perDay,
                                    @Value("${app.chat.media.max-per-message:4}") int maxPerMessage,
                                    @Value("${app.chat.media.pending-max:20}") int pendingMax,
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

    // ------------------------------------------------------------------ yukleme

    public AttachmentView upload(Long userId, Long conversationId, MultipartFile file) {
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
            if (blocks.isBlocked(userId, peer)) {
                throw new ApiException(HttpStatus.FORBIDDEN, "BLOCKED", "Bu kullanıcıyla mesajlaşamazsınız.");
            }
            if (users.findById(peer).filter(User::isActive).isEmpty()) {
                throw new ApiException(HttpStatus.FORBIDDEN, "USER_UNAVAILABLE", "Bu kullanıcıya mesaj gönderilemez.");
            }
        }
    }

    // ------------------------------------------------------------------ mesaja baglama

    /** Gonderimden once hizli dogrulama (sayi, tekrar, sahiplik). Gecersiz her durumda ayni 400. */
    public List<Long> precheck(Long senderId, Long conversationId, List<Long> ids) {
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
        if (m == null || m.isHidden()) {
            return Optional.empty();
        }
        Conversation conv = convs.findById(conversationId).orElse(null);
        if (conv == null) {
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
        return privateNoStore(store.serve(BUCKET, thumb ? a.getThumbKey() : a.getStorageKey()));
    }

    /** Yonetici onizlemesi icin: yetki denetimi cagiranda (ADMIN), gizli ekler dahil. */
    public ResponseEntity<Resource> streamForAdmin(Long attachmentId, boolean thumb) {
        MessageAttachment a = repo.findById(attachmentId).orElseThrow(MessageAttachmentService::notFound);
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
        Duration ttl = Duration.ofSeconds(Math.max(30, linkTtlSeconds));
        Instant exp = Instant.now().plus(ttl.compareTo(Duration.ofHours(1)) > 0 ? Duration.ofHours(1) : ttl);
        return new AttachmentView.Link(signer.sign(BUCKET, a.getStorageKey(), ttl),
                signer.sign(BUCKET, a.getThumbKey(), ttl), exp.getEpochSecond());
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
            String[] nk = store.copy(BUCKET, oldKey, a.getThumbKey());
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

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "ATTACHMENT_NOT_FOUND", "Görsel bulunamadı.");
    }

    private static ApiException convNotFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "CONVERSATION_NOT_FOUND", "Konuşma bulunamadı.");
    }
}
