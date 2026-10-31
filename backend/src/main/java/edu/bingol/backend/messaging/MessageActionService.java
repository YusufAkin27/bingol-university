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
                                @Value("${app.chat.edit-window-minutes:0}") long editWindowMinutes,
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

    /** Yalnizca gonderen, `app.chat.edit-window-minutes` icinde. Yeni sifreli govde yazilir; eski sifreli surum `message_revision`'a arsivlenir. */
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
        // 0 = sinirsiz: sure denetimi uygulanmaz
        if (!editWindow.isZero() && now.isAfter(m.getCreatedAt().plus(editWindow))) {
            throw new ApiException(HttpStatus.FORBIDDEN, "MESSAGE_EDIT_EXPIRED",
                    "Mesaj yalnızca gönderildikten sonraki " + editWindow.toMinutes() + " dakika içinde düzenlenebilir.",
                    String.valueOf(editWindow.toMinutes()));
        }
        codec.open(m);
        if (body.equals(m.getBody()) && m.getBodyCiphertext() != null) {
            return assembler.assemble(userId, List.of(m), Set.of(), a.since).get(0); // degisiklik yok: kayit yazilmaz
        }
        // Golge engel (T-028): karsi tarafca engellenen gonderenin duzenlemesi hata vermez ama YAZILMAZ; engelleyenin
        // gecmisinde duzenlenmis metin gorunmez, engellenen taraf da engellendigini ogrenmez.
        if (blockedByPeer(a.conversation, userId)) {
            return assembler.assemble(userId, List.of(m), Set.of(), a.since).get(0);
        }
        codec.seal(m, body); // yeni nonce + gerekirse guncel DEK surumu; AAD (gonderen+clientId) ayni kalir
        messages.archiveRevision(m.getId()); // onceki sifreli surum duzenleme gecmisine (yonetici goruntuleyici)
        if (messages.applyEdit(m.getId(), m.getBodyCiphertext(), m.getBodyNonce(), m.getKeyVersion(), now) == 0) {
            throw new ApiException(HttpStatus.CONFLICT, "MESSAGE_NOT_EDITABLE", "Bu mesaj düzenlenemez.");
        }
        clearLegacyPlaintext(m.getId());
        m.setEditedAt(now);
        MessageView view = assembler.assemble(userId, List.of(m), Set.of(), a.since).get(0);
        // Olaya gonderenin gorunumu gider: tek gosterimlik ekler (url'siz) alicilari yaniltmasin diye olaydan cikarilir
        MessageView evView = view.withExtras(null, List.of(), null)
                .withAttachments(view.attachments().stream().filter(x -> !x.viewOnce()).toList());
        publish(a, userId,
                new MessageEvent("edited", m.getConversationId(), m.getId(), userId, evView,
                        null, null, now.toString()));
        return view;
    }

    // --- silme ---

    /**
     * Herkes icin silme: gonderen (`app.chat.delete-window-minutes` doluysa o sure icinde) ya da grup yoneticisi (suresiz).
     * Kullanici icin mesaj "silindi" gorunur (icerik/ek erisimi kapanir; tepkiler silinir) AMA sifreli govde, nonce ve
     * anahtar surumu VERITABANINDA KALIR (deleted_at/deleted_by); yalnizca yonetici goruntuleyici cozer.
     * Saklama: `app.chat.deleted-retention-days` (0 = suresiz). Tekrar silme sessizce basarilidir (idempotent).
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
        reactions.removeAll(m.getId());
        // Ekler SILINMEZ: kullanici erisimi kapanir (MessageAttachmentService.accessible mesaj silinmisse bos doner,
        // goruntu meta verisi de donmez); bayt yonetici onizlemesi icin saklanir (T24).
        publish(a, userId, new MessageEvent("deleted", m.getConversationId(), m.getId(), userId,
                null, null, null, now.toString()));
    }

    // --- tepkiler ---

    public ReactionSummary react(Long userId, Long messageId, String emoji) {
        String e = emoji == null ? "" : normalize(emoji);
        if (e.isEmpty() || !allowedReactions.contains(e)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "REACTION_NOT_ALLOWED", "Bu tepki kullanılamaz.");
        }
        Access a = reactable(userId, messageId);
        if (blockedByPeer(a.conversation, userId)) { // golge engel: yazilmaz, olay yok, hata yok
            ReactionSummary s = summary(messageId, userId);
            return new ReactionSummary(messageId, s.reactions(), e);
        }
        reactions.upsert(messageId, userId, e, Instant.now());
        return afterReaction(a, userId, e);
    }

    public ReactionSummary unreact(Long userId, Long messageId) {
        Access a = reactable(userId, messageId);
        if (blockedByPeer(a.conversation, userId)) {
            return new ReactionSummary(messageId, summary(messageId, userId).reactions(), null);
        }
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
        return a;
    }

    private ReactionSummary afterReaction(Access a, Long userId, String emoji) {
        ReactionSummary s = summary(a.message.getId(), userId);
        publish(a, userId, new MessageEvent("reaction", a.message.getConversationId(),
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
        if (m.isSuppressed() && !m.getSenderId().equals(userId)) { // golge engel: alici icin yok
            throw messageNotFound();
        }
        if (users.findById(userId).filter(User::isActive).isEmpty()) {
            throw new ApiException(HttpStatus.FORBIDDEN, "ACCOUNT_SUSPENDED", "Hesabınız askıya alındı.");
        }
        return new Access(m, conv, me, since);
    }

    /**
     * Birebirde karsi taraf cagirani ENGELLEMIS mi (golge engel). Engelleyen kendi eylemlerinde etkilenmez; engellenen
     * taraf icin eylemler sessizce yazilmaz (hata kodu/alan farki birakilmaz).
     */
    private boolean blockedByPeer(Conversation conv, Long userId) {
        if (conv.getType() != Conversation.Type.DIRECT) {
            return false;
        }
        return members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(conv.getId()).stream()
                .map(ConversationMember::getUserId).filter(id -> !id.equals(userId))
                .anyMatch(peer -> blocks.hasBlocked(peer, userId));
    }

    /** Gecis donemindeki eski duz metin sutunu varsa temizler (tombstone/duzenleme sonrasi duz metin kalmasin). */
    private void clearLegacyPlaintext(Long messageId) {
        if (codec.legacyColumnPresent()) {
            jdbc.update("UPDATE message SET body = NULL WHERE id = ? AND body IS NOT NULL", messageId);
        }
    }

    /**
     * Aktif uyelere (eylemi yapanin diger cihazlari dahil); engel iliskisi olanlara gitmez. GRUPTA katilma oncesi
     * mesajlarin olayi (duzenlenmis metin, tepki) sonradan katilanlara ve "sohbeti sil" ile temizleyenlere gitmez (T-030):
     * gecmis uclari ile ayni kural.
     */
    private void publish(Access a, Long actorId, MessageEvent event) {
        try {
            Set<Long> related = blocks.hiddenFrom(actorId);
            boolean group = a.conversation.getType() == Conversation.Type.GROUP;
            Instant created = a.message.getCreatedAt();
            long msgId = a.message.getId();
            List<Long> recipients = members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(a.conversation.getId()).stream()
                    .filter(m -> m.getUserId().equals(actorId) || (!related.contains(m.getUserId())
                            && !(group && created != null && created.isBefore(m.getJoinedAt()))
                            && msgId > m.getClearedUpToMessageId()))
                    .map(ConversationMember::getUserId).toList();
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
