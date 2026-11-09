package edu.bingol.backend.messaging.room.dept;

import edu.bingol.backend.catalog.CatalogService;
import edu.bingol.backend.catalog.CatalogService.Department;
import edu.bingol.backend.catalog.CatalogService.Faculty;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.messaging.ConversationService;
import edu.bingol.backend.messaging.dto.MessagingDtos.ConversationView;
import edu.bingol.backend.messaging.room.RoomConversations;
import edu.bingol.backend.messaging.room.RoomConversations.RoomInfo;
import edu.bingol.backend.messaging.room.RoomKind;
import edu.bingol.backend.unitnews.UnitKeys;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.text.Normalizer;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Bolum sohbet gruplari (RoomConversations, DEPARTMENT, department_chat_room.id). Her bolumun tek odasi vardir;
 * kullanici HERHANGI bir bolumun kanalina ISTERSE katilir (zorunlu degil; v2), istedigi an ayrilir; bolum degisse de
 * secilen kanallar kalir. Eski "kendi bolumun" uclari (get/join/leave) geriye uyum icin durur. Oda ilk katilimda
 * tembel kurulur; kurucu/grup yoneticisi sistem yoneticisidir (ADMIN; moderasyon: DepartmentRoomModerators).
 * Uyeler birbirini mevcut sikayet akisiyle (USER / MESSAGE / CONVERSATION) bildirir.
 */
@Service
public class DepartmentChatService {

    private final RoomConversations rooms;
    private final DepartmentChatRoomRepository depts;
    private final UserRepository users;
    private final ConversationService conversations;
    /** Katalog bolumleri (kanal kimligi = katalog bolum id'si; ayni oda anahtarina dusenler tek kanal). */
    private final List<Channel> channels;
    private final Map<String, Channel> byId;

    public DepartmentChatService(RoomConversations rooms, DepartmentChatRoomRepository depts, UserRepository users,
                                 CatalogService catalog, ConversationService conversations) {
        this.rooms = rooms;
        this.depts = depts;
        this.users = users;
        this.conversations = conversations;
        List<Channel> list = new ArrayList<>();
        Map<String, Channel> ids = new HashMap<>();
        Set<String> seenKeys = new HashSet<>();
        for (Faculty f : catalog.catalog().faculties()) {
            for (Department d : f.departments()) {
                String key = UnitKeys.deptKey(d.name());
                if (key == null || ids.containsKey(d.id()) || !seenKeys.add(key)) {
                    continue;
                }
                Channel c = new Channel(d.id(), key, d, f, fold(d.name()) + " " + fold(d.nameEn()) + " "
                        + fold(d.nameAr()) + " " + fold(f.name()));
                list.add(c);
                ids.put(d.id(), c);
            }
        }
        this.channels = List.copyOf(list);
        this.byId = Map.copyOf(ids);
    }

    private record Channel(String id, String roomKey, Department dept, Faculty faculty, String haystack) {}

    /**
     * Bolum kanali satiri (tum bolumler listesi). `key` katalog bolum kimligidir (join/leave yolu); `own`: kullanicinin
     * profil bolumu; conversationId yalniz uyeyken dolu.
     */
    public record DepartmentChannel(String key, String name, String nameEn, String nameAr, String faculty,
                                    String facultyEn, String facultyAr, boolean own, boolean joined, boolean closed,
                                    long memberCount, Long conversationId) {}

    /** `ownKey`: kullanicinin profil bolumunun kanal anahtari (katalogda yoksa null). */
    public record DepartmentChannelPage(List<DepartmentChannel> items, int page, int size, long total, String ownKey) {}

    /** Katildigim kanal: sohbet listesiyle ayni ConversationView (okunmamis, son mesaj dahil). */
    public record MyChannel(String key, String name, String nameEn, String nameAr, String faculty, boolean own,
                            ConversationView conversation) {}

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

    // ---- bolum kanallari (v2): her ogrenci herhangi bir bolume katilip cikabilir ----

    /** Tum bolumler (katalog sirasi); `q` bolum/fakulte adinda (tr/en/ar) aksan duyarsiz suzer; sayfali (en cok 200). */
    @Transactional(readOnly = true)
    public DepartmentChannelPage listChannels(Long userId, String q, int page, int size) {
        User u = requireUser(userId);
        String ownKey = keyOf(u);
        String needle = q == null ? "" : fold(q.length() > 80 ? q.substring(0, 80) : q).trim();
        int sz = Math.max(1, Math.min(size, 200));
        int pg = Math.max(0, page);
        Map<String, DepartmentChatStats> stats = statsByKey(userId);
        List<Channel> hits = needle.isEmpty() ? channels
                : channels.stream().filter(c -> c.haystack().contains(needle)).toList();
        int from = (int) Math.min((long) pg * sz, hits.size());
        List<DepartmentChannel> items = hits.subList(from, Math.min(hits.size(), from + sz)).stream()
                .map(c -> channelView(c, stats.get(c.roomKey()), ownKey)).toList();
        String ownId = channels.stream().filter(c -> c.roomKey().equals(ownKey)).map(Channel::id).findFirst()
                .orElse(null);
        return new DepartmentChannelPage(items, pg, sz, hits.size(), ownId);
    }

    /** Katildigim kanallar (acik odalar), ConversationView ile; en cok 100. */
    @Transactional(readOnly = true)
    public List<MyChannel> myChannels(Long userId) {
        User u = requireUser(userId);
        String ownKey = keyOf(u);
        Map<String, DepartmentChatStats> stats = statsByKey(userId);
        List<MyChannel> out = new ArrayList<>();
        for (Channel c : channels) {
            DepartmentChatStats s = stats.get(c.roomKey());
            if (s == null || !Boolean.TRUE.equals(s.getJoined()) || Boolean.TRUE.equals(s.getClosed())
                    || s.getConversationId() == null) {
                continue;
            }
            try {
                out.add(new MyChannel(c.id(), c.dept().name(), c.dept().nameEn(), c.dept().nameAr(),
                        c.faculty().name(), c.roomKey().equals(ownKey),
                        conversations.view(userId, s.getConversationId())));
            } catch (ApiException e) {
                // uyelik bu arada dustu: atla
            }
            if (out.size() >= 100) {
                break;
            }
        }
        return out;
    }

    /** Herhangi bir bolum kanalina katilir (idempotent; oda tembel kurulur; askida/dogrulanmamis hesap 403). */
    @Transactional
    public DepartmentChannel joinChannel(Long userId, String key) {
        User u = requireUser(userId);
        Channel c = channelOf(key);
        if (!u.isActive() || !u.isEmailVerified()) {
            throw joinForbidden();
        }
        DepartmentChatRoom room = ensureRecord(c.roomKey(), c.dept().name());
        RoomInfo info = rooms.find(RoomKind.DEPARTMENT, room.getId()).orElse(null);
        if (info == null) {
            rooms.ensureRoom(RoomKind.DEPARTMENT, room.getId(), room.getName(), ownerOf(userId));
            info = rooms.find(RoomKind.DEPARTMENT, room.getId()).orElseThrow(DepartmentChatService::notFound);
        }
        if (info.closed()) {
            throw new ApiException(HttpStatus.CONFLICT, "CHAT_ROOM_CLOSED", "Sohbet odası kapalı.");
        }
        if (!rooms.addMember(RoomKind.DEPARTMENT, room.getId(), userId)) {
            throw joinForbidden();
        }
        return new DepartmentChannel(c.id(), c.dept().name(), c.dept().nameEn(), c.dept().nameAr(),
                c.faculty().name(), c.faculty().nameEn(), c.faculty().nameAr(), c.roomKey().equals(keyOf(u)), true,
                false, rooms.memberCount(RoomKind.DEPARTMENT, room.getId()), info.conversationId());
    }

    /** Kanaldan ayrilir (uye degilse / oda yoksa no-op). */
    @Transactional
    public void leaveChannel(Long userId, String key) {
        Channel c = channelOf(key);
        depts.findByDeptKey(c.roomKey()).ifPresent(r -> rooms.removeMember(RoomKind.DEPARTMENT, r.getId(), userId));
    }

    /** Konusma kimligiyle ayrilir (sohbet bilgi sayfasi); bolum odasi degilse no-op. */
    @Transactional
    public void leaveByConversation(Long userId, Long conversationId) {
        rooms.findByConversation(conversationId).filter(i -> i.kind() == RoomKind.DEPARTMENT)
                .ifPresent(i -> rooms.removeMember(RoomKind.DEPARTMENT, i.refId(), userId));
    }

    private Map<String, DepartmentChatStats> statsByKey(Long userId) {
        Map<String, DepartmentChatStats> m = new LinkedHashMap<>();
        for (DepartmentChatStats s : depts.statsFor(userId)) {
            m.put(s.getDeptKey(), s);
        }
        return m;
    }

    private static DepartmentChannel channelView(Channel c, DepartmentChatStats s, String ownKey) {
        boolean closed = s != null && Boolean.TRUE.equals(s.getClosed());
        boolean joined = s != null && !closed && Boolean.TRUE.equals(s.getJoined());
        long count = s == null || closed || s.getMemberCount() == null ? 0 : s.getMemberCount();
        return new DepartmentChannel(c.id(), c.dept().name(), c.dept().nameEn(), c.dept().nameAr(),
                c.faculty().name(), c.faculty().nameEn(), c.faculty().nameAr(), c.roomKey().equals(ownKey), joined,
                closed, count, joined ? s.getConversationId() : null);
    }

    private Channel channelOf(String key) {
        Channel c = key == null ? null : byId.get(key);
        if (c == null) {
            throw new ApiException(HttpStatus.NOT_FOUND, "DEPARTMENT_NOT_FOUND", "Bölüm bulunamadı.");
        }
        return c;
    }

    private static ApiException joinForbidden() {
        return new ApiException(HttpStatus.FORBIDDEN, "DEPARTMENT_JOIN_FORBIDDEN", "Bu bölüm kanalına katılamazsın.");
    }

    private static String fold(String s) {
        if (s == null) {
            return "";
        }
        String n = Normalizer.normalize(s.toLowerCase(Locale.ROOT).replace('ı', 'i'), Normalizer.Form.NFD);
        return n.replaceAll("\\p{M}+", "");
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
