package edu.bingol.backend.notification;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.notification.dto.NotificationDtos.NotificationPage;
import edu.bingol.backend.notification.dto.NotificationDtos.NotificationView;
import java.util.Arrays;
import java.util.List;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/** Uygulama ici bildirim kutusu: liste, okundu, silme. Baskasinin bildirimi icin 404 doner (varligi sizmaz). */
@Service
public class NotificationInboxService {

    /** Kutuda gosterilen turler: MESSAGE haric hepsi (mesajlar yalniz push ile gelir). */
    private static final List<NotificationType> ALL_TYPES = Arrays.stream(NotificationType.values())
            .filter(t -> t != NotificationType.MESSAGE).toList();

    private static boolean isMessageType(String type) {
        return type != null && "MESSAGE".equalsIgnoreCase(type.trim());
    }

    private final NotificationRepository notifications;

    public NotificationInboxService(NotificationRepository notifications) {
        this.notifications = notifications;
    }

    public NotificationPage list(Long userId, Long cursor, int size, String type, boolean unreadOnly) {
        return list(userId, cursor, size, type, unreadOnly, null);
    }

    public NotificationPage list(Long userId, Long cursor, int size, String type, boolean unreadOnly, String category) {
        String selected = category == null || category.isBlank() ? null : category.trim().toUpperCase(java.util.Locale.ROOT);
        if (selected != null && !List.of("EVENT", "ANNOUNCEMENT", "ACADEMIC", "POLL", "SOCIAL", "SYSTEM").contains(selected)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz bildirim kategorisi.");
        }
        int s = CursorPage.clampSize(size);
        if (isMessageType(type)) {
            // Sohbet mesaji kutuda yok (yalniz push): gecerli tur ama bos liste
            return new NotificationPage(List.of(), null, notifications.countUnreadInbox(userId));
        }
        List<Notification> rows = selected == null
                ? notifications.pageFiltered(userId, cursor, types(type), unreadOnly, PageRequest.of(0, s + 1))
                : notifications.pageCategory(userId, cursor, types(type), unreadOnly, selected, PageRequest.of(0, s + 1));
        CursorPage<NotificationView> page = CursorPage.of(rows, s, Notification::getId, NotificationView::of);
        return new NotificationPage(project(userId, page.items()), page.nextCursor(), notifications.countUnreadInbox(userId));
    }

    // --- istek anı projeksiyonu: aktor avatari (gizlilik suzgeci) + kaynak adi (kulup); kalici data'ya yazilmaz ---

    private edu.bingol.backend.user.UserRepository users;
    private edu.bingol.backend.profile.privacy.AvatarVisibility avatarVisibility;
    private edu.bingol.backend.moderation.BlockService blocks;
    private edu.bingol.backend.community.CommunityRepository communities;
    private edu.bingol.backend.event.UserEventRepository events;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setProjection(edu.bingol.backend.user.UserRepository users,
                       edu.bingol.backend.profile.privacy.AvatarVisibility avatarVisibility,
                       edu.bingol.backend.moderation.BlockService blocks,
                       edu.bingol.backend.community.CommunityRepository communities,
                       edu.bingol.backend.event.UserEventRepository events) {
        this.users = users;
        this.avatarVisibility = avatarVisibility;
        this.blocks = blocks;
        this.communities = communities;
        this.events = events;
    }

    private static final java.util.Set<NotificationType> ACTOR_TYPES = java.util.Set.of(NotificationType.POST_LIKE,
            NotificationType.USER_FOLLOW, NotificationType.FOLLOW_REQUEST, NotificationType.FOLLOW_ACCEPTED);

    /** Hata satiri bozmaz: projeksiyon basarisizsa alanlar bos kalir. */
    private List<NotificationView> project(Long viewerId, List<NotificationView> items) {
        if (items.isEmpty() || users == null) {
            return items;
        }
        try {
            java.util.Map<Long, java.util.Map<String, String>> parsed = new java.util.HashMap<>();
            java.util.Set<Long> actorIds = new java.util.HashSet<>();
            java.util.Set<Long> communityIds = new java.util.HashSet<>();
            java.util.Set<Long> eventIds = new java.util.HashSet<>();
            for (NotificationView v : items) {
                java.util.Map<String, String> d = NotificationPresentation.data(v.data());
                parsed.put(v.id(), d);
                if (ACTOR_TYPES.contains(v.type())) {
                    Long actor = longOf(v.type() == NotificationType.POST_LIKE ? d.get("actorId") : d.get("userId"));
                    if (actor != null) actorIds.add(actor);
                }
                Long c = longOf(d.get("communityId"));
                if (c != null) communityIds.add(c);
                else {
                    Long e = longOf(d.get("eventId"));
                    if (e != null) eventIds.add(e);
                }
            }
            java.util.Map<Long, String> avatars = new java.util.HashMap<>();
            if (!actorIds.isEmpty() && avatarVisibility != null) {
                java.util.Set<Long> visible = avatarVisibility.visibleOwners(viewerId, actorIds,
                        edu.bingol.backend.profile.privacy.AvatarVisibility.Field.AVATAR);
                java.util.Set<Long> hidden = blocks == null ? java.util.Set.of() : blocks.hiddenFrom(viewerId);
                users.findAllById(actorIds).forEach(u -> {
                    if (u.getAvatarUrl() != null && !u.getAvatarUrl().isBlank() && visible.contains(u.getId())
                            && !hidden.contains(u.getId())) {
                        avatars.put(u.getId(), u.getAvatarUrl());
                    }
                });
            }
            java.util.Map<Long, Long> eventCommunity = new java.util.HashMap<>();
            if (!eventIds.isEmpty() && events != null) {
                events.findAllById(eventIds).forEach(e -> {
                    if (e.getCommunityId() != null) {
                        eventCommunity.put(e.getId(), e.getCommunityId());
                        communityIds.add(e.getCommunityId());
                    }
                });
            }
            java.util.Map<Long, String> names = new java.util.HashMap<>();
            if (!communityIds.isEmpty() && communities != null) {
                communities.findAllById(communityIds).forEach(c -> names.put(c.getId(), c.getName()));
            }
            List<NotificationView> out = new java.util.ArrayList<>(items.size());
            for (NotificationView v : items) {
                java.util.Map<String, String> d = parsed.get(v.id());
                String avatar = null;
                if (ACTOR_TYPES.contains(v.type())) {
                    Long actor = longOf(v.type() == NotificationType.POST_LIKE ? d.get("actorId") : d.get("userId"));
                    avatar = actor == null ? null : avatars.get(actor);
                }
                Long c = longOf(d.get("communityId"));
                if (c == null) {
                    Long e = longOf(d.get("eventId"));
                    c = e == null ? null : eventCommunity.get(e);
                }
                String source = c == null ? null : names.get(c);
                out.add(avatar == null && source == null ? v : v.withProjection(avatar, source));
            }
            return out;
        } catch (RuntimeException e) {
            return items;
        }
    }

    private static Long longOf(String s) {
        if (s == null || s.isBlank() || s.length() > 18) return null;
        try {
            return Long.valueOf(s.trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    public long unreadCount(Long userId) {
        return notifications.countUnreadInbox(userId);
    }

    public void markRead(Long userId, List<Long> ids, boolean all) {
        if (all) {
            notifications.markAllRead(userId);
        } else if (ids != null && !ids.isEmpty()) {
            notifications.markRead(userId, ids);
        } else {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "ids veya all gerekli.");
        }
    }

    public void markOneRead(Long userId, Long id) {
        requireOwned(userId, id);
        notifications.markRead(userId, List.of(id));
    }

    public void delete(Long userId, Long id) {
        if (notifications.deleteOne(userId, id) == 0) {
            throw notFound();
        }
    }

    /** type verilirse yalnizca o tur; readOnly=true ise yalnizca okunmuslar. */
    public int deleteAll(Long userId, String type, boolean readOnly) {
        if (isMessageType(type)) {
            return 0;
        }
        return notifications.deleteForUser(userId, types(type), readOnly);
    }

    private void requireOwned(Long userId, Long id) {
        notifications.findByIdAndUserId(id, userId).orElseThrow(NotificationInboxService::notFound);
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "NOTIFICATION_NOT_FOUND", "Bildirim bulunamadı.");
    }

    private static List<NotificationType> types(String type) {
        if (type == null || type.isBlank()) {
            return ALL_TYPES;
        }
        try {
            return List.of(NotificationType.valueOf(type.trim().toUpperCase(java.util.Locale.ROOT)));
        } catch (IllegalArgumentException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz bildirim türü.");
        }
    }
}
