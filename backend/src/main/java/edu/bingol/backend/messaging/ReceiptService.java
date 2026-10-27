package edu.bingol.backend.messaging;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.messaging.dto.MessagingDtos.ReceiptEvent;
import edu.bingol.backend.messaging.ws.ChatEventBus;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Instant;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/**
 * Iletildi / okundu makbuzlari (WhatsApp tik mantigi). Uye basina iki imlec vardir (okundu >= iletildi).
 * Mesaj durumu (yalniz gonderenin kendi mesajinda): SENT -> DELIVERED -> READ; birebirde alici, grupta TUM diger
 * aktif uyeler (ayrilan / engel iliskisi olan / askidaki haric, mesajdan sonra katilanlar haric) esigi gecince.
 * Hesap sayfa basina toplu yapilir: konusma uyeleri tek sorguyla gelir, mesaj basina sorgu yoktur.
 */
@Service
public class ReceiptService {

    public static final String SENT = "SENT";
    public static final String DELIVERED = "DELIVERED";
    public static final String READ = "READ";
    /** Grup toplulastirmasinda bir ack icin bakilan en yeni mesaj sayisi (ust sinir). */
    static final int AGGREGATE_LIMIT = 200;
    /** Iletildi ack'i: kullanici basina dakikada (REST ve WS ortak anahtar). */
    public static final int DELIVERED_PER_MINUTE = 120;

    private static final Logger log = LoggerFactory.getLogger(ReceiptService.class);

    private final ConversationMemberRepository members;
    private final ConversationRepository convs;
    private final MessageRepository messages;
    private final UserRepository users;
    private final BlockService blocks;
    private final ChatEventBus bus;

    public ReceiptService(ConversationMemberRepository members, ConversationRepository convs, MessageRepository messages,
                          UserRepository users, BlockService blocks, ChatEventBus bus) {
        this.members = members;
        this.convs = convs;
        this.messages = messages;
        this.users = users;
        this.blocks = blocks;
        this.bus = bus;
    }

    // ------------------------------------------------------------------ durum hesabi

    /** Saf kural: `others` zaten elenmis (aktif, engelsiz) diger uyelerdir. */
    static String statusOf(Message m, boolean direct, Collection<ConversationMember> others) {
        List<ConversationMember> eligible = direct ? List.copyOf(others)
                : others.stream().filter(o -> !o.getJoinedAt().isAfter(m.getCreatedAt())).toList();
        if (eligible.isEmpty()) {
            return SENT;
        }
        long id = m.getId();
        if (eligible.stream().allMatch(o -> o.getLastReadMessageId() >= id)) {
            return READ;
        }
        if (eligible.stream().allMatch(o -> o.getLastDeliveredMessageId() >= id)) {
            return DELIVERED;
        }
        return SENT;
    }

    /**
     * `viewerId`in kendi mesajlarinin durumlari (mesaj kimligi -> durum). `membersBy`: konusma -> aktif uyeler
     * (null ise yuklenir). `direct`: konusma kimligi -> birebir mi (null ise uye sayisi 2 ise birebir sayilir).
     */
    public Map<Long, String> statuses(Long viewerId, Collection<Message> own,
                                      Map<Long, List<ConversationMember>> membersBy, Map<Long, Boolean> direct) {
        List<Message> mine = own.stream().filter(m -> viewerId.equals(m.getSenderId()) && !m.isDeleted() && !m.isHidden())
                .toList();
        if (mine.isEmpty()) {
            return Map.of();
        }
        Set<Long> cids = mine.stream().map(Message::getConversationId).collect(Collectors.toSet());
        Map<Long, List<ConversationMember>> by = membersBy;
        if (by == null) {
            by = members.findByConversationIdInAndLeftAtIsNull(cids).stream()
                    .collect(Collectors.groupingBy(ConversationMember::getConversationId));
        }
        Set<Long> excluded = new HashSet<>(blocks.hiddenFrom(viewerId));
        Set<Long> candidateIds = new HashSet<>();
        for (Long cid : cids) {
            by.getOrDefault(cid, List.of()).forEach(m -> candidateIds.add(m.getUserId()));
        }
        candidateIds.remove(viewerId);
        candidateIds.removeAll(excluded);
        if (!candidateIds.isEmpty()) {
            users.findAllById(candidateIds).stream().filter(u -> !u.isActive()).map(User::getId).forEach(excluded::add);
        }
        Map<Long, List<ConversationMember>> others = new HashMap<>();
        for (Long cid : cids) {
            others.put(cid, by.getOrDefault(cid, List.of()).stream()
                    .filter(o -> !o.getUserId().equals(viewerId) && !excluded.contains(o.getUserId())).toList());
        }
        Map<Long, String> out = new HashMap<>();
        for (Message m : mine) {
            if (m.isSuppressed()) { // golge engel: asla DELIVERED/READ olmaz
                out.put(m.getId(), SENT);
                continue;
            }
            boolean isDirect = direct != null && direct.containsKey(m.getConversationId())
                    ? direct.get(m.getConversationId())
                    : by.getOrDefault(m.getConversationId(), List.of()).size() <= 2;
            out.put(m.getId(), statusOf(m, isDirect, others.get(m.getConversationId())));
        }
        return out;
    }

    // ------------------------------------------------------------------ iletildi ack'i

    /**
     * Iletildi imleci: yalniz ileri; baskalarinin mesajlarina kadar ilerler (kendi mesajini ackleyemez). Ilerlediyse
     * mesaj sahiplerine `receipt` olayi gider. Bos konusma / ilerleme yoksa sessiz no-op. Uye degilse 404.
     */
    public void markDelivered(Long userId, Long conversationId, Long lastMessageId) {
        ConversationMember me = members.findByConversationIdAndUserIdAndLeftAtIsNull(conversationId, userId)
                .orElseThrow(ReceiptService::notFound);
        if (lastMessageId == null || lastMessageId <= 0) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_MESSAGE_ID", "Geçersiz mesaj kimliği.");
        }
        Conversation conv = convs.findById(conversationId).orElseThrow(ReceiptService::notFound);
        if (conv.getLastMessageId() == null) {
            return;
        }
        long upTo = Math.min(lastMessageId, conv.getLastMessageId());
        // Gruba sonradan katilan, katilmadan onceki mesajlari ackleyemez: imlec yalniz kendi gordugu mesajlara gider
        Long target = messages.maxIdFromOthers(conversationId, upTo, userId);
        long before = me.getLastDeliveredMessageId();
        if (target == null || target <= before) {
            return;
        }
        if (members.advanceDelivered(conversationId, userId, target) > 0) {
            publish(conv, userId, "delivered", before, target);
        }
    }

    /** `MessageService.markRead` ilerleme sonrasi cagirir: `read` olayi (+ iletildi imleci de ilerlediyse `delivered`). */
    public void onRead(Long userId, Long conversationId, long oldRead, long oldDelivered, long newCursor) {
        try {
            Conversation conv = convs.findById(conversationId).orElse(null);
            if (conv == null) {
                return;
            }
            if (oldDelivered < newCursor) {
                publish(conv, userId, "delivered", oldDelivered, newCursor);
            }
            publish(conv, userId, "read", oldRead, newCursor);
        } catch (RuntimeException e) {
            log.warn("Makbuz olayi yayinlanamadi (konusma {}): {}", conversationId, e.toString());
        }
    }

    /** (from, to] araligi icin mesaj sahiplerine olay. Engel iliskisi olanlara gitmez. */
    private void publish(Conversation conv, Long actor, String kind, long from, long to) {
        List<ConversationMember> active = members
                .findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(conv.getId());
        Set<Long> related = blocks.hiddenFrom(actor);
        String at = Instant.now().toString();
        if (conv.getType() == Conversation.Type.DIRECT) {
            List<Long> peers = active.stream().map(ConversationMember::getUserId)
                    .filter(id -> !id.equals(actor) && !related.contains(id)).toList();
            // Birebirde durum karsi tarafin imlecine esittir: olay dogrudan alicinin ilerlemesini tasir
            if (peers.isEmpty()) {
                return; // engel iliskisi: makbuz gitmez
            }
            // Golge engel: bastirilmis mesaj varsa imlec onun oncesinde kesilir (istemci o mesaji ilerletmesin)
            Long minSup = messages.minSuppressedId(conv.getId(), peers.get(0), from, to);
            long upTo = minSup != null && minSup > 0 ? minSup - 1 : to;
            if (upTo <= from) {
                return;
            }
            bus.publish("message-events", peers, new ReceiptEvent("receipt", conv.getId(), kind, upTo, actor, at,
                    "read".equals(kind) ? READ : DELIVERED));
            return;
        }
        Map<Long, List<ConversationMember>> by = Map.of(conv.getId(), active);
        int need = "read".equals(kind) ? 2 : 1;
        for (Long owner : messages.sendersInRange(conv.getId(), from, to, actor)) {
            if (related.contains(owner) || active.stream().noneMatch(a -> a.getUserId().equals(owner))) {
                continue;
            }
            List<Message> msgs = messages.ownedInRange(conv.getId(), owner, from, to, PageRequest.of(0, AGGREGATE_LIMIT));
            Map<Long, String> st = statuses(owner, msgs, by, Map.of(conv.getId(), false));
            Long best = null;
            String bestStatus = null;
            for (Message m : msgs) { // yeni -> eski: ilk saglayan en yuksek kimliktir
                String s = st.get(m.getId());
                if (s != null && level(s) >= need) {
                    best = m.getId();
                    bestStatus = s;
                    break;
                }
            }
            if (best != null) {
                bus.publish("message-events", List.of(owner), new ReceiptEvent("receipt", conv.getId(), kind, best,
                        actor, at, bestStatus));
            }
        }
    }

    private static int level(String status) {
        return READ.equals(status) ? 2 : DELIVERED.equals(status) ? 1 : 0;
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "CONVERSATION_NOT_FOUND", "Konuşma bulunamadı.");
    }
}
