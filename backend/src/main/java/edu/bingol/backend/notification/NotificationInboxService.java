package edu.bingol.backend.notification;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.notification.dto.NotificationDtos.NotificationPage;
import edu.bingol.backend.notification.dto.NotificationDtos.NotificationView;
import edu.bingol.backend.notification.dto.NotificationDtos.UnreadCounts;
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
        return list(userId, cursor, size, type, unreadOnly, category, null, null);
    }

    public NotificationPage list(Long userId, Long cursor, int size, String type, boolean unreadOnly, String category,
                                 String scope) {
        return list(userId, cursor, size, type, unreadOnly, category, scope, null);
    }

    /**
     * scope: SOCIAL (Hareketler/kalp) | INFORMATION (Bildirimler/zil, sosyal ve sohbet icermez) | bos = eski davranis
     * (tum kutu). Dondurulen unreadCount eski toplamdir; merkez sayaclari {@link #unreadCounts}.
     */
    public NotificationPage list(Long userId, Long cursor, int size, String type, boolean unreadOnly, String category,
                                 String scope, String kind) {
        Boolean social = parseScope(scope);
        // category: tek deger ya da virgullu liste (ornek "ANNOUNCEMENT,ACADEMIC,POLL" = Duyurular cipi)
        List<String> selected = parseCategories(category);
        String kindUp = kind == null || kind.isBlank() ? null : kind.trim().toUpperCase(java.util.Locale.ROOT);
        if (kindUp != null && !List.of("LIKES", "COMMENTS", "FOLLOWS").contains(kindUp)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz bildirim alt süzgeci.");
        }
        int s = CursorPage.clampSize(size);
        if (isMessageType(type)) {
            // Sohbet mesaji kutuda yok (yalniz push): gecerli tur ama bos liste
            return new NotificationPage(List.of(), null, notifications.countUnreadInbox(userId));
        }
        List<Notification> rows;
        if (social != null) {
            // Kapsam sorgusu (tek kaynak); kategori verilmisse kapsamla celisiyorsa bos liste.
            rows = selected == null
                    ? notifications.pageScope(userId, cursor, types(type), unreadOnly, social, kindUp == null ? "ALL" : kindUp, PageRequest.of(0, s + 1))
                    : scopedCategory(userId, cursor, type, unreadOnly, selected, social, s);
        } else {
            rows = selected == null
                    ? notifications.pageFiltered(userId, cursor, types(type), unreadOnly, PageRequest.of(0, s + 1))
                    : notifications.pageCategory(userId, cursor, types(type), unreadOnly, selected, PageRequest.of(0, s + 1));
        }
        CursorPage<NotificationView> page = CursorPage.of(rows, s, Notification::getId, NotificationView::of);
        return new NotificationPage(project(userId, page.items()), page.nextCursor(), notifications.countUnreadInbox(userId));
    }

    private List<Notification> scopedCategory(Long userId, Long cursor, String type, boolean unreadOnly,
                                              List<String> categories, boolean social, int s) {
        // SOCIAL kategorisi yalniz SOCIAL kapsaminda, diger kategoriler yalniz INFORMATION kapsaminda anlamlidir.
        List<String> ok = categories.stream().filter(c -> "SOCIAL".equals(c) == social).toList();
        if (ok.isEmpty()) {
            return List.of();
        }
        return notifications.pageCategory(userId, cursor, types(type), unreadOnly, ok, PageRequest.of(0, s + 1));
    }

    private static final List<String> CATEGORIES = List.of("EVENT", "ANNOUNCEMENT", "ACADEMIC", "POLL", "SOCIAL", "SYSTEM");

    /** Bos -> null (suzgec yok); gecersiz deger 400. */
    static List<String> parseCategories(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        List<String> out = new java.util.ArrayList<>();
        for (String part : raw.split(",")) {
            String c = part.trim().toUpperCase(java.util.Locale.ROOT);
            if (c.isEmpty()) {
                continue;
            }
            if (!CATEGORIES.contains(c)) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz bildirim kategorisi.");
            }
            out.add(c);
        }
        return out.isEmpty() ? null : out;
    }

    /** SOCIAL -> true, INFORMATION -> false, bos -> null; baska deger 400. */
    static Boolean parseScope(String scope) {
        if (scope == null || scope.isBlank()) {
            return null;
        }
        return switch (scope.trim().toUpperCase(java.util.Locale.ROOT)) {
            case "SOCIAL" -> Boolean.TRUE;
            case "INFORMATION" -> Boolean.FALSE;
            default -> throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz bildirim kapsamı.");
        };
    }

    // --- istek anı projeksiyonu: aktor avatari (gizlilik suzgeci) + kaynak adi (kulup); kalici data'ya yazilmaz ---

    private edu.bingol.backend.user.UserRepository users;
    private edu.bingol.backend.profile.privacy.AvatarVisibility avatarVisibility;
    private edu.bingol.backend.moderation.BlockService blocks;
    private edu.bingol.backend.community.CommunityRepository communities;
    private edu.bingol.backend.event.UserEventRepository events;
    private edu.bingol.backend.post.follow.FollowRequestService followRequests;
    private edu.bingol.backend.community.PendingMembershipCounter membershipCounter;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setPending(edu.bingol.backend.post.follow.FollowRequestService followRequests,
                    edu.bingol.backend.community.PendingMembershipCounter membershipCounter) {
        this.followRequests = followRequests;
        this.membershipCounter = membershipCounter;
    }

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
            NotificationType.POST_MENTION, NotificationType.USER_FOLLOW, NotificationType.FOLLOW_REQUEST, NotificationType.FOLLOW_ACCEPTED);

    /** Avatari gosterilen aktorlu bildirim: sosyal turler + kulup katilma istegi (basvuran). */
    private static boolean hasActor(NotificationView v) {
        return ACTOR_TYPES.contains(v.type())
                || (v.type() == NotificationType.COMMUNITY && "COMMUNITY_JOIN".equals(v.subtype()));
    }

    private static String actorKey(NotificationView v, java.util.Map<String, String> d) {
        String k = v.type() == NotificationType.POST_LIKE ? d.get("actorId") : d.get("userId");
        return k != null ? k : d.get("actorId");
    }

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
                if (hasActor(v)) {
                    Long actor = longOf(actorKey(v, d));
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
            java.util.Map<Long, String> eventStates = new java.util.HashMap<>();
            java.time.Instant nowAt = java.time.Instant.now();
            if (!eventIds.isEmpty() && events != null) {
                events.findAllById(eventIds).forEach(e -> {
                    eventStates.put(e.getId(), edu.bingol.backend.event.EventLiveness.state(e, nowAt));
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
                if (hasActor(v)) {
                    Long actor = longOf(actorKey(v, d));
                    avatar = actor == null ? null : avatars.get(actor);
                }
                Long c = longOf(d.get("communityId"));
                if (c == null) {
                    Long e = longOf(d.get("eventId"));
                    c = e == null ? null : eventCommunity.get(e);
                }
                String source = c == null ? null : names.get(c);
                NotificationView pv = avatar == null && source == null ? v : v.withProjection(avatar, source);
                Long evId = v.type() == NotificationType.EVENT ? longOf(d.get("eventId")) : null;
                if (evId != null) {
                    pv = pv.withEventState(eventStates.getOrDefault(evId, "UNAVAILABLE"));
                }
                out.add(pv);
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

    /**
     * Iki merkezin sayaclari (sunucuda, bagimsiz). Bekleyen takip/uyelik istekleri islem gerektirdigi icin ayri alanlarda
     * doner; mobil kalp noktasi = social + bekleyen istekler. Alt sorgu hatasi sayaci bozmaz (0).
     */
    public UnreadCounts unreadCounts(Long userId) {
        long social = notifications.countUnreadScope(userId, true);
        long info = notifications.countUnreadScope(userId, false);
        long fr = 0;
        long mr = 0;
        try {
            if (followRequests != null) fr = followRequests.count(userId);
        } catch (RuntimeException ignored) {
            // sayac hafif kalir
        }
        try {
            if (membershipCounter != null) mr = membershipCounter.countFor(userId);
        } catch (RuntimeException ignored) {
            // sayac hafif kalir
        }
        return new UnreadCounts(social, info, social + info, fr, mr);
    }

    public void markRead(Long userId, List<Long> ids, boolean all) {
        markRead(userId, ids, all, null);
    }

    /** all=true + scope: yalniz o merkezin bildirimleri okundu olur; scope bos = tum kutu (eski davranis). */
    public void markRead(Long userId, List<Long> ids, boolean all, String scope) {
        if (all) {
            Boolean social = parseScope(scope);
            if (social == null) {
                notifications.markAllRead(userId);
            } else {
                notifications.markAllReadScopeAt(userId, social, java.time.Instant.now());
            }
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
