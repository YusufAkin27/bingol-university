package edu.bingol.backend.messaging.room.dept;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.messaging.room.RoomConversations;
import edu.bingol.backend.messaging.room.RoomConversations.RoomInfo;
import edu.bingol.backend.messaging.room.RoomKind;
import edu.bingol.backend.unitnews.UnitKeys;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.time.Instant;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Bolum sohbet gruplari (RoomConversations, DEPARTMENT, department_chat_room.id). Her bolumun tek odasi vardir;
 * kullanici kendi profil bolumunun odasina ISTERSE katilir (zorunlu degil), istedigi an ayrilir. Oda ilk katilimda
 * tembel kurulur; kurucu/grup yoneticisi sistem yoneticisidir (ADMIN; moderasyon: DepartmentRoomModerators).
 * Uyeler birbirini mevcut sikayet akisiyle (USER / MESSAGE / CONVERSATION) bildirir.
 */
@Service
public class DepartmentChatService {

    private final RoomConversations rooms;
    private final DepartmentChatRoomRepository depts;
    private final UserRepository users;

    public DepartmentChatService(RoomConversations rooms, DepartmentChatRoomRepository depts, UserRepository users) {
        this.rooms = rooms;
        this.depts = depts;
        this.users = users;
    }

    /**
     * available=false: profilde bolum yok (istemci girisi gostermez). conversationId yalniz uyeyken dolu.
     * memberCount: oda yoksa 0.
     */
    public record DepartmentChatView(boolean available, String departmentName, boolean closed, boolean joined,
                                     long memberCount, Long conversationId) {}

    /** Yonetici listesi satiri. */
    public record AdminRoomView(Long id, String name, Long conversationId, boolean closed, long memberCount) {}

    @Transactional(readOnly = true)
    public DepartmentChatView get(Long userId) {
        User u = requireUser(userId);
        String key = keyOf(u);
        if (key == null) {
            return new DepartmentChatView(false, null, false, false, 0, null);
        }
        DepartmentChatRoom room = depts.findByDeptKey(key).orElse(null);
        RoomInfo info = room == null ? null : rooms.find(RoomKind.DEPARTMENT, room.getId()).orElse(null);
        if (info == null) {
            return new DepartmentChatView(true, u.getDepartment(), false, false, 0, null);
        }
        return view(u, room, info);
    }

    /** Kullanici kendi bolum odasina katilir (zaten uyeyse idempotent). Oda yoksa kurulur. */
    @Transactional
    public DepartmentChatView join(Long userId) {
        User u = requireUser(userId);
        String key = keyOf(u);
        if (key == null) {
            throw new ApiException(HttpStatus.CONFLICT, "DEPARTMENT_REQUIRED",
                    "Bölüm grubuna katılmak için profilinde bölüm seçmelisin.");
        }
        DepartmentChatRoom room = ensureRecord(key, u.getDepartment());
        RoomInfo info = rooms.find(RoomKind.DEPARTMENT, room.getId()).orElse(null);
        if (info == null) {
            rooms.ensureRoom(RoomKind.DEPARTMENT, room.getId(), room.getName(), ownerOf(userId));
            info = rooms.find(RoomKind.DEPARTMENT, room.getId()).orElseThrow(DepartmentChatService::notFound);
        }
        if (info.closed()) {
            throw new ApiException(HttpStatus.CONFLICT, "CHAT_ROOM_CLOSED", "Sohbet odası kapalı.");
        }
        if (!rooms.addMember(RoomKind.DEPARTMENT, room.getId(), userId)) {
            throw notFound(); // hesap uygun degil (askida/dogrulanmamis)
        }
        return view(u, room, info);
    }

    /** Odadan ayrilir (uye degilse no-op). Kullanicinin SU ANKI bolum odasi degil, uye oldugu bolum odasi da olabilir. */
    @Transactional
    public void leave(Long userId) {
        User u = requireUser(userId);
        String key = keyOf(u);
        if (key == null) {
            return;
        }
        depts.findByDeptKey(key).ifPresent(r -> rooms.removeMember(RoomKind.DEPARTMENT, r.getId(), userId));
    }

    // ---- yonetici ----

    @Transactional(readOnly = true)
    public List<AdminRoomView> adminList() {
        return depts.findAllByOrderByNameAsc(org.springframework.data.domain.PageRequest.of(0, 500)).stream()
                .map(r -> {
                    RoomInfo i = rooms.find(RoomKind.DEPARTMENT, r.getId()).orElse(null);
                    return new AdminRoomView(r.getId(), r.getName(), i == null ? null : i.conversationId(),
                            i != null && i.closed(), i == null || i.closed() ? 0 : rooms.memberCount(RoomKind.DEPARTMENT, r.getId()));
                }).toList();
    }

    /** Odayi kapatir (herkes cikar, gecmis saklanir) ya da yeniden acar (eski uyeler otomatik donmez; kendileri katilir). */
    @Transactional
    public AdminRoomView adminSetClosed(Long id, boolean closed) {
        DepartmentChatRoom r = depts.findById(id).orElseThrow(DepartmentChatService::notFound);
        if (rooms.find(RoomKind.DEPARTMENT, id).isEmpty()) {
            throw notFound();
        }
        if (closed) {
            rooms.closeRoom(RoomKind.DEPARTMENT, id);
        } else {
            rooms.openRoom(RoomKind.DEPARTMENT, id, List.of());
        }
        RoomInfo i = rooms.find(RoomKind.DEPARTMENT, id).orElseThrow(DepartmentChatService::notFound);
        return new AdminRoomView(r.getId(), r.getName(), i.conversationId(), i.closed(),
                i.closed() ? 0 : rooms.memberCount(RoomKind.DEPARTMENT, id));
    }

    // ---- ic yardimcilar ----

    private DepartmentChatRoom ensureRecord(String key, String name) {
        String n = name.trim();
        depts.insertIfAbsent(key, n.length() <= 120 ? n : n.substring(0, 120), Instant.now());
        return depts.findByDeptKey(key).orElseThrow(DepartmentChatService::notFound);
    }

    /** Oda sahibi: ilk aktif sistem yoneticisi (grup yoneticisi); hic yoksa ilk katilan kullanici. */
    private Long ownerOf(Long fallbackUserId) {
        return users.findAllAdmins().stream().filter(a -> a.getStatus() == UserStatus.ACTIVE).map(User::getId)
                .findFirst().orElse(fallbackUserId);
    }

    private DepartmentChatView view(User u, DepartmentChatRoom room, RoomInfo info) {
        boolean joined = !info.closed() && rooms.isMember(RoomKind.DEPARTMENT, room.getId(), u.getId());
        return new DepartmentChatView(true, u.getDepartment(), info.closed(), joined,
                info.closed() ? 0 : rooms.memberCount(RoomKind.DEPARTMENT, room.getId()),
                joined ? info.conversationId() : null);
    }

    private static String keyOf(User u) {
        String d = u.getDepartment();
        return d == null || d.isBlank() ? null : UnitKeys.deptKey(d);
    }

    private User requireUser(Long id) {
        return users.findById(id).orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND",
                "Kullanıcı bulunamadı."));
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "CHAT_ROOM_NOT_FOUND", "Sohbet odası bulunamadı.");
    }
}
