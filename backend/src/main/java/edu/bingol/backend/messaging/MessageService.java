package edu.bingol.backend.messaging;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.messaging.dto.MessagingDtos.MessageView;
import edu.bingol.backend.messaging.dto.MessagingDtos.ReadReceipt;
import edu.bingol.backend.messaging.dto.MessagingDtos.ReportMessageRequest;
import edu.bingol.backend.messaging.dto.MessagingDtos.TypingEvent;
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
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
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
    private static final int PUSH_PREVIEW = 100;

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

    public MessageService(ConversationRepository convs, ConversationMemberRepository members, MessageRepository messages,
                          UserRepository users, BlockService blocks, RateLimiter limiter, ChatEventBus bus,
                          PresenceService presence, NotificationService notifications, ReportService reports,
                          PlatformTransactionManager txManager) {
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

    public SendResult send(Long senderId, Long conversationId, String text, String clientId) {
        if (conversationId == null || clientId == null || clientId.isBlank() || clientId.length() > 64) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "conversationId ve clientId gerekli.");
        }
        String body = MessageText.clean(text);
        if (body.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "EMPTY_MESSAGE", "Mesaj boş olamaz.");
        }
        // Sinir kod noktasi sayar (DB VARCHAR(2000) de oyle): emoji 2 UTF-16 birimi olsa da 1 karakterdir.
        if (body.codePointCount(0, body.length()) > MAX_LENGTH) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "MESSAGE_TOO_LONG",
                    "Mesaj en fazla " + MAX_LENGTH + " karakter olabilir.", String.valueOf(MAX_LENGTH));
        }
        requireMember(conversationId, senderId);
        // Hesabi silinen/askiya alinan gonderenin (suresi dolmamis) eski token'i ile yazmasi engellenir.
        if (users.findById(senderId).filter(User::isActive).isEmpty()) {
            throw new ApiException(HttpStatus.FORBIDDEN, "ACCOUNT_SUSPENDED", "Hesabınız askıya alındı.");
        }

        // Tekrar gonderim: limite sayilmaz, ayni mesaj doner.
        Optional<Message> dup = messages.findByConversationIdAndSenderIdAndClientId(conversationId, senderId, clientId);
        if (dup.isPresent()) {
            return new SendResult(MessageView.of(dup.get()), false);
        }

        Conversation conv = convs.findById(conversationId).orElseThrow(MessageService::notFound);
        List<ConversationMember> active = members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(conversationId);
        if (conv.getType() == Conversation.Type.DIRECT) {
            Long peerId = active.stream().map(ConversationMember::getUserId).filter(id -> !id.equals(senderId))
                    .findFirst().orElseThrow(MessageService::notFound);
            if (blocks.isBlocked(senderId, peerId)) {
                throw new ApiException(HttpStatus.FORBIDDEN, "BLOCKED", "Bu kullanıcıyla mesajlaşamazsınız.");
            }
            if (users.findById(peerId).filter(User::isActive).isEmpty()) {
                throw new ApiException(HttpStatus.FORBIDDEN, "USER_UNAVAILABLE", "Bu kullanıcıya mesaj gönderilemez.");
            }
        }
        limiter.check("msg:user:" + senderId, RATE_PER_MINUTE, Duration.ofMinutes(1));

        Message saved;
        try {
            saved = tx.execute(s -> persist(conversationId, senderId, clientId, body));
        } catch (DataIntegrityViolationException e) {
            // Ayni clientId ile eszamanli iki istek: kazanan kaydetti, digeri onu doner.
            Message existing = messages.findByConversationIdAndSenderIdAndClientId(conversationId, senderId, clientId)
                    .orElseThrow(() -> e);
            return new SendResult(MessageView.of(existing), false);
        }
        MessageView view = MessageView.of(saved);
        try {
            deliver(conv, saved, view, active);
        } catch (RuntimeException e) {
            // Mesaj kayitli; teslim hatasi gondericiye hata olarak donmez (istemci yeniden baglaninca ceker).
            log.warn("Mesaj teslimi basarisiz (mesaj {}): {}", saved.getId(), e.toString());
        }
        return new SendResult(view, true);
    }

    private Message persist(Long conversationId, Long senderId, String clientId, String body) {
        Message m = new Message();
        m.setConversationId(conversationId);
        m.setSenderId(senderId);
        m.setClientId(clientId);
        m.setBody(body);
        m = messages.saveAndFlush(m);
        convs.touchLastMessage(conversationId, m.getId(), m.getCreatedAt());
        members.advanceRead(conversationId, senderId, m.getId()); // kendi mesaji okunmus sayilir
        return m;
    }

    /** Tum uyelere (gonderenin diger cihazlari dahil) WebSocket; cevrimdisi alicilara bildirim. Engel iliskisi olanlara gitmez. */
    private void deliver(Conversation conv, Message m, MessageView view, List<ConversationMember> active) {
        Long senderId = m.getSenderId();
        Set<Long> related = blocks.hiddenFrom(senderId);
        List<Long> recipients = active.stream().map(ConversationMember::getUserId)
                .filter(id -> id.equals(senderId) || !related.contains(id)).toList();
        bus.publish("messages", recipients, view);

        List<Long> offline = recipients.stream().filter(id -> !id.equals(senderId) && !presence.isOnline(id)).toList();
        if (offline.isEmpty()) {
            return;
        }
        String senderName = users.findById(senderId).map(User::getDisplayName).orElse("Yeni mesaj");
        String title = conv.getType() == Conversation.Type.GROUP && conv.getTitle() != null
                ? conv.getTitle() + " - " + senderName : senderName;
        String preview = m.getBody().length() > PUSH_PREVIEW ? m.getBody().substring(0, PUSH_PREVIEW) + "…" : m.getBody();
        Map<String, String> data = Map.of("conversationId", String.valueOf(conv.getId()),
                "messageId", String.valueOf(m.getId()));
        offline.forEach(id -> notifications.send(id, NotificationType.MESSAGE, title, preview, data));
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
        List<Message> rows = after != null
                ? messages.after(conversationId, since, after, PageRequest.of(0, s + 1))
                : messages.before(conversationId, since, before, PageRequest.of(0, s + 1));
        return CursorPage.of(rows, s, Message::getId,
                m -> MessageView.of(m, related.contains(m.getSenderId()) && !m.getSenderId().equals(userId)));
    }

    /** Okundu imleci: yalnizca ileri gider, konusmadaki son mesaji gecemez. Imlec ilerlediyse diger uyelere bildirilir. */
    public void markRead(Long userId, Long conversationId, Long lastMessageId) {
        requireMember(conversationId, userId);
        Conversation conv = convs.findById(conversationId).orElseThrow(MessageService::notFound);
        if (lastMessageId == null || lastMessageId <= 0
                || conv.getLastMessageId() == null || lastMessageId > conv.getLastMessageId()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_MESSAGE_ID", "Geçersiz mesaj kimliği.");
        }
        if (members.advanceRead(conversationId, userId, lastMessageId) > 0) {
            bus.publish("read-receipts", othersOf(conversationId, userId, true),
                    new ReadReceipt(conversationId, userId, lastMessageId));
        }
    }

    /** "Yaziyor" bilgisi kalici degildir; asiri sik istekler (2 sn'de 1) sessizce atilir. */
    public void typing(Long userId, Long conversationId) {
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
