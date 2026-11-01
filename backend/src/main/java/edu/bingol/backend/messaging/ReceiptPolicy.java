package edu.bingol.backend.messaging;

import edu.bingol.backend.messaging.room.ChatRoomLink;
import edu.bingol.backend.messaging.room.ChatRoomLinkRepository;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Okundu/iletildi tikleri ve "yaziyor" bilgisinin hangi konusmalarda tutuldugunu belirler (FIX-P03, karar K2).
 * Birebir her zaman acik; kulup/etkinlik odalari ve `app.chat.receipts-max-members` (varsayilan 20) uyeyi asan
 * gruplarda kapali: bu konusmalarda sunucu yalniz uyenin kendi imlecini ilerletir, diger uyelere olay yayinlamaz
 * (500 uyeli odada her okuma 499 alicili iki olay + gonderen basina sorgu uretiyordu).
 */
@Component
public class ReceiptPolicy {

    /** Karar onbellegi omru: uyelik sayisi dakikalar icinde onemli oranda degismez; satir basina sorguyu keser. */
    static final long TTL_NANOS = 60_000_000_000L;
    static final int CACHE_CAP = 20_000;

    private final ConversationMemberRepository members;
    private final ChatRoomLinkRepository roomLinks;
    private final int maxMembers;
    private final ConcurrentHashMap<Long, Decision> cache = new ConcurrentHashMap<>();

    private record Decision(boolean tracked, long expiresAt) {}

    public ReceiptPolicy(ConversationMemberRepository members, ChatRoomLinkRepository roomLinks,
                         @Value("${app.chat.receipts-max-members:20}") int maxMembers) {
        this.members = members;
        this.roomLinks = roomLinks;
        this.maxMembers = Math.max(2, maxMembers);
    }

    public int maxMembers() {
        return maxMembers;
    }

    /** Konusma bir kulup/etkinlik odasi mi (tek PK/benzersiz sorgu). */
    public boolean isRoom(Long conversationId) {
        return roomLinks != null && roomLinks.findByConversationId(conversationId).isPresent();
    }

    /**
     * Konusmada makbuz/yaziyor tutulur mu? Birebir: evet. Grup: oda degilse ve aktif uye sayisi sinirin altindaysa.
     * Sonuc 60 sn onbelleklenir (typing ve markRead sik cagrilir).
     */
    public boolean tracked(Conversation conv) {
        return conv.getType() == Conversation.Type.DIRECT || tracked(conv.getId());
    }

    /** Tur bilinmiyorsa: 2 ve daha az uyeli konusma birebir sayilir (her zaman acik). */
    public boolean tracked(Long conversationId) {
        long now = System.nanoTime();
        Decision d = cache.get(conversationId);
        if (d != null && d.expiresAt() > now) {
            return d.tracked();
        }
        long n = members.countByConversationIdAndLeftAtIsNull(conversationId);
        boolean ok = n <= 2 || (n <= maxMembers && !isRoom(conversationId));
        if (cache.size() >= CACHE_CAP) {
            cache.clear();
        }
        cache.put(conversationId, new Decision(ok, now + TTL_NANOS));
        return ok;
    }

    /** Onbellegi atar (uyelik degisince cagrilabilir; zorunlu degil, TTL zaten kisadir). */
    public void invalidate(Long conversationId) {
        cache.remove(conversationId);
    }

    /**
     * Verilen konusmalardan makbuz tutulanlar. `known`: aktif uye sayisi onceden biliniyorsa (konusma -> sayi), yoksa
     * tek GROUP BY sorgusuyla sayilir. 2 ve daha az uyeli konusma birebir sayilir (oda kontrolu yapilmaz).
     */
    public Set<Long> trackable(Collection<Long> conversationIds, Map<Long, Integer> known) {
        Map<Long, Integer> counts = new HashMap<>(known == null ? Map.of() : known);
        Set<Long> unknown = new HashSet<>(conversationIds);
        unknown.removeAll(counts.keySet());
        if (!unknown.isEmpty()) {
            for (Object[] row : members.activeCounts(unknown)) {
                counts.put((Long) row[0], ((Number) row[1]).intValue());
            }
        }
        Set<Long> out = new HashSet<>();
        Set<Long> groups = new HashSet<>();
        for (Long cid : conversationIds) {
            int n = counts.getOrDefault(cid, 0);
            if (n <= 2) {
                out.add(cid);
            } else if (n <= maxMembers) {
                groups.add(cid);
            }
        }
        if (!groups.isEmpty()) {
            Set<Long> rooms = new HashSet<>();
            if (roomLinks != null) {
                for (ChatRoomLink l : roomLinks.findByConversationIdIn(groups)) {
                    rooms.add(l.getConversationId());
                }
            }
            groups.removeAll(rooms);
            out.addAll(groups);
        }
        return out;
    }
}
