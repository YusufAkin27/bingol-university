package edu.bingol.backend.messaging;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.messaging.dto.MessagingDtos.ConversationDetail;
import edu.bingol.backend.messaging.dto.MessagingDtos.ConversationView;
import edu.bingol.backend.messaging.dto.MessagingDtos.MemberView;
import edu.bingol.backend.messaging.dto.MessagingDtos.MessageView;
import edu.bingol.backend.messaging.dto.MessagingDtos.UserSummary;
import edu.bingol.backend.messaging.media.AttachmentView;
import edu.bingol.backend.messaging.media.MessageAttachmentService;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Instant;
import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Konusma olusturma/listeleme ve grup yonetimi. Yonetici = grubu olusturan (ayrilirsa en eski uye devralir).
 * Engelli birebir konusmalar listede KALIR (`blocked=true`), gecmis okunabilir ama gonderim 403 BLOCKED olur.
 */
@Service
public class ConversationService {

    public static final int MAX_MEMBERS = 50;

    /** `created` false ise birebir konusma zaten vardi. */
    public record Opened(ConversationView conversation, boolean created) {}

    private final ConversationRepository convs;
    private final ConversationMemberRepository members;
    private final MessageRepository messages;
    private final UserRepository users;
    private final BlockService blocks;
    private final MessageCodec codec;
    /** T8: son mesaj onizlemesinde gorsel ekleri (setter enjeksiyonu; yoksa eksiz). */
    private MessageAttachmentService attachments;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setAttachments(MessageAttachmentService attachments) {
        this.attachments = attachments;
    }

    /** Kulup/etkinlik odasi baglantilari: gorunumde tur (CLUB/EVENT) ve kaynak kimligi buradan turetilir. */
    private edu.bingol.backend.messaging.room.ChatRoomLinkRepository roomLinks;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setRoomLinks(edu.bingol.backend.messaging.room.ChatRoomLinkRepository roomLinks) {
        this.roomLinks = roomLinks;
    }

    public ConversationService(ConversationRepository convs, ConversationMemberRepository members,
                               MessageRepository messages, UserRepository users, BlockService blocks, MessageCodec codec) {
        this.codec = codec;
        this.convs = convs;
        this.members = members;
        this.messages = messages;
        this.users = users;
        this.blocks = blocks;
    }

    /** Birebir konusmayi acar; varsa mevcudu doner. Benzersiz `direct_key` yaris kosulunda cift olusmasini onler. */
    @Transactional
    public Opened openDirect(Long me, Long otherId) {
        if (otherId == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "userId gerekli.");
        }
        if (me.equals(otherId)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "CANNOT_MESSAGE_SELF", "Kendinizle konuşma başlatamazsınız.");
        }
        requireMessageable(List.of(otherId));
        if (blocks.isBlocked(me, otherId)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "BLOCKED", "Bu kullanıcıyla mesajlaşamazsınız.");
        }
        String key = Conversation.directKey(me, otherId);
        boolean created = convs.insertDirect(key, me, Instant.now()) == 1;
        Conversation c = convs.findByDirectKey(key).orElseThrow();
        if (created) {
            members.save(ConversationMember.of(c.getId(), me, ConversationMember.Role.MEMBER));
            members.save(ConversationMember.of(c.getId(), otherId, ConversationMember.Role.MEMBER));
        }
        return new Opened(views(me, List.of(c)).get(0), created);
    }

    @Transactional
    public ConversationView createGroup(Long me, String title, List<Long> memberIds) {
        String t = title == null ? "" : title.trim();
        if (t.isEmpty() || t.length() > 100) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Grup başlığı 1-100 karakter olmalı.");
        }
        Set<Long> ids = new LinkedHashSet<>(memberIds == null ? List.of() : memberIds);
        ids.remove(me);
        if (ids.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "En az bir üye ekleyin.");
        }
        if (ids.size() + 1 > MAX_MEMBERS) {
            throw groupFull();
        }
        requireMessageable(ids);
        requireNotBlocked(me, ids);

        Conversation c = new Conversation();
        c.setType(Conversation.Type.GROUP);
        c.setTitle(t);
        c.setCreatedBy(me);
        c = convs.save(c);
        members.save(ConversationMember.of(c.getId(), me, ConversationMember.Role.ADMIN));
        for (Long id : ids) {
            members.save(ConversationMember.of(c.getId(), id, ConversationMember.Role.MEMBER));
        }
        return views(me, List.of(c)).get(0);
    }

    /** Mesaji olan konusmalar, en yeni mesaj once. Imlec = onceki sayfanin son `lastMessage.id` degeri. */
    @Transactional(readOnly = true)
    public CursorPage<ConversationView> list(Long me, Long cursor, int size) {
        return list(me, cursor, size, false);
    }

    /** `archived` true: yalniz arsivdekiler; false: arsivdekiler listelenmez. */
    @Transactional(readOnly = true)
    public CursorPage<ConversationView> list(Long me, Long cursor, int size, boolean archived) {
        int s = CursorPage.clampSize(size);
        List<Conversation> rows = convs.page(me, cursor, archived, PageRequest.of(0, s + 1));
        boolean more = rows.size() > s;
        List<Conversation> page = more ? rows.subList(0, s) : rows;
        return new CursorPage<>(views(me, page), more ? page.get(page.size() - 1).getLastMessageId() : null);
    }

    @Transactional(readOnly = true)
    public ConversationDetail detail(Long me, Long id) {
        requireMember(id, me);
        Conversation c = convs.findById(id).orElseThrow(ConversationService::notFound);
        List<ConversationMember> active = members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(id);
        Map<Long, User> byId = users.findAllById(active.stream().map(ConversationMember::getUserId).toList()).stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));
        List<MemberView> list = active.stream().filter(m -> byId.containsKey(m.getUserId()))
                .map(m -> new MemberView(m.getUserId(), byId.get(m.getUserId()).getDisplayName(),
                        byId.get(m.getUserId()).getAvatarUrl(), m.getRole().name())).toList();
        return new ConversationDetail(views(me, List.of(c)).get(0), list);
    }

    /** Tek konusmanin gorunumu (yalnizca aktif uye). Kulup/etkinlik sohbet uclari kullanir. */
    @Transactional(readOnly = true)
    public ConversationView view(Long me, Long id) {
        requireMember(id, me);
        Conversation c = convs.findById(id).orElseThrow(ConversationService::notFound);
        return views(me, List.of(c)).get(0);
    }

    @Transactional
    public ConversationView rename(Long me, Long id, String title) {
        Conversation c = requireGroupAdmin(id, me);
        String t = title == null ? "" : title.trim();
        if (t.isEmpty() || t.length() > 100) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Grup başlığı 1-100 karakter olmalı.");
        }
        c.setTitle(t);
        convs.save(c);
        return views(me, List.of(c)).get(0);
    }

    @Transactional
    public ConversationView addMembers(Long me, Long id, List<Long> userIds) {
        Conversation c = requireGroupAdmin(id, me);
        convs.lockById(id); // uye sayisi siniri es zamanli eklemelerde asilmasin
        Set<Long> ids = new LinkedHashSet<>(userIds);
        ids.remove(me);
        if (ids.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Eklenecek üye yok.");
        }
        requireMessageable(ids);
        requireNotBlocked(me, ids);

        long current = members.countByConversationIdAndLeftAtIsNull(id);
        long adding = ids.stream().filter(uid -> members.findByConversationIdAndUserIdAndLeftAtIsNull(id, uid).isEmpty()).count();
        if (current + adding > MAX_MEMBERS) {
            throw groupFull();
        }
        for (Long uid : ids) {
            ConversationMember m = members.findByConversationIdAndUserId(id, uid).orElse(null);
            if (m == null) {
                m = ConversationMember.of(id, uid, ConversationMember.Role.MEMBER);
            } else if (m.getLeftAt() == null) {
                continue; // zaten uye
            } else {
                // Yeniden ekleme: onceki mesajlar okunmamis sayilmaz, onceki gecmis gorunmez.
                m.setLeftAt(null);
                m.setJoinedAt(Instant.now());
                m.setRole(ConversationMember.Role.MEMBER);
            }
            m.setLastReadMessageId(c.getLastMessageId() == null ? 0L : c.getLastMessageId());
            members.save(m);
        }
        return views(me, List.of(c)).get(0);
    }

    /** Yonetici baskasini cikarir; kendi id'si verilirse ayrilma sayilir. */
    @Transactional
    public void removeMember(Long me, Long id, Long targetId) {
        if (me.equals(targetId)) {
            leave(me, id);
            return;
        }
        requireGroupAdmin(id, me);
        ConversationMember target = members.findByConversationIdAndUserIdAndLeftAtIsNull(id, targetId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "MEMBER_NOT_FOUND", "Üye bulunamadı."));
        target.setLeftAt(Instant.now());
        members.save(target);
    }

    /** Gruptan ayril. Yonetici ayrilirsa en eski uye yonetici olur. */
    @Transactional
    public void leave(Long me, Long id) {
        Conversation c = convs.findById(id).orElseThrow(ConversationService::notFound);
        ConversationMember self = requireMember(id, me);
        // Kulup/etkinlik odasindan elle ayrilinmaz: uyelik kaynaga (kulup/RSVP) bagli, oradan senkronlanir.
        if (c.getType() != Conversation.Type.GROUP || (roomLinks != null && !roomLinks.findByConversationIdIn(List.of(id)).isEmpty())) {
            throw notGroup();
        }
        self.setLeftAt(Instant.now());
        members.save(self);
        if (self.isAdmin()) {
            List<ConversationMember> rest = members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(id);
            if (!rest.isEmpty() && rest.stream().noneMatch(ConversationMember::isAdmin)) {
                rest.get(0).setRole(ConversationMember.Role.ADMIN);
                members.save(rest.get(0));
            }
        }
    }

    // --- yardimcilar ---

    /** Her biri var, aktif ve e-postasi dogrulanmis olmali; yoksa 404 (hangisinin gecersiz oldugu soylenmez). */
    private void requireMessageable(Collection<Long> ids) {
        List<User> found = users.findAllById(ids);
        if (found.size() != ids.size() || found.stream().anyMatch(u -> !u.isActive() || !u.isEmailVerified())) {
            throw new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı.");
        }
    }

    private void requireNotBlocked(Long me, Collection<Long> ids) {
        Set<Long> related = blocks.hiddenFrom(me);
        if (ids.stream().anyMatch(related::contains)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "BLOCKED", "Engel ilişkisi olan kullanıcı eklenemez.");
        }
    }

    private ConversationMember requireMember(Long conversationId, Long userId) {
        return members.findByConversationIdAndUserIdAndLeftAtIsNull(conversationId, userId)
                .orElseThrow(ConversationService::notFound);
    }

    private Conversation requireGroupAdmin(Long id, Long me) {
        ConversationMember m = requireMember(id, me);
        Conversation c = convs.findById(id).orElseThrow(ConversationService::notFound);
        if (c.getType() != Conversation.Type.GROUP) {
            throw notGroup();
        }
        if (!m.isAdmin()) {
            throw new ApiException(HttpStatus.FORBIDDEN, "NOT_GROUP_ADMIN", "Bu işlem için grup yöneticisi olmalısınız.");
        }
        return c;
    }

    /** Toplu gorunum: uyeler, karsi taraf profilleri, son mesajlar ve okunmamis sayilari tek seferde yuklenir. */
    private List<ConversationView> views(Long me, List<Conversation> page) {
        if (page.isEmpty()) {
            return List.of();
        }
        List<Long> ids = page.stream().map(Conversation::getId).toList();
        Map<Long, List<ConversationMember>> membersBy = members.findByConversationIdInAndLeftAtIsNull(ids).stream()
                .collect(Collectors.groupingBy(ConversationMember::getConversationId));
        List<Long> peerIds = page.stream().filter(c -> c.getType() == Conversation.Type.DIRECT)
                .map(c -> peerOf(membersBy.getOrDefault(c.getId(), List.of()), me)).filter(java.util.Objects::nonNull).toList();
        Map<Long, User> peers = users.findAllById(peerIds).stream().collect(Collectors.toMap(User::getId, Function.identity()));
        Map<Long, Message> lastMessages = messages.findAllById(
                page.stream().map(Conversation::getLastMessageId).filter(java.util.Objects::nonNull).toList()).stream()
                .collect(Collectors.toMap(Message::getId, Function.identity()));
        codec.openAll(new java.util.ArrayList<>(lastMessages.values())); // son mesaj onizlemesi: sifre cozulur
        Map<Long, List<AttachmentView>> lastAtt = attachments == null ? Map.of() : attachments.viewsFor(lastMessages.keySet());
        Map<Long, Long> unread = new HashMap<>();
        for (Object[] row : messages.unreadCounts(me, ids)) {
            unread.put((Long) row[0], (Long) row[1]);
        }
        Set<Long> related = blocks.hiddenFrom(me);
        Map<Long, edu.bingol.backend.messaging.room.ChatRoomLink> roomOf = roomLinks == null ? Map.of()
                : roomLinks.findByConversationIdIn(ids).stream().collect(Collectors.toMap(
                        edu.bingol.backend.messaging.room.ChatRoomLink::getConversationId, Function.identity(), (x, y) -> x));

        return page.stream().map(c -> {
            List<ConversationMember> ms = membersBy.getOrDefault(c.getId(), List.of());
            boolean direct = c.getType() == Conversation.Type.DIRECT;
            Long peerId = direct ? peerOf(ms, me) : null;
            UserSummary peer = peerId == null || !peers.containsKey(peerId) ? null : UserSummary.of(peers.get(peerId));
            Message last = c.getLastMessageId() == null ? null : lastMessages.get(c.getLastMessageId());
            // Gruba sonradan katilan, katilmadan onceki son mesaji onizlemede de gormez (gecmisle tutarli).
            Instant joined = ms.stream().filter(m -> m.getUserId().equals(me)).map(ConversationMember::getJoinedAt)
                    .findFirst().orElse(Instant.EPOCH);
            MessageView lastView = last == null || (!direct && last.getCreatedAt().isBefore(joined)) ? null
                    : MessageView.of(last, !direct && related.contains(last.getSenderId()) && !last.getSenderId().equals(me))
                    .withAttachments(lastAtt.get(last.getId()));
            boolean admin = ms.stream().anyMatch(m -> m.getUserId().equals(me) && m.isAdmin());
            ConversationMember mine = ms.stream().filter(m -> m.getUserId().equals(me)).findFirst().orElse(null);
            boolean muted = mine != null && mine.isMuted();
            var room = roomOf.get(c.getId());
            boolean club = room != null && room.getKind() == edu.bingol.backend.messaging.room.RoomKind.COMMUNITY;
            boolean event = room != null && room.getKind() == edu.bingol.backend.messaging.room.RoomKind.EVENT;
            String type = club ? "CLUB" : event ? "EVENT" : c.getType().name();
            return new ConversationView(c.getId(), type, c.getTitle(), peer, ms.size(), admin, lastView,
                    unread.getOrDefault(c.getId(), 0L), direct && peerId != null && related.contains(peerId),
                    c.getCreatedAt().toString(), muted, muted ? mine.getMutedUntil().toString() : null,
                    mine != null && mine.getArchivedAt() != null,
                    club ? room.getRefId() : null, event ? room.getRefId() : null);
        }).toList();
    }

    private static Long peerOf(List<ConversationMember> ms, Long me) {
        return ms.stream().map(ConversationMember::getUserId).filter(id -> !id.equals(me)).findFirst().orElse(null);
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "CONVERSATION_NOT_FOUND", "Konuşma bulunamadı.");
    }

    private static ApiException notGroup() {
        return new ApiException(HttpStatus.BAD_REQUEST, "NOT_A_GROUP", "Bu işlem yalnızca gruplarda yapılabilir.");
    }

    private static ApiException groupFull() {
        return new ApiException(HttpStatus.BAD_REQUEST, "GROUP_FULL", "Bir grupta en fazla " + MAX_MEMBERS + " üye olabilir.",
                String.valueOf(MAX_MEMBERS));
    }
}
