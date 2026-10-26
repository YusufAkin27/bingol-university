package edu.bingol.backend.messaging;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.messaging.dto.MessagingDtos.MessageEvent;
import edu.bingol.backend.messaging.dto.MessagingDtos.MessageView;
import edu.bingol.backend.messaging.dto.MessagingDtos.ReactionCount;
import edu.bingol.backend.messaging.dto.MessagingDtos.ReactionSummary;
import edu.bingol.backend.messaging.room.RoomModeration;
import edu.bingol.backend.messaging.ws.ChatEventBus;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

/**
 * Mesaj uzerindeki eylemler: duzenleme, herkes icin silme, tepki. Yetki sirasi: mesaj yok / uye degil -> 404
 * (varlik sizdirilmaz); uye ama yetkisiz -> 403. Olaylar commit SONRASI, mesajlarla ayni sifreli yoldan
 * ({@link ChatEventBus} + BusCipher) `/user/queue/message-events` kuyruguna gider; teslim hatasi eylemi bozmaz.
 */
@Service
public class MessageActionService {

    /** Varsayilan izinli tepkiler (kod noktasi kacislari: kaynak dosya kodlamasindan bagimsiz). */
    static final String DEFAULT_REACTIONS = "👍,❤️,😂,😮,😢,🙏";

    private static final Logger log = LoggerFactory.getLogger(MessageActionService.class);

    private final MessageRepository messages;
    private final MessageReactionRepository reactions;
    private final ConversationRepository convs;
    private final ConversationMemberRepository members;
    private final UserRepository users;
    private final BlockService blocks;
    private final ChatEventBus bus;
    private final MessageCodec codec;
    private final MessageViewAssembler assembler;
    private final JdbcTemplate jdbc;
    private final Duration editWindow;
    private final Duration deleteWindow;
    private final Set<String> allowedReactions;

    public MessageActionService(MessageRepository messages, MessageReactionRepository reactions,
                                ConversationRepository convs, ConversationMemberRepository members, UserRepository users,
                                BlockService blocks, ChatEventBus bus, MessageCodec codec,
                                MessageViewAssembler assembler, JdbcTemplate jdbc,
                                @Value("${app.chat.edit-window-minutes:15}") long editWindowMinutes,
                                @Value("${app.chat.delete-window-minutes:0}") long deleteWindowMinutes,
                                @Value("${app.chat.reactions:}") String reactionList) {
        this.messages = messages;
        this.reactions = reactions;
        this.convs = convs;
        this.members = members;
        this.users = users;
        this.blocks = blocks;
        this.bus = bus;
        this.codec = codec;
        this.assembler = assembler;
        this.jdbc = jdbc;
        this.editWindow = Duration.ofMinutes(Math.max(0, editWindowMinutes));
        this.deleteWindow = Duration.ofMinutes(Math.max(0, deleteWindowMinutes));
        Set<String> set = new LinkedHashSet<>();
        for (String e : (reactionList == null || reactionList.isBlank() ? DEFAULT_REACTIONS : reactionList).split(",")) {
            if (!e.isBlank()) {
                set.add(normalize(e));
            }
        }
        this.allowedReactions = set;
    }

    /** Kulup/etkinlik odasi moderasyonu (setter enjeksiyonu; yoksa yalnizca grup yoneticisi yetkilidir). */
    private RoomModeration roomModeration;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setRoomModeration(RoomModeration roomModeration) {
        this.roomModeration = roomModeration;
    }

    private boolean isRoomModerator(Long conversationId, Long userId) {
        return roomModeration != null && roomModeration.canModerate(conversationId, userId);
    }

    /** T8: gorsel ekleri (setter enjeksiyonu; yoksa eksiz). */
    private edu.bingol.backend.messaging.media.MessageAttachmentService attachments;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setAttachments(edu.bingol.backend.messaging.media.MessageAttachmentService attachments) {
        this.attachments = attachments;
    }

    public Set<String> allowedReactions() {
        return allowedReactions;
    }

    // --- duzenleme ---

    /** Yalnizca gonderen, `app.chat.edit-window-minutes` icinde. Yeni sifreli govde yazilir; eskisi ezilir, gecmis tutulmaz. */
    public MessageView edit(Long userId, Long messageId, String text) {
        Access a = access(userId, messageId);
        // Gorselli mesajda metin bosaltilabilir (yalniz gorsel kalir); gorselsiz mesajda bos metin reddedilir
        String body = MessageService.validatedBody(text, attachments != null && attachments.hasAttachments(messageId));
        Message m = a.message;
        if (!m.getSenderId().equals(userId)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "MESSAGE_NOT_OWNER", "Yalnızca kendi mesajınızı düzenleyebilirsiniz.");
        }
        if (m.isDeleted() || m.isHidden()) {
            throw new ApiException(HttpStatus.CONFLICT, "MESSAGE_NOT_EDITABLE", "Bu mesaj düzenlenemez.");
        }
        Instant now = Instant.now();
        if (now.isAfter(m.getCreatedAt().plus(editWindow))) {
            throw new ApiException(HttpStatus.FORBIDDEN, "MESSAGE_EDIT_EXPIRED",
                    "Mesaj yalnızca gönderildikten sonraki " + editWindow.toMinutes() + " dakika içinde düzenlenebilir.",
                    String.valueOf(editWindow.toMinutes()));
        }
        requireDirectNotBlocked(a.conversation, userId);

        codec.open(m);
        if (body.equals(m.getBody()) && m.getBodyCiphertext() != null) {
            return assembler.assemble(userId, List.of(m), Set.of(), a.since).get(0); // degisiklik yok: kayit yazilmaz
        }
        codec.seal(m, body); // yeni nonce + gerekirse guncel DEK surumu; AAD (gonderen+clientId) ayni kalir
        if (messages.applyEdit(m.getId(), m.getBodyCiphertext(), m.getBodyNonce(), m.getKeyVersion(), now) == 0) {
            throw new ApiException(HttpStatus.CONFLICT, "MESSAGE_NOT_EDITABLE", "Bu mesaj düzenlenemez.");
        }
        clearLegacyPlaintext(m.getId());
        m.setEditedAt(now);
        MessageView view = assembler.assemble(userId, List.of(m), Set.of(), a.since).get(0);
        publish(m.getConversationId(), userId,
                new MessageEvent("edited", m.getConversationId(), m.getId(), userId, view.withExtras(null, List.of(), null),
                        null, null, now.toString()));
        return view;
    }

    // --- silme ---

    /**
     * Herkes icin silme: gonderen (`app.chat.delete-window-minutes` doluysa o sure icinde) ya da grup yoneticisi (suresiz).
     * Sifreli govde, nonce, anahtar surumu ve yanit bagi NULL'lanir; tepkiler silinir. Raporlanmis mesajda da
     * yonetici-cozulebilir KOPYA TUTULMAZ: rapor kaydi (kim/neden/ne zaman) kalir, icerik geri getirilemez.
     * Tekrar silme sessizce basarilidir (idempotent).
     */
    public void delete(Long userId, Long messageId) {
        Access a = access(userId, messageId);
        Message m = a.message;
        if (m.isDeleted()) {
            return;
        }
        boolean owner = m.getSenderId().equals(userId);
        // Grup yoneticisi ya da kulup/etkinlik odasinin moderatoru/organizatoru: baskasinin mesajini suresiz silebilir
        boolean groupAdmin = a.conversation.getType() == Conversation.Type.GROUP
                && (a.member.isAdmin() || (!owner && isRoomModerator(m.getConversationId(), userId)));
        if (!owner && !groupAdmin) {
            throw new ApiException(HttpStatus.FORBIDDEN, "MESSAGE_DELETE_FORBIDDEN", "Bu mesajı silme yetkiniz yok.");
        }
        Instant now = Instant.now();
        if (owner && !groupAdmin && !deleteWindow.isZero() && now.isAfter(m.getCreatedAt().plus(deleteWindow))) {
            throw new ApiException(HttpStatus.FORBIDDEN, "MESSAGE_DELETE_EXPIRED",
                    "Mesaj yalnızca gönderildikten sonraki " + deleteWindow.toMinutes() + " dakika içinde silinebilir.",
                    String.valueOf(deleteWindow.toMinutes()));
        }
        if (messages.tombstone(m.getId(), now, userId) == 0) {
            return; // es zamanli baska silme kazandi
        }
        clearLegacyPlaintext(m.getId());
        reactions.removeAll(m.getId());
        if (attachments != null) {
            attachments.purgeForMessage(m.getId()); // gorsel baytlari da silinir (erisim zaten kapanir)
        }
        publish(m.getConversationId(), userId, new MessageEvent("deleted", m.getConversationId(), m.getId(), userId,
                null, null, null, now.toString()));
    }

    // --- tepkiler ---

    public ReactionSummary react(Long userId, Long messageId, String emoji) {
        String e = emoji == null ? "" : normalize(emoji);
        if (e.isEmpty() || !allowedReactions.contains(e)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "REACTION_NOT_ALLOWED", "Bu tepki kullanılamaz.");
        }
        Access a = reactable(userId, messageId);
        reactions.upsert(messageId, userId, e, Instant.now());
        return afterReaction(a, userId, e);
    }

    public ReactionSummary unreact(Long userId, Long messageId) {
        Access a = reactable(userId, messageId);
        if (reactions.remove(messageId, userId) == 0) {
            return summary(messageId, userId); // zaten yoktu: olay yayilmaz
        }
        return afterReaction(a, userId, null);
    }

    private Access reactable(Long userId, Long messageId) {
        Access a = access(userId, messageId);
        if (a.message.isDeleted() || a.message.isHidden()) {
            throw new ApiException(HttpStatus.NOT_FOUND, "MESSAGE_NOT_FOUND", "Mesaj bulunamadı.");
        }
        requireDirectNotBlocked(a.conversation, userId);
        return a;
    }

    private ReactionSummary afterReaction(Access a, Long userId, String emoji) {
        ReactionSummary s = summary(a.message.getId(), userId);
        publish(a.message.getConversationId(), userId, new MessageEvent("reaction", a.message.getConversationId(),
                a.message.getId(), userId, null, emoji, s.reactions(), Instant.now().toString()));
        return s;
    }

    private ReactionSummary summary(Long messageId, Long userId) {
        List<ReactionCount> counts = new ArrayList<>();
        for (Object[] row : reactions.counts(List.of(messageId))) {
            counts.add(new ReactionCount((String) row[1], ((Number) row[2]).longValue()));
        }
        String mine = reactions.mine(userId, List.of(messageId)).stream().map(MessageReaction::getEmoji).findFirst().orElse(null);
        return new ReactionSummary(messageId, counts, mine);
    }

    // --- ortak ---

    private record Access(Message message, Conversation conversation, ConversationMember member, Instant since) {}

    /** Mesaj + uyelik + hesap durumu. Uye olmayan / katilma oncesi mesaj icin 404. */
    private Access access(Long userId, Long messageId) {
        Message m = messages.findById(messageId).orElseThrow(MessageActionService::messageNotFound);
        ConversationMember me = members.findByConversationIdAndUserIdAndLeftAtIsNull(m.getConversationId(), userId)
                .orElseThrow(MessageActionService::messageNotFound);
        Conversation conv = convs.findById(m.getConversationId()).orElseThrow(MessageActionService::messageNotFound);
        Instant since = conv.getType() == Conversation.Type.GROUP ? me.getJoinedAt() : null;
        if (since != null && m.getCreatedAt().isBefore(since)) {
            throw messageNotFound();
        }
        if (users.findById(userId).filter(User::isActive).isEmpty()) {
            throw new ApiException(HttpStatus.FORBIDDEN, "ACCOUNT_SUSPENDED", "Hesabınız askıya alındı.");
        }
        return new Access(m, conv, me, since);
    }

    private void requireDirectNotBlocked(Conversation conv, Long userId) {
        if (conv.getType() != Conversation.Type.DIRECT) {
            return;
        }
        boolean blocked = members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(conv.getId()).stream()
                .map(ConversationMember::getUserId).filter(id -> !id.equals(userId))
                .anyMatch(peer -> blocks.isBlocked(userId, peer));
        if (blocked) {
            throw new ApiException(HttpStatus.FORBIDDEN, "BLOCKED", "Bu kullanıcıyla mesajlaşamazsınız.");
        }
    }

    /** Gecis donemindeki eski duz metin sutunu varsa temizler (tombstone/duzenleme sonrasi duz metin kalmasin). */
    private void clearLegacyPlaintext(Long messageId) {
        if (codec.legacyColumnPresent()) {
            jdbc.update("UPDATE message SET body = NULL WHERE id = ? AND body IS NOT NULL", messageId);
        }
    }

    /** Aktif uyelere (eylemi yapanin diger cihazlari dahil); engel iliskisi olanlara gitmez. */
    private void publish(Long conversationId, Long actorId, MessageEvent event) {
        try {
            Set<Long> related = blocks.hiddenFrom(actorId);
            List<Long> recipients = members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(conversationId).stream()
                    .map(ConversationMember::getUserId).filter(id -> id.equals(actorId) || !related.contains(id)).toList();
            bus.publish("message-events", recipients, event);
        } catch (RuntimeException e) {
            log.warn("Mesaj olayi yayinlanamadi (mesaj {}): {}", event.messageId(), e.toString());
        }
    }

    /** Emoji karsilastirmasi: bosluk ve gorunum secici (U+FE0F) farki yok sayilir. */
    static String normalize(String emoji) {
        return emoji.trim().replace("️", "");
    }

    private static ApiException messageNotFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "MESSAGE_NOT_FOUND", "Mesaj bulunamadı.");
    }
}
