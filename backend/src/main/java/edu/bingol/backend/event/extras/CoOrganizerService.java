package edu.bingol.backend.event.extras;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.community.permissions.ClubPermission;
import edu.bingol.backend.event.EventService;
import edu.bingol.backend.event.UserEvent;
import edu.bingol.backend.event.extras.ExtrasDtos.CoOrganizerView;
import edu.bingol.backend.moderation.BlockService;
import java.util.Set;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserStatus;
import java.util.List;
import java.util.Map;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Ortak organizatorler: olusturanla ayni yonetim yetkisi (yoklama, basvuru, duyuru...). Yukseltme korumasi:
 * ortak organizator baska ortak ekleyip cikaramaz; yalniz sahip (olusturan / topluluk yetkilisi / ADMIN) yapar.
 * Ortak organizator yalnizca kendini cikarabilir (ayrilma).
 */
@Service
public class CoOrganizerService {

    static final int MAX_CO_ORGANIZERS = 5;

    private final EventService events;
    private final CoOrganizerRepository repo;
    private final CommunityService communities;
    private final BlockService blocks;
    private final NotificationService notifications;

    public CoOrganizerService(EventService events, CoOrganizerRepository repo, CommunityService communities,
                              BlockService blocks, NotificationService notifications) {
        this.events = events;
        this.repo = repo;
        this.communities = communities;
        this.blocks = blocks;
        this.notifications = notifications;
    }

    @Transactional
    public CoOrganizerView add(Actor a, Long eventId, Long targetId) {
        UserEvent e = events.load(eventId);
        requireOwnerLevel(a, e);
        if (e.getStatus() != UserEvent.Status.ACTIVE && e.getStatus() != UserEvent.Status.PENDING_REVIEW) {
            throw new ApiException(HttpStatus.CONFLICT, "EVENT_NOT_EDITABLE", "Bu etkinlik düzenlenemez.");
        }
        if (targetId.equals(e.getCreatedBy()) || targetId.equals(a.id())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "CO_ORGANIZER_TARGET_INVALID",
                    "Bu kullanıcı ortak organizatör olarak eklenemez.");
        }
        User target = communities.usersById(List.of(targetId)).get(targetId);
        if (target == null || target.getStatus() != UserStatus.ACTIVE) {
            throw new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı.");
        }
        if (blocks.isBlocked(a.id(), targetId)) {
            throw new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı.");
        }
        if (repo.existsByEventIdAndUserId(eventId, targetId)) {
            throw new ApiException(HttpStatus.CONFLICT, "CO_ORGANIZER_EXISTS", "Kullanıcı zaten ortak organizatör.");
        }
        if (repo.countByEventId(eventId) >= MAX_CO_ORGANIZERS) {
            throw new ApiException(HttpStatus.CONFLICT, "CO_ORGANIZER_LIMIT",
                    "En fazla " + MAX_CO_ORGANIZERS + " ortak organizatör eklenebilir.", String.valueOf(MAX_CO_ORGANIZERS));
        }
        CoOrganizer c = new CoOrganizer();
        c.setEventId(eventId);
        c.setUserId(targetId);
        c.setAddedBy(a.id());
        try {
            repo.saveAndFlush(c);
        } catch (DataIntegrityViolationException ex) {
            throw new ApiException(HttpStatus.CONFLICT, "CO_ORGANIZER_EXISTS", "Kullanıcı zaten ortak organizatör.");
        }
        notifications.sendTemplate(targetId, ExtrasTemplates.CO_ORGANIZER_ADDED,
                Map.of("eventId", eventId.toString()), null, e.getTitle());
        return new CoOrganizerView(targetId, target.getDisplayName(), target.getAvatarUrl(), c.getCreatedAt());
    }

    @Transactional
    public void remove(Actor a, Long eventId, Long targetId) {
        UserEvent e = events.load(eventId);
        if (a.id().equals(targetId)) {
            // Kendi ayrilmasi: yalnizca olay gorunurse (aksi halde varlik sizmasin)
            events.loadVisible(a, eventId);
        } else {
            requireOwnerLevel(a, e);
        }
        CoOrganizer c = repo.findByEventIdAndUserId(eventId, targetId).orElseThrow(() ->
                new ApiException(HttpStatus.NOT_FOUND, "CO_ORGANIZER_NOT_FOUND", "Ortak organizatör bulunamadı."));
        repo.delete(c);
    }

    @Transactional(readOnly = true)
    public List<CoOrganizerView> list(Actor a, Long eventId) {
        events.requireManager(a, events.load(eventId));
        List<CoOrganizer> rows = repo.findByEventIdOrderById(eventId);
        Map<Long, User> users = communities.usersById(rows.stream().map(CoOrganizer::getUserId).toList());
        Set<Long> hideAvatar = blocks.hiddenFrom(a.id());
        return rows.stream().map(c -> {
            User u = users.get(c.getUserId());
            return new CoOrganizerView(c.getUserId(), u == null ? "Kullanıcı" : u.getDisplayName(),
                    u == null || hideAvatar.contains(c.getUserId()) ? null : u.getAvatarUrl(), c.getCreatedAt());
        }).toList();
    }

    /** Sahip duzeyi: ADMIN, olusturan veya bagli toplulugun etkinlik yetkilisi (ortak organizator DEGIL). */
    boolean ownerLevel(Actor a, UserEvent e) {
        return a.admin() || e.getCreatedBy().equals(a.id())
                || (e.getCommunityId() != null && communities.can(a, e.getCommunityId(), ClubPermission.MANAGE_EVENTS));
    }

    private void requireOwnerLevel(Actor a, UserEvent e) {
        if (ownerLevel(a, e)) {
            return;
        }
        // Gorunmeyen etkinlik: 404; gorunen ama yetkisiz (ortak organizator dahil): 403
        events.requireManager(a, e);
        throw new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", "Bu işlem için etkinlik sahibi olmalısınız.");
    }
}
