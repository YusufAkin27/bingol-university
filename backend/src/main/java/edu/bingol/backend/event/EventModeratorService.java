package edu.bingol.backend.event;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.event.EventModerator.Perm;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserStatus;
import java.time.Instant;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Etkinlik moderatorleri ve yoklama acma anahtari. Yonetim (ekleme/cikarma/yetki, yoklamayi acma-kapama) YALNIZ
 * etkinlik sahibine (ve sistem yoneticisine) aittir; moderator bunlari yapamaz. Moderator yetkisi, kulup uyeligi
 * surdukce gecerlidir (uyelikten cikan / silinen kullanicinin yetkisi duser).
 */
@Service
public class EventModeratorService {

    private static final Logger log = LoggerFactory.getLogger(EventModeratorService.class);
    static final int MAX_MODERATORS = 20;

    public record ModeratorView(Long userId, String displayName, List<String> permissions, Instant createdAt) {
    }

    public record MyPermissions(boolean owner, boolean attendanceOpen, List<String> permissions) {
    }

    private final EventService events;
    private final UserEventRepository eventRepo;
    private final EventModeratorRepository mods;
    private final CommunityService communities;
    private edu.bingol.backend.notification.NotificationService notifications;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setNotifications(edu.bingol.backend.notification.NotificationService notifications) {
        this.notifications = notifications;
    }

    public EventModeratorService(EventService events, UserEventRepository eventRepo, EventModeratorRepository mods,
                                 CommunityService communities) {
        this.events = events;
        this.eventRepo = eventRepo;
        this.mods = mods;
        this.communities = communities;
    }

    /** Moderator gecerli mi ve bu yetkiye sahip mi (kulup uyeligi canli denetlenir). */
    public boolean has(UserEvent e, Long userId, Perm p) {
        EventModerator m = mods.findByEventIdAndUserId(e.getId(), userId).orElse(null);
        if (m == null || !m.has(p)) {
            return false;
        }
        Long cid = e.getCommunityId();
        return cid == null || communities.roleOf(cid, userId).isPresent();
    }

    /** Kisi bu etkinlikte (gecerli) moderator mi; yetkisi eksikse sahip-ozel/yetkisiz uc 404 yerine 403 alsin. */
    public boolean isModerator(UserEvent e, Long userId) {
        return mods.findByEventIdAndUserId(e.getId(), userId).isPresent();
    }

    @Transactional(readOnly = true)
    public List<ModeratorView> list(Actor a, Long eventId) {
        UserEvent e = ownerOnly(a, eventId);
        List<EventModerator> rows = mods.findByEventIdOrderByCreatedAtAsc(e.getId());
        Map<Long, User> users = communities.usersById(rows.stream().map(EventModerator::getUserId).toList());
        List<ModeratorView> out = new ArrayList<>();
        for (EventModerator m : rows) {
            User u = users.get(m.getUserId());
            out.add(new ModeratorView(m.getUserId(), u == null || u.getDisplayName() == null ? "Kullanıcı" : u.getDisplayName(),
                    names(m.getPermissions()), m.getCreatedAt()));
        }
        return out;
    }

    /** Moderator ekler ya da yetkilerini degistirir (idempotent). Yalniz sahip. */
    @Transactional
    public ModeratorView put(Actor a, Long eventId, Long userId, List<String> permissions) {
        UserEvent e = ownerOnly(a, eventId);
        if (e.getCommunityId() == null) {
            throw new ApiException(HttpStatus.CONFLICT, "MODERATOR_NOT_MEMBER", "Moderatör yalnızca kulüp üyeleri arasından seçilir.");
        }
        int bits = bits(permissions);
        User u = communities.usersById(List.of(userId)).get(userId);
        if (u == null || u.getStatus() != UserStatus.ACTIVE) {
            throw new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı.");
        }
        if (communities.roleOf(e.getCommunityId(), userId).isEmpty()) {
            throw new ApiException(HttpStatus.CONFLICT, "MODERATOR_NOT_MEMBER", "Moderatör yalnızca kulüp üyeleri arasından seçilir.");
        }
        EventModerator m = mods.findByEventIdAndUserId(eventId, userId).orElse(null);
        boolean isNew = m == null;
        if (m == null) {
            if (mods.findByEventIdOrderByCreatedAtAsc(eventId).size() >= MAX_MODERATORS) {
                throw new ApiException(HttpStatus.CONFLICT, "MODERATOR_LIMIT", "En fazla " + MAX_MODERATORS + " moderatör eklenebilir.",
                        String.valueOf(MAX_MODERATORS));
            }
            m = new EventModerator();
            m.setEventId(eventId);
            m.setUserId(userId);
            m.setAddedBy(a.id());
        }
        m.setPermissions(bits);
        m.setUpdatedAt(Instant.now());
        mods.save(m);
        // Denetim izi: kim kime hangi yetkiyi verdi
        log.info("event-moderator event={} user={} perms={} by={}", eventId, userId, bits, a.id());
        if (isNew) {
            notifyUser(userId, "notif.event.moderatorAdded", e);
        }
        return new ModeratorView(userId, u.getDisplayName() == null ? "Kullanıcı" : u.getDisplayName(), names(bits), m.getCreatedAt());
    }

    @Transactional
    public void remove(Actor a, Long eventId, Long userId) {
        UserEvent e = ownerOnly(a, eventId);
        mods.findByEventIdAndUserId(e.getId(), userId).ifPresent(m -> {
            mods.delete(m);
            log.info("event-moderator-removed event={} user={} by={}", eventId, userId, a.id());
            notifyUser(userId, "notif.event.moderatorRemoved", e);
        });
    }

    /** Yoklamayi acar/kapatir. Yalniz sahip; yayinda olmayan etkinlikte 409. */
    @Transactional
    public MyPermissions setAttendanceOpen(Actor a, Long eventId, boolean open) {
        UserEvent e = ownerOnly(a, eventId);
        if (e.getStatus() != UserEvent.Status.ACTIVE) {
            throw new ApiException(HttpStatus.CONFLICT, "EVENT_NOT_OPEN", "Etkinlik yayında değil.");
        }
        e.setAttendanceOpen(open);
        eventRepo.save(e);
        return new MyPermissions(true, open, names(allBits()));
    }

    /** Cagiranin bu etkinlikteki rolu: sahip (tum yetkiler) ya da moderator (verilen yetkiler). */
    @Transactional(readOnly = true)
    public MyPermissions me(Actor a, Long eventId) {
        UserEvent e = events.loadVisible(a, eventId);
        if (events.canManage(a, e)) {
            return new MyPermissions(true, e.isAttendanceOpen(), names(allBits()));
        }
        EventModerator m = mods.findByEventIdAndUserId(eventId, a.id()).orElse(null);
        List<String> perms = List.of();
        if (m != null && (e.getCommunityId() == null || communities.roleOf(e.getCommunityId(), a.id()).isPresent())) {
            perms = names(m.getPermissions());
        }
        // Katilimci/moderator icin "yoklama acik" = sahip anahtari VEYA etkinlik yoklama penceresi (QR gosterilebilir);
        // sahip yanit(true) anahtarin gercek degerini gosterir (anahtar arayuzu).
        boolean effective = e.isAttendanceOpen() || AttendanceService.inWindow(e, java.time.Instant.now());
        return new MyPermissions(false, effective, perms);
    }

    private void notifyUser(Long userId, String key, UserEvent e) {
        if (notifications == null) {
            return;
        }
        try {
            notifications.sendTemplated(userId, edu.bingol.backend.notification.NotificationType.EVENT,
                    edu.bingol.backend.notification.NotificationSubtype.EVENT_UPDATE, key,
                    Map.of("eventId", e.getId().toString()), e.getTitle());
        } catch (RuntimeException ex) {
            log.warn("Moderator bildirimi gonderilemedi: {}", ex.toString());
        }
    }

    /** KVKK dislama: kullanicinin moderator oldugu etkinlikler ve yetkileri. */
    public List<Map<String, Object>> exportFor(Long userId) {
        List<Map<String, Object>> out = new ArrayList<>();
        for (EventModerator m : mods.findByUserId(userId)) {
            out.add(Map.of("eventId", m.getEventId(), "permissions", names(m.getPermissions()), "since", m.getCreatedAt().toString()));
        }
        return out;
    }

    /** Sahip-ozel islem: moderator 403 EVENT_PERMISSION_DENIED alir, yabanci kullanici requireManager kuralini (404/403). */
    private UserEvent ownerOnly(Actor a, Long eventId) {
        UserEvent e = events.load(eventId);
        if (!events.canManage(a, e) && isModerator(e, a.id())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "EVENT_PERMISSION_DENIED", "Bu işlem yalnızca etkinlik sahibine aittir.");
        }
        return events.requireManager(a, e);
    }

    /** Hesap silinince moderatorluk satirlari temizlenir. */
    @Transactional
    public void purgeUser(Long userId) {
        mods.deleteByUser(userId);
    }

    static int allBits() {
        int b = 0;
        for (Perm p : Perm.values()) {
            b |= p.bit;
        }
        return b;
    }

    static List<String> names(int bits) {
        List<String> out = new ArrayList<>();
        for (Perm p : Perm.values()) {
            if ((bits & p.bit) != 0) {
                out.add(p.name());
            }
        }
        return out;
    }

    static int bits(List<String> names) {
        Set<Perm> set = EnumSet.noneOf(Perm.class);
        if (names != null) {
            for (String n : names) {
                try {
                    set.add(Perm.valueOf(n));
                } catch (IllegalArgumentException | NullPointerException ex) {
                    // Sahip-ozel yetkiler (kapatma, iptal, moderator yonetimi...) ve bilinmeyenler burada reddedilir.
                    throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz moderatör yetkisi.");
                }
            }
        }
        int b = 0;
        for (Perm p : set) {
            b |= p.bit;
        }
        return b;
    }
}
