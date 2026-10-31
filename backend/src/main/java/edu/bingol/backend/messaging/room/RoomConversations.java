package edu.bingol.backend.messaging.room;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.messaging.Conversation;
import edu.bingol.backend.messaging.ConversationMember;
import edu.bingol.backend.messaging.ConversationMemberRepository;
import edu.bingol.backend.messaging.ConversationRepository;
import edu.bingol.backend.messaging.dto.MessagingDtos;
import edu.bingol.backend.messaging.ws.ChatEventBus;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Instant;
import java.util.Collection;
import java.util.Optional;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * GENEL sohbet odasi altyapisi (kulup, etkinlik...). Oda = mevcut bir GRUP konusmasi + {@code chat_room_link}
 * baglantisi; mesajlasma kodu odayi sade bir grup olarak gorur.
 *
 * <p>Odadaki hic kimse ConversationMember.Role.ADMIN degildir: boylece sohbet tarafindaki elle uye ekleme/cikarma/
 * yeniden adlandirma uclari (grup yoneticisi ister) odada calismaz; uyelik yalnizca kaynagin (kulup/etkinlik)
 * uyeligiyle senkron tutulur. Ust sinir {@code app.chat.room-max-members} (varsayilan 500); normal grup siniri
 * (ConversationService.MAX_MEMBERS = 50) odayi etkilemez. Yalnizca ACTIVE ve e-postasi dogrulanmis kullanici girer.
 */
@Service
public class RoomConversations {

    private final ChatRoomLinkRepository links;
    private final ConversationRepository convs;
    private final ConversationMemberRepository members;
    private final UserRepository users;
    private final int maxMembers;

    public RoomConversations(ChatRoomLinkRepository links, ConversationRepository convs,
                             ConversationMemberRepository members, UserRepository users,
                             @Value("${app.chat.room-max-members:500}") int maxMembers) {
        this.links = links;
        this.convs = convs;
        this.members = members;
        this.users = users;
        this.maxMembers = Math.max(2, maxMembers);
    }

    /** Odanin durumu: conversationId sohbet uclarinda (mesaj gonder/oku) kullanilan kimliktir. */
    public record RoomInfo(Long conversationId, RoomKind kind, Long refId, boolean closed) {}

    /**
     * Odayi yoksa olusturur (idempotent, yaristan guvenli) ve conversationId'yi doner. Sahip odaya uye olarak
     * girer (aktifse). Kapali odayi acmaz.
     */
    @Transactional
    public Long ensureRoom(RoomKind kind, Long refId, String title, Long ownerUserId) {
        Optional<ChatRoomLink> existing = links.findByKindAndRefId(kind, refId);
        if (existing.isPresent()) {
            return existing.get().getConversationId();
        }
        Conversation c = new Conversation();
        c.setType(Conversation.Type.GROUP);
        c.setTitle(cut(title));
        c.setCreatedBy(ownerUserId);
        c = convs.save(c);
        if (links.insertIfAbsent(kind.name(), refId, c.getId(), Instant.now()) == 0) {
            // Es zamanli istek once davrandi: bizim konusmayi at, onunkini kullan.
            convs.deleteById(c.getId());
            return links.findByKindAndRefId(kind, refId).orElseThrow().getConversationId();
        }
        addTo(c.getId(), ownerUserId, c);
        return c.getId();
    }

    @Transactional(readOnly = true)
    public Optional<RoomInfo> find(RoomKind kind, Long refId) {
        return links.findByKindAndRefId(kind, refId).map(RoomConversations::info);
    }

    /** Kullanici odanin su an AKTIF uyesi mi. */
    @Transactional(readOnly = true)
    public boolean isMember(RoomKind kind, Long refId, Long userId) {
        return links.findByKindAndRefId(kind, refId)
                .map(l -> members.findByConversationIdAndUserIdAndLeftAtIsNull(l.getConversationId(), userId).isPresent())
                .orElse(false);
    }

    @Transactional(readOnly = true)
    public long memberCount(RoomKind kind, Long refId) {
        return links.findByKindAndRefId(kind, refId)
                .map(l -> members.countByConversationIdAndLeftAtIsNull(l.getConversationId())).orElse(0L);
    }

    /**
     * Kullaniciyi odaya ekler (zaten uyeyse true). Oda yok/kapali ya da kullanici uygun degilse (askida, silinmis,
     * dogrulanmamis) false. Oda doluysa 409 ROOM_FULL.
     */
    @Transactional
    public boolean addMember(RoomKind kind, Long refId, Long userId) {
        ChatRoomLink l = links.findByKindAndRefId(kind, refId).orElse(null);
        if (l == null || l.isClosed()) {
            return false;
        }
        convs.lockById(l.getConversationId()); // sinir kontrolu es zamanli eklemelerde asilmasin
        return addTo(l.getConversationId(), userId, null);
    }

    /** Birden cok kullaniciyi ekler; dolunca durur. Eklenen/zaten uye olan sayisini doner. */
    @Transactional
    public int addMembers(RoomKind kind, Long refId, Collection<Long> userIds) {
        ChatRoomLink l = links.findByKindAndRefId(kind, refId).orElse(null);
        if (l == null || l.isClosed()) {
            return 0;
        }
        convs.lockById(l.getConversationId());
        int n = 0;
        for (Long uid : userIds) {
            try {
                if (addTo(l.getConversationId(), uid, null)) {
                    n++;
                }
            } catch (ApiException e) {
                break; // ROOM_FULL
            }
        }
        return n;
    }

    /** Kullaniciyi odadan cikarir (uye degilse no-op); cikarildiysa true. */
    @Transactional
    public boolean removeMember(RoomKind kind, Long refId, Long userId) {
        ChatRoomLink l = links.findByKindAndRefId(kind, refId).orElse(null);
        if (l == null) {
            return false;
        }
        ConversationMember m = members.findByConversationIdAndUserIdAndLeftAtIsNull(l.getConversationId(), userId)
                .orElse(null);
        if (m == null) {
            return false;
        }
        m.setLeftAt(Instant.now());
        members.save(m);
        notifyRemoved(l.getConversationId(), java.util.List.of(userId));
        return true;
    }

    /**
     * Toplu bakim gibi dogrudan SQL ile uyelik dusen akislar icin: ayni conversation-removed olayini yayinlar (C3).
     * Commit sonrasi (islem varsa) ya da hemen gonderilir; hata sizdirmaz.
     */
    public void announceRemoved(Long conversationId, Collection<Long> userIds) {
        notifyRemoved(conversationId, userIds);
    }

    /** Ayrilan/cikarilan kullanicilarin istemcisi konusmayi listeden dusursun (`/user/queue/message-events`). */
    private void notifyRemoved(Long conversationId, Collection<Long> userIds) {
        if (bus == null || userIds.isEmpty()) {
            return;
        }
        Runnable send = () -> {
            try {
                bus.publish("message-events", userIds, new MessagingDtos.ConversationRemovedEvent(
                        "conversation-removed", conversationId, Instant.now().toString()));
            } catch (RuntimeException e) {
                // teslim hatasi islemi bozmaz; istemci listeyi yenileyince konusma zaten gelmez
            }
        };
        if (org.springframework.transaction.support.TransactionSynchronizationManager.isSynchronizationActive()) {
            org.springframework.transaction.support.TransactionSynchronizationManager.registerSynchronization(
                    new org.springframework.transaction.support.TransactionSynchronization() {
                        @Override
                        public void afterCommit() {
                            send.run();
                        }
                    });
        } else {
            send.run();
        }
    }

    private ChatEventBus bus;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    public void setBus(ChatEventBus bus) {
        this.bus = bus;
    }

    /**
     * removeMember'in bagimsiz (REQUIRES_NEW) surumu: cagiranin transaction'i commit olduktan sonra (afterCommit)
     * calistirilir; hata cagiranin transaction'ini rollback-only yapmaz.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public boolean removeMemberIsolated(RoomKind kind, Long refId, Long userId) {
        return removeMember(kind, refId, userId);
    }

    /** closeRoom'un bagimsiz (REQUIRES_NEW) surumu; bkz. {@link #removeMemberIsolated}. */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void closeRoomIsolated(RoomKind kind, Long refId) {
        closeRoom(kind, refId);
    }

    /** Odayi kapatir: herkes cikarilir, yeni uye eklenmez. Gecmis veritabaninda kalir. Idempotent. */
    @Transactional
    public void closeRoom(RoomKind kind, Long refId) {
        links.findByKindAndRefId(kind, refId).ifPresent(l -> {
            java.util.List<Long> leaving = members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(l.getConversationId())
                    .stream().map(ConversationMember::getUserId).toList();
            l.setClosed(true);
            links.save(l);
            links.leaveAll(l.getConversationId(), Instant.now());
            notifyRemoved(l.getConversationId(), leaving);
        });
    }

    /** Kapali odayi acar ve verilen kullanicilari (kaynagin aktif uyeleri) yeniden ekler. */
    @Transactional
    public void openRoom(RoomKind kind, Long refId, Collection<Long> memberIds) {
        ChatRoomLink l = links.findByKindAndRefId(kind, refId).orElse(null);
        if (l == null) {
            return;
        }
        if (l.isClosed()) {
            l.setClosed(false);
            links.save(l);
        }
        addMembers(kind, refId, memberIds);
    }

    /** Oda basligini gunceller (kulup adi degisince). */
    @Transactional
    public void renameRoom(RoomKind kind, Long refId, String title) {
        links.findByKindAndRefId(kind, refId).flatMap(l -> convs.findById(l.getConversationId())).ifPresent(c -> {
            c.setTitle(cut(title));
            convs.save(c);
        });
    }

    /** Zamanlanmis temizlik: askiya alinan/silinen kullanicilari tum odalardan cikarir. */
    @Transactional
    public int purgeInactiveUsers() {
        return links.purgeInactiveUsers(Instant.now());
    }

    // ---- ic yardimcilar ----

    /** Cagiran kilidi almis olmali. {@code known} varsa konusma tekrar okunmaz. */
    private boolean addTo(Long conversationId, Long userId, Conversation known) {
        User u = users.findById(userId).orElse(null);
        if (u == null || !u.isActive() || !u.isEmailVerified()) {
            return false;
        }
        ConversationMember m = members.findByConversationIdAndUserId(conversationId, userId).orElse(null);
        if (m != null && m.getLeftAt() == null) {
            return true;
        }
        if (members.countByConversationIdAndLeftAtIsNull(conversationId) >= maxMembers) {
            throw new ApiException(HttpStatus.CONFLICT, "ROOM_FULL", "Sohbet odası dolu.", String.valueOf(maxMembers));
        }
        Conversation c = known != null ? known : convs.findById(conversationId).orElse(null);
        long lastMsg = c == null || c.getLastMessageId() == null ? 0L : c.getLastMessageId();
        if (m == null) {
            m = ConversationMember.of(conversationId, userId, ConversationMember.Role.MEMBER);
        } else {
            // Yeniden giris: onceki gecmis gorunmez, eski mesajlar okunmamis sayilmaz.
            m.setLeftAt(null);
            m.setJoinedAt(Instant.now());
            m.setRole(ConversationMember.Role.MEMBER);
        }
        m.setLastReadMessageId(lastMsg);
        m.setHiddenAt(null);
        m.setLastDeliveredMessageId(lastMsg);
        members.save(m);
        return true;
    }

    private static RoomInfo info(ChatRoomLink l) {
        return new RoomInfo(l.getConversationId(), l.getKind(), l.getRefId(), l.isClosed());
    }

    private static String cut(String title) {
        String t = title == null || title.isBlank() ? "Sohbet" : title.trim();
        return t.length() <= 100 ? t : t.substring(0, 100);
    }
}
