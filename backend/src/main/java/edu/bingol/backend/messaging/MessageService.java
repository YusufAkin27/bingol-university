package edu.bingol.backend.messaging;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.messaging.dto.MessagingDtos;
import edu.bingol.backend.messaging.dto.MessagingDtos.MessageView;
import edu.bingol.backend.messaging.dto.MessagingDtos.ReadReceipt;
import edu.bingol.backend.messaging.dto.MessagingDtos.ReportMessageRequest;
import edu.bingol.backend.messaging.dto.MessagingDtos.TypingEvent;
import edu.bingol.backend.messaging.media.MessageAttachmentService;
import edu.bingol.backend.messaging.ws.ChatEventBus;
import edu.bingol.backend.messaging.ws.PresenceService;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.moderation.ReportService;
import edu.bingol.backend.moderation.ReportTargetType;
import edu.bingol.backend.moderation.dto.ModerationDtos.CreateReportRequest;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.concurrent.Executor;
import java.util.concurrent.RejectedExecutionException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Mesaj gonderme/okuma tek yolu: REST ve WebSocket ayni metotlari cagirir (yetki, temizleme, limit, idempotency burada).
 * Sira: dogrula -> DB'ye yaz (kendi transaction'i) -> commit SONRASI Redis'e yayinla / gerekirse bildirim gonder.
 */
@Service
public class MessageService {

    public static final int MAX_LENGTH = 2000;
    public static final int RATE_PER_MINUTE = 30;
    /** DB sorgularindan ONCE uygulanan kaba kullanici siniri (tekrarli clientId dahil tum gonderim denemeleri). */
    static final int COARSE_SEND_PER_MINUTE = 120;
    static final int COARSE_READ_PER_MINUTE = 180;
    private static final int PUSH_PREVIEW = 100;
    static final int READ_PER_WINDOW = 20;
    static final Duration READ_WINDOW = Duration.ofSeconds(10);
    /** Bu sayidan fazla cevrimdisi alici varsa bildirimler tek toplu cagriyla gider. */
    static final int BULK_NOTIFY_THRESHOLD = 20;

    /** Gonderim sonucu: `created` false ise ayni clientId ile daha once kaydedilmis mesaj doner. */
    public record SendResult(MessageView message, boolean created) {}

    private static final Logger log = LoggerFactory.getLogger(MessageService.class);

    private final ConversationRepository convs;
    private final ConversationMemberRepository members;
    private final MessageRepository messages;
    private final UserRepository users;
    private final BlockService blocks;
    private final RateLimiter limiter;
    private final ChatEventBus bus;
    private final PresenceService presence;
    private final NotificationService notifications;
    private final ReportService reports;
    private final TransactionTemplate tx;
    private final MessageCodec codec;
    private final MessageViewAssembler assembler;
    /** `app.push.message-preview`: true ise push govdesinde mesaj onizlemesi gider (bildirim tablosuna YAZILMAZ). */
    private final boolean pushPreview;
    /** T8: sohbet gorselleri (setter enjeksiyonu: yapici imzasi degismesin). Yoksa gorselsiz calisir. */
    private MessageAttachmentService attachments;

    public MessageService(ConversationRepository convs, ConversationMemberRepository members, MessageRepository messages,
                          UserRepository users, BlockService blocks, RateLimiter limiter, ChatEventBus bus,
                          PresenceService presence, NotificationService notifications, ReportService reports,
                          PlatformTransactionManager txManager, MessageCodec codec,
                          MessageViewAssembler assembler,
                          @Value("${app.push.message-preview:false}") boolean pushPreview) {
        this.codec = codec;
        this.assembler = assembler;
        this.pushPreview = pushPreview;
        this.convs = convs;
        this.members = members;
        this.messages = messages;
        this.users = users;
        this.blocks = blocks;
        this.limiter = limiter;
        this.bus = bus;
        this.presence = presence;
        this.notifications = notifications;
        this.reports = reports;
        this.tx = new TransactionTemplate(txManager);
    }

    /** Bildirim dagitimi icin (buyuk odalarda gondericiyi bekletmesin); varsayilan: cagiran is parcacigi. */
    private Executor fanout = Runnable::run;

    @Autowired(required = false)
    void setFanout(@Qualifier("chatFanoutExecutor") Executor fanout) {
        this.fanout = fanout;
    }

    /** Iletildi/okundu makbuzlari (setter enjeksiyonu: yapici imzasi degismesin). Yoksa yalniz eski okundu olayi gider. */
    private ReceiptService receipts;

    @Autowired(required = false)
    void setReceipts(ReceiptService receipts) {
        this.receipts = receipts;
    }

    /** Push yukundeki gonderen avatari icin profil gizlilik karari (yoksa avatar gonderilmez). */
    private edu.bingol.backend.profile.privacy.AvatarVisibility avatarVisibility;

    @Autowired(required = false)
    void setAvatarVisibility(edu.bingol.backend.profile.privacy.AvatarVisibility avatarVisibility) {
        this.avatarVisibility = avatarVisibility;
    }

    @Autowired(required = false)
    void setAttachments(MessageAttachmentService attachments) {
        this.attachments = attachments;
    }

    public SendResult send(Long senderId, Long conversationId, String text, String clientId) {
        return send(senderId, conversationId, text, clientId, null);
    }

    /** Temizler ve dogrular (gonderme ve duzenleme ortak): bos / cok uzun ise ApiException. */
    static String validatedBody(String text) {
        return validatedBody(text, false);
    }

    /** T8: `allowEmpty` (gorsel eki olan mesaj) ise bos metin kabul edilir; uzunluk siniri her durumda gecerli. */
    static String validatedBody(String text, boolean allowEmpty) {
        String body = MessageText.clean(text);
        if (body.isEmpty() && !allowEmpty) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "EMPTY_MESSAGE", "Mesaj boş olamaz.");
        }
        // Sinir kod noktasi sayar (DB VARCHAR(2000) de oyle): emoji 2 UTF-16 birimi olsa da 1 karakterdir.
        if (body.codePointCount(0, body.length()) > MAX_LENGTH) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "MESSAGE_TOO_LONG",
                    "Mesaj en fazla " + MAX_LENGTH + " karakter olabilir.", String.valueOf(MAX_LENGTH));
        }
        return body;
    }

    public SendResult send(Long senderId, Long conversationId, String text, String clientId, Long replyToMessageId) {
        return send(senderId, conversationId, text, clientId, replyToMessageId, null);
    }

    /**
     * `replyToMessageId`: ayni konusmadaki (silinmemis, gorunur) bir mesaj; aksi halde 404 MESSAGE_NOT_FOUND.
     * `attachmentIds` (T8): onceden yuklenmis sohbet gorselleri; doluysa metin bos olabilir.
     */
    public SendResult send(Long senderId, Long conversationId, String text, String clientId, Long replyToMessageId,
                           List<Long> attachmentIds) {
        return send(senderId, conversationId, text, clientId, replyToMessageId, attachmentIds, null);
    }

    /** `viewOnce` true: yalniz ek doluyken ve en fazla 1 ek ile; aksi 400 VIEW_ONCE_INVALID. */
    public SendResult send(Long senderId, Long conversationId, String text, String clientId, Long replyToMessageId,
                           List<Long> attachmentIds, Boolean viewOnceFlag) {
        if (conversationId == null || clientId == null || clientId.isBlank() || clientId.length() > 64) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "conversationId ve clientId gerekli.");
        }
        boolean hasMedia = attachmentIds != null && !attachmentIds.isEmpty();
        boolean viewOnce = Boolean.TRUE.equals(viewOnceFlag);
        if (viewOnce && (!hasMedia || attachmentIds.size() != 1)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VIEW_ONCE_INVALID",
                    "Tek gösterimlik mesajda tam olarak bir görsel olmalıdır.");
        }
        if (hasMedia && attachments == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "ATTACHMENT_INVALID", "Geçersiz veya kullanılmış görsel eki.");
        }
        String body = validatedBody(text, hasMedia);
        // Ucuz (yalniz Redis) kullanici basi kaba sinir: DB sorgularindan ONCE ve tekrarli clientId yolunu da kapsar
        limiter.check("msg:all:" + senderId, COARSE_SEND_PER_MINUTE, Duration.ofMinutes(1));
        ConversationMember sender = requireMember(conversationId, senderId);
        // Hesabi silinen/askiya alinan gonderenin (suresi dolmamis) eski token'i ile yazmasi engellenir.
        if (users.findById(senderId).filter(User::isActive).isEmpty()) {
            throw new ApiException(HttpStatus.FORBIDDEN, "ACCOUNT_SUSPENDED", "Hesabınız askıya alındı.");
        }

        // Tekrar gonderim: limite sayilmaz, ayni mesaj doner.
        Optional<Message> dup = messages.findByConversationIdAndSenderIdAndClientId(conversationId, senderId, clientId);
        if (dup.isPresent()) {
            return new SendResult(viewFor(senderId, codec.open(dup.get()), null), false);
        }

        Conversation conv = convs.findById(conversationId).orElseThrow(MessageService::notFound);
        // P08: yonetici kapattiysa yeni mesaj yok (yineleme yolu yukarida: eski clientId yine ayni mesaji doner)
        if (conv.isClosed()) {
            throw new ApiException(HttpStatus.CONFLICT, "CONVERSATION_CLOSED", "Bu sohbet yönetici tarafından kapatıldı.");
        }
        Instant since = conv.getType() == Conversation.Type.GROUP ? sender.getJoinedAt() : null;
        if (replyToMessageId != null) {
            // Baska konusmanin / katilma oncesi / silinmis / gizlenmis mesaja yanit verilemez (varligi da sizdirilmaz)
            Message parent = messages.findById(replyToMessageId).orElseThrow(MessageService::messageNotFound);
            if (!parent.getConversationId().equals(conversationId) || parent.isDeleted() || parent.isHidden()
                    || (parent.isSuppressed() && !parent.getSenderId().equals(senderId))
                    || parent.getId() <= sender.getClearedUpToMessageId()
                    || (since != null && parent.getCreatedAt().isBefore(since))) {
                throw messageNotFound();
            }
        }
        List<ConversationMember> active = members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(conversationId);
        boolean suppressed = false;
        if (conv.getType() == Conversation.Type.DIRECT) {
            Long peerId = active.stream().map(ConversationMember::getUserId).filter(id -> !id.equals(senderId))
                    .findFirst().orElseThrow(MessageService::notFound);
            // Golge engel: hata YOK; mesaj kaydedilir ama karsi tarafa hicbir yerde ulasmaz (kalici bayrak)
            suppressed = blocks.isBlocked(senderId, peerId);
            if (users.findById(peerId).filter(User::isActive).isEmpty()) {
                throw new ApiException(HttpStatus.FORBIDDEN, "USER_UNAVAILABLE", "Bu kullanıcıya mesaj gönderilemez.");
            }
        }
        // Ek dogrulamasi mesaj hakkini harcamadan once (baskasinin/kullanilmis/uygunsuz ek -> 400)
        List<Long> ids = hasMedia ? (viewOnce ? attachments.precheck(senderId, conversationId, attachmentIds, true)
                : attachments.precheck(senderId, conversationId, attachmentIds)) : List.of();
        limiter.check("msg:user:" + senderId, RATE_PER_MINUTE, Duration.ofMinutes(1));

        // Sifreleme transaction DISINDA: DB'ye yalnizca sifreli govde yazilir (docs/ENCRYPTION.md).
        Message draft = new Message();
        draft.setConversationId(conversationId);
        draft.setSenderId(senderId);
        draft.setClientId(clientId);
        draft.setReplyToMessageId(replyToMessageId);
        draft.setSuppressed(suppressed);
        codec.seal(draft, body);
        Message saved;
        try {
            saved = tx.execute(s -> persist(draft, ids, viewOnce));
        } catch (DataIntegrityViolationException e) {
            // Ayni clientId ile eszamanli iki istek: kazanan kaydetti, digeri onu doner.
            Message existing = messages.findByConversationIdAndSenderIdAndClientId(conversationId, senderId, clientId)
                    .orElseThrow(() -> e);
            return new SendResult(viewFor(senderId, codec.open(existing), since), false);
        }
        MessageView view = viewFor(senderId, saved, since);
        try {
            deliver(conv, saved, view, active);
        } catch (RuntimeException e) {
            // Mesaj kayitli; teslim hatasi gondericiye hata olarak donmez (istemci yeniden baglaninca ceker).
            log.warn("Mesaj teslimi basarisiz (mesaj {}): {}", saved.getId(), e.toString());
        }
        return new SendResult(view, true);
    }

    private Message persist(Message draft, List<Long> attachmentIds, boolean viewOnce) {
        String plain = draft.getBody();
        Message m = messages.saveAndFlush(draft);
        if (!attachmentIds.isEmpty()) {
            // Ayni transaction: baska mesaja/kullaniciya ait ya da kullanilmis ek varsa istisna -> mesaj da geri alinir
            if (viewOnce) {
                attachments.claim(m.getId(), m.getSenderId(), m.getConversationId(), attachmentIds, true);
            } else {
                attachments.claim(m.getId(), m.getSenderId(), m.getConversationId(), attachmentIds);
            }
        }
        m.setBody(plain); // @Transient: kayit sonrasi geri verilen nesnede duz metni koru (teslim/yanit icin)
        convs.touchLastMessage(m.getConversationId(), m.getId(), m.getCreatedAt());
        if (m.isSuppressed()) {
            convs.markShadowed(m.getConversationId());
            members.advanceOwnSuppressed(m.getConversationId(), m.getSenderId(), m.getId());
            members.unhideMember(m.getConversationId(), m.getSenderId()); // karsi tarafin listesi etkilenmez
            members.advanceRead(m.getConversationId(), m.getSenderId(), m.getId());
            m.setBody(plain);
            return m;
        }
        convs.touchLastVisible(m.getConversationId(), m.getId());
        members.advanceRead(m.getConversationId(), m.getSenderId(), m.getId()); // kendi mesaji okunmus sayilir
        members.unarchiveOnMessage(m.getConversationId()); // yapiskan olmayan arsivler yeni mesajla cikar
        members.unhideOnMessage(m.getConversationId()); // "sohbeti sil" yapanlarda konusma yeniden belirir
        return m;
    }

    private MessageView viewFor(Long viewerId, Message m, Instant since) {
        return assembler.assemble(viewerId, List.of(m), Set.of(), since).get(0);
    }

    /** Tum uyelere (gonderenin diger cihazlari dahil) WebSocket; cevrimdisi alicilara bildirim. Engel iliskisi olanlara gitmez. */
    private void deliver(Conversation conv, Message m, MessageView view, List<ConversationMember> active) {
        Long senderId = m.getSenderId();
        if (m.isSuppressed()) {
            // Golge engel: yalniz gondericinin cihazlarina; karsi tarafa WS / push / bildirim yok
            bus.publish("messages", List.of(senderId), view);
            return;
        }
        Set<Long> related = blocks.hiddenFrom(senderId);
        List<Long> recipients = active.stream().map(ConversationMember::getUserId)
                .filter(id -> id.equals(senderId) || !related.contains(id)).toList();
        // Grupta mesajdan sonra katilanlar yanit onizlemesinde katilma oncesi icerigi gormesin
        Instant parentAt = view.replyTo() == null || conv.getType() != Conversation.Type.GROUP ? null
                : parentTime(view.replyToMessageId());
        Set<Long> late = parentAt == null ? Set.of()
                : active.stream().filter(a -> a.getJoinedAt().isAfter(parentAt))
                        .map(ConversationMember::getUserId).collect(java.util.stream.Collectors.toSet());
        List<Long> normal = recipients.stream().filter(id -> !late.contains(id)).toList();
        // Tek gosterimlikte gonderenin gorunumunde url yoktur; alicilara acilabilir (url'li) gorunum gider
        boolean viewOnce = view.attachments().stream().anyMatch(a -> a.viewOnce());
        MessageView others = viewOnce ? view.withAttachments(view.attachments().stream()
                .map(a -> a.forRecipient(m.getConversationId())).toList()) : view;
        if (viewOnce) {
            bus.publish("messages", List.of(senderId), view);
            bus.publish("messages", normal.stream().filter(id -> !id.equals(senderId)).toList(), others);
        } else {
            bus.publish("messages", normal, view);
        }
        List<Long> lateRecipients = recipients.stream().filter(late::contains).toList();
        if (!lateRecipients.isEmpty()) {
            bus.publish("messages", lateRecipients, others.withoutReplyPreview());
        }

        // Sessize alinan konusma: push ve uygulama ici bildirim yok (okunmamis sayaci yine artar, WS yine iletilir).
        // Sessiz (muted/mutedForever) ve yapiskan arsivdeki (archiveSticky) uyelere de bildirim yok.
        Set<Long> muted = active.stream().filter(a -> a.isMuted() || (a.getArchivedAt() != null && a.isArchiveSticky()))
                .map(ConversationMember::getUserId).collect(java.util.stream.Collectors.toSet());
        List<Long> candidates = recipients.stream().filter(id -> !id.equals(senderId) && !muted.contains(id)).toList();
        if (candidates.isEmpty()) {
            return;
        }
        String title = conv.getType() == Conversation.Type.GROUP && conv.getTitle() != null ? conv.getTitle() : null;
        String preview = previewOf(m);
        Map<String, String> data = Map.of("conversationId", String.valueOf(conv.getId()),
                "messageId", String.valueOf(m.getId()), "conversationType", conv.getType().name());
        Long convId = conv.getId();
        try {
            fanout.execute(() -> notifyOffline(senderId, convId, title, preview, data, candidates));
        } catch (RejectedExecutionException e) {
            log.warn("Bildirim kuyrugu dolu, mesaj {} icin bildirim atlandi", m.getId());
        }
    }

    /** Onizleme yalniz push govdesine gider; uygulama ici bildirim tablosuna duz metin YAZILMAZ (sabit "Yeni mesaj"). */
    private String previewOf(Message m) {
        if (!pushPreview) {
            return null;
        }
        String body = m.getBody();
        return body.isEmpty() ? "📷" // yalniz gorsel
                : body.length() > PUSH_PREVIEW ? body.substring(0, PUSH_PREVIEW) + "…" : body;
    }

    /**
     * Cevrimdisi alicilara bildirim (asenkron; hata gondericiyi etkilemez). Cevrimici olanlara yalniz canli WS olayi gider.
     * Sohbeti su an goruntuleyene hicbir sey yazilmaz; uygulamasi on planda olana yalniz uygulama ici kayit (push yok);
     * askidaki/silinmis hesaba bildirim yok. Presence/viewing/foreground tek MGET'lerle okunur.
     */
    private void notifyOffline(Long senderId, Long conversationId, String groupTitle, String preview,
                               Map<String, String> data, List<Long> candidates) {
        try {
            Set<Long> online = presence.onlineAmong(candidates);
            Set<Long> viewing = presence.viewingAmong(candidates, conversationId);
            List<Long> offline = candidates.stream().filter(id -> !online.contains(id) && !viewing.contains(id)).toList();
            if (offline.isEmpty()) {
                return;
            }
            Set<Long> inactive = new java.util.HashSet<>();
            users.findAllById(offline).forEach(u -> {
                if (!u.isActive()) {
                    inactive.add(u.getId());
                }
            });
            Set<Long> foreground = presence.foregroundAmong(offline);
            User sender = users.findById(senderId).orElse(null);
            String senderName = sender == null ? "Yeni mesaj" : sender.getDisplayName();
            String title = groupTitle == null ? senderName : groupTitle + " - " + senderName;
            // Gonderen avatari (on plan push karti): yalniz gizlilik ayari alicinin gormesine izin veriyorsa
            String avatar = sender == null ? null : sender.getAvatarUrl();
            Set<Long> avatarOk = avatar == null || avatarVisibility == null ? Set.of()
                    : avatarVisibility.viewersAmong(senderId, offline,
                            edu.bingol.backend.profile.privacy.AvatarVisibility.Field.AVATAR);
            Set<Long> related = avatarOk.isEmpty() ? Set.of() : blocks.hiddenFrom(senderId);
            for (Long id : offline) {
                if (!inactive.contains(id)) {
                    Map<String, String> perUser = data;
                    if (avatarOk.contains(id) && !related.contains(id)) {
                        perUser = new java.util.HashMap<>(data);
                        perUser.put("senderAvatarUrl", avatar);
                    }
                    notifications.sendNewMessage(id, title, preview, perUser, !foreground.contains(id));
                }
            }
        } catch (RuntimeException e) {
            log.warn("Mesaj bildirimi gonderilemedi: {}", e.toString());
        }
    }

    private Instant parentTime(Long parentId) {
        return messages.findById(parentId).map(Message::getCreatedAt).orElse(Instant.EPOCH);
    }

    /**
     * Gecmis. `after` verilirse eski->yeni (kacirilanlari tamamlama), degilse `before`'a gore yeni->eski.
     * Gruplarda engel iliskisi olan gondericilerin mesajlari gizlenmis metinle doner.
     */
    public CursorPage<MessageView> history(Long userId, Long conversationId, Long before, Long after, int size) {
        if (before != null && after != null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "before ve after birlikte verilemez.");
        }
        ConversationMember me = requireMember(conversationId, userId);
        Conversation conv = convs.findById(conversationId).orElseThrow(MessageService::notFound);
        boolean group = conv.getType() == Conversation.Type.GROUP;
        // Gruba sonradan katilan, katilmadan onceki mesajlari gormez.
        Instant since = group ? me.getJoinedAt() : Instant.EPOCH;
        Set<Long> related = group ? blocks.hiddenFrom(userId) : Set.of();
        int s = CursorPage.clampSize(size);
        long cleared = me.getClearedUpToMessageId(); // "sohbeti sil": bu id ve oncesi gorunmez
        List<Message> rows = cleared > 0 || conv.isShadowed()
                ? (after != null ? messages.afterCleared(conversationId, since, cleared, userId, after, PageRequest.of(0, s + 1))
                        : messages.beforeCleared(conversationId, since, cleared, userId, before, PageRequest.of(0, s + 1)))
                : after != null
                ? messages.after(conversationId, since, after, PageRequest.of(0, s + 1))
                : messages.before(conversationId, since, before, PageRequest.of(0, s + 1));
        List<Message> page = rows.size() > s ? rows.subList(0, s) : rows;
        codec.openAll(page); // yalniz donecek sayfa cozulur
        Map<Long, MessageView> views = new java.util.HashMap<>();
        assembler.assemble(userId, page, related, group ? me.getJoinedAt() : null).forEach(v -> views.put(v.id(),
                cleared > 0 && v.replyTo() != null && v.replyToMessageId() != null && v.replyToMessageId() <= cleared
                        ? v.withExtras(new MessagingDtos.ReplyPreview(v.replyToMessageId(), null, null, false),
                                v.reactions(), v.myReaction())
                        : v));
        return CursorPage.of(rows, s, Message::getId, m -> views.get(m.getId()));
    }

    /** Okundu imleci: yalnizca ileri gider, konusmadaki son mesaji gecemez. Imlec ilerlediyse diger uyelere bildirilir. */
    public void markRead(Long userId, Long conversationId, Long lastMessageId) {
        // Ucuz kaba sinir DB'den once: asiri okundu istekleri sessizce atilir (sonraki istek imleci ilerletir)
        try {
            limiter.check("read:all:" + userId, COARSE_READ_PER_MINUTE, Duration.ofMinutes(1));
        } catch (ApiException e) {
            return;
        }
        ConversationMember me = requireMember(conversationId, userId);
        Conversation conv = convs.findById(conversationId).orElseThrow(MessageService::notFound);
        if (conv.getLastMessageId() == null) {
            return; // bos konusma: okunacak bir sey yok (no-op)
        }
        if (lastMessageId == null || lastMessageId <= 0 || lastMessageId > conv.getLastMessageId()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_MESSAGE_ID", "Geçersiz mesaj kimliği.");
        }
        // Sessiz limit (typing gibi): fazla sik okundu istekleri atilir, sonraki istek imleci yine ilerletir
        try {
            limiter.check("read:" + userId + ":" + conversationId, READ_PER_WINDOW, READ_WINDOW);
        } catch (ApiException e) {
            return;
        }
        long oldRead = me.getLastReadMessageId();
        long oldDelivered = me.getLastDeliveredMessageId();
        if (members.advanceRead(conversationId, userId, lastMessageId) > 0) {
            bus.publish("read-receipts", othersOf(conversationId, userId, true),
                    new ReadReceipt(conversationId, userId, lastMessageId));
            // Yeni akis: mesaj sahibine /user/queue/message-events {type:"receipt", kind:"read"} (okuma iletildiyi de ilerletir)
            if (receipts != null) {
                receipts.onRead(userId, conversationId, oldRead, oldDelivered, lastMessageId);
            }
        }
    }

    /** "Yaziyor" bilgisi kalici degildir; asiri sik istekler (2 sn'de 1) sessizce atilir. */
    public void typing(Long userId, Long conversationId) {
        // Ucuz kaba sinir DB'den once (rastgele konusma kimligiyle anahtar uretmeyi de onler)
        try {
            limiter.check("typing:all:" + userId, 5, Duration.ofSeconds(2));
        } catch (ApiException e) {
            return;
        }
        requireMember(conversationId, userId);
        try {
            limiter.check("typing:" + userId + ":" + conversationId, 1, Duration.ofSeconds(2));
        } catch (ApiException e) {
            return;
        }
        bus.publish("typing", othersOf(conversationId, userId, true), new TypingEvent(conversationId, userId));
    }

    /** Mesaji raporla: yalnizca mesajin bulundugu konusmanin uyesi raporlayabilir. */
    public Long report(Long reporterId, Long messageId, ReportMessageRequest r) {
        Message m = messages.findById(messageId).orElseThrow(MessageService::messageNotFound);
        if (members.findByConversationIdAndUserIdAndLeftAtIsNull(m.getConversationId(), reporterId).isEmpty()) {
            throw messageNotFound();
        }
        return reports.create(reporterId, new CreateReportRequest(ReportTargetType.MESSAGE, messageId, r.reason(), r.note()))
                .getId();
    }

    /** Konusmanin diger aktif uyeleri; `skipRelated` ise kullaniciyla engel iliskisi olanlar cikarilir. */
    private List<Long> othersOf(Long conversationId, Long userId, boolean skipRelated) {
        Set<Long> related = skipRelated ? blocks.hiddenFrom(userId) : Set.of();
        return members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(conversationId).stream()
                .map(ConversationMember::getUserId).filter(id -> !id.equals(userId) && !related.contains(id)).toList();
    }

    private ConversationMember requireMember(Long conversationId, Long userId) {
        return members.findByConversationIdAndUserIdAndLeftAtIsNull(conversationId, userId)
                .orElseThrow(MessageService::notFound);
    }

    // Katilimci olmayana konusmanin varligi da sizdirilmaz.
    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "CONVERSATION_NOT_FOUND", "Konuşma bulunamadı.");
    }

    private static ApiException messageNotFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "MESSAGE_NOT_FOUND", "Mesaj bulunamadı.");
    }
}
