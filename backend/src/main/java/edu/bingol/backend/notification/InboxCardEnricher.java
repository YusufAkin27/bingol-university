package edu.bingol.backend.notification;

import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.notification.dto.NotificationDtos.NotificationView;
import edu.bingol.backend.profile.privacy.AvatarVisibility;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.json.JsonMapper;

/**
 * Bildirim kutusu satirlarina kart alanlarini ekler (tasarim 08): kart/eylemler (NotifCard), gonderen adi + avatari,
 * gorsel, takip istegi kimligi, ust etiket. Avatar BAKAN (kutu sahibi) icin hesaplanir: `AvatarVisibility` izin vermezse
 * ve iki taraftan biri digerini engellediyse yok. Avatar bildirim satirina yazilmaz (sonradan gizlenebilir), her okumada
 * guncel gizlilikle uretilir. Hata satiri dusurmez: eksik alan null kalir.
 */
@Component
public class InboxCardEnricher {

    private static final Logger log = LoggerFactory.getLogger(InboxCardEnricher.class);
    private static final TypeReference<Map<String, String>> STRING_MAP = new TypeReference<>() { };

    private final UserRepository users;
    private final AvatarVisibility avatars;
    private final BlockService blocks;
    private final JsonMapper json;

    public InboxCardEnricher(UserRepository users, AvatarVisibility avatars, BlockService blocks, JsonMapper json) {
        this.users = users;
        this.avatars = avatars;
        this.blocks = blocks;
        this.json = json;
    }

    public List<NotificationView> enrich(Long viewerId, List<Notification> rows) {
        List<Map<String, String>> data = new ArrayList<>(rows.size());
        Set<Long> actors = new HashSet<>();
        for (Notification n : rows) {
            Map<String, String> d = parse(n.getData());
            data.add(d);
            Long actor = actorOf(d);
            if (actor != null) {
                actors.add(actor);
            }
        }
        Map<Long, User> byId = new HashMap<>();
        Set<Long> avatarOk = Set.of();
        Set<Long> related = Set.of();
        if (!actors.isEmpty()) {
            try {
                users.findAllById(actors).forEach(u -> byId.put(u.getId(), u));
                avatarOk = avatars.visibleOwners(viewerId, actors, AvatarVisibility.Field.AVATAR);
                related = blocks.hiddenFrom(viewerId);
            } catch (RuntimeException e) {
                log.warn("Bildirim gonderen bilgisi okunamadi: {}", e.toString());
            }
        }
        List<NotificationView> out = new ArrayList<>(rows.size());
        for (int i = 0; i < rows.size(); i++) {
            Notification n = rows.get(i);
            Map<String, String> d = data.get(i);
            NotifCard card = NotifCard.ofRow(n.getType(), n.getSubtype(), d);
            Long actor = actorOf(d);
            User u = actor == null ? null : byId.get(actor);
            String name = u == null || related.contains(actor) ? null : blankToNull(u.getDisplayName());
            String avatar = u == null || related.contains(actor) || !avatarOk.contains(actor) ? null
                    : blankToNull(u.getAvatarUrl());
            // Cevaplanan takip istegi artik gecersiz: kart eylemi (Onayla/Reddet) cizilmez
            boolean stale = card == NotifCard.FOLLOW_REQUEST && n.getReadAt() != null;
            String image = blankToNull(d.get("imageUrl"));
            out.add(new NotificationView(n.getId(), n.getType(), n.getTitle(), n.getBody(), n.getData(),
                    n.getReadAt() != null, n.getCreatedAt().toString(), n.getSubtype(), n.getGroupCount(),
                    n.getCollapseKey(), card == null ? null : card.name(), category(n.getType()),
                    card == null ? null : card.channel(), name, avatar, image,
                    image == null || card == null ? null : card.imageStyle(),
                    card == null || stale ? List.of() : card.actions(),
                    card == NotifCard.FOLLOW_REQUEST ? blankToNull(d.get("userId")) : null,
                    blankToNull(d.get("label"))));
        }
        return out;
    }

    /** Gonderen: takip/istek/kabul `userId`, begeni `actorId`. */
    static Long actorOf(Map<String, String> d) {
        String raw = d.get("actorId") != null ? d.get("actorId") : d.get("userId");
        if (raw == null) {
            return null;
        }
        try {
            return Long.valueOf(raw);
        } catch (NumberFormatException e) {
            return null;
        }
    }

    /** Liste suzgeci kategorisi (istemci chip adlari): events | announcements | social | system. */
    static String category(NotificationType t) {
        return switch (t) {
            case EVENT -> "events";
            case NEWS, ANNOUNCEMENT, COMMUNITY -> "announcements";
            case POST_LIKE, POST_COMMENT, COMMENT_REPLY, POST_MENTION, USER_FOLLOW, FOLLOW_REQUEST, FOLLOW_ACCEPTED -> "social";
            case MESSAGE -> "messages";
            case SYSTEM -> "system";
        };
    }

    private Map<String, String> parse(String raw) {
        if (raw == null || raw.isBlank()) {
            return Map.of();
        }
        try {
            Map<String, String> m = json.readValue(raw, STRING_MAP);
            return m == null ? Map.of() : m;
        } catch (RuntimeException e) {
            return Map.of();
        }
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s;
    }
}
