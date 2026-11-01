package edu.bingol.backend.messaging.room;

import java.util.List;
import org.springframework.stereotype.Service;

/** Konusma bir sohbet odasiysa kulup/etkinlik yetkisine gore moderasyon yetkisini cozer (mesaj silme). */
@Service
public class RoomModeration {

    private final ChatRoomLinkRepository links;
    private final List<RoomModerationAuthorizer> authorizers;

    public RoomModeration(ChatRoomLinkRepository links, List<RoomModerationAuthorizer> authorizers) {
        this.links = links;
        this.authorizers = authorizers;
    }

    /** Oda degilse ya da kapali/yetkisiz ise false. */
    public boolean canModerate(Long conversationId, Long userId) {
        return links.findByConversationId(conversationId)
                .map(l -> canModerate(l, userId))
                .orElse(false);
    }

    /** Baglanti zaten yukluyse (konusma listesi) satir basina ek baglanti sorgusu atilmaz (FIX-P03, A02#8). */
    public boolean canModerate(ChatRoomLink link, Long userId) {
        return authorizers.stream()
                .anyMatch(a -> a.kind() == link.getKind() && a.canModerate(link.getRefId(), userId));
    }
}
