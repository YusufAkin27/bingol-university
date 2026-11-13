package edu.bingol.backend.messaging.room.dept;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.catalog.CatalogService;
import edu.bingol.backend.messaging.room.RoomConversations;
import edu.bingol.backend.messaging.room.RoomConversations.RoomInfo;
import edu.bingol.backend.messaging.room.RoomKind;
import edu.bingol.backend.academic.AudienceKey;
import edu.bingol.backend.unitnews.UnitKeys;
import org.springframework.data.domain.PageRequest;
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
 * kullanici kayitta kendi bolumune katilir; diger bolumlere de katilabilir ve istedigi an ayrilir. Oda ilk katilimda
 * tembel kurulur; kurucu/grup yoneticisi sistem yoneticisidir (ADMIN; moderasyon: DepartmentRoomModerators).
 * Uyeler birbirini mevcut sikayet akisiyle (USER / MESSAGE / CONVERSATION) bildirir.
 */
@Service
public class DepartmentChatService {

    private final RoomConversations rooms;
    private final DepartmentChatRoomRepository depts;
    private final UserRepository users;
    private final CatalogService catalog;

    public DepartmentChatService(RoomConversations rooms, DepartmentChatRoomRepository depts, UserRepository users,
                                 CatalogService catalog) {
        this.rooms = rooms;
        this.depts = depts;
        this.users = users;
        this.catalog = catalog;
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
        return joinRoom(u, key, u.getDepartment());
    }

    /**
     * Baska bir bolume katilim; profil bolumunu degistirmez. Gecerli bolum = katalogda olan YA DA en az bir ACTIVE
     * kullanicinin profil bolumu olan ad (eski/katalog disi kayitlar da katilabilir).
     */
    @Transactional
    public DepartmentChatView join(Long userId, String department) {
        if (department == null) return join(userId);
        User u = requireUser(userId);
        String name = department.trim();
        if (name.isEmpty() || name.length() > 120 || UnitKeys.deptKey(name) == null
                || !(inCatalog(name) || users.existsActiveDepartment(name))) {
            throw notFound();
        }
        return joinRoom(u, UnitKeys.deptKey(name), name);
    }

    private boolean inCatalog(String name) {
        return catalog.catalog().faculties().stream().flatMap(f -> f.departments().stream())
                .map(CatalogService.Department::name).anyMatch(name::equals);
    }

    /** Istemci sayfa boyutu: varsayilan 30, sunucu tavani 50. */
    public static final int DEFAULT_PAGE = 30;
    public static final int MAX_PAGE = 50;
    /** q aramasinda bellekte suzulen DISTINCT bolum adi tavani (gercek bolum sayisi yuzlerce). */
    private static final int SEARCH_POOL = 2000;

    /**
     * "Bolum ara": UYESI (ACTIVE kullanicisi) olan bolumler, ada gore alfabetik keyset sayfalama. Kaynak katalog
     * degil app_user.department'tir; hic kullanicisi olmayan bolum listelenmez. q: Turkce-duyarli (AudienceKey
     * katlama) icerir aramasi. Oda/uye bilgisi sayfa icin TOPLU sorgulanir.
     */
    @Transactional(readOnly = true)
    public List<DepartmentChatView> browse(Long userId, Integer size, String after, String q) {
        User u = requireUser(userId);
        int limit = size == null || size < 1 ? DEFAULT_PAGE : Math.min(size, MAX_PAGE);
        String cursor = after == null ? "" : after;
        String needle = q == null || q.isBlank() ? null : AudienceKey.of(q);
        List<String> raw;
        if (needle == null) {
            // Indeksli keyset; ayni anahtarli yazim varyantlari sayfayi kisaltabilir: 2x okuyup kirpariz.
            raw = users.pageActiveDepartments(cursor, PageRequest.of(0, limit * 2));
        } else {
            raw = users.pageActiveDepartments("", PageRequest.of(0, SEARCH_POOL)).stream()
                    .filter(n -> n.compareTo(cursor) > 0)
                    .filter(n -> {
                        String f = AudienceKey.of(n);
                        return f != null && f.contains(needle);
                    }).toList();
        }
        var picked = new java.util.LinkedHashMap<String, String>(); // deptKey -> ham ad (keyset anahtari)
        for (String n : raw) {
            String key = n == null || n.isBlank() ? null : UnitKeys.deptKey(n);
            if (key != null) picked.putIfAbsent(key, n);
            if (picked.size() >= limit) break;
        }
        if (picked.isEmpty()) return List.of();
        var roomByKey = new java.util.HashMap<String, DepartmentChatRoom>();
        for (DepartmentChatRoom r : depts.findByDeptKeyIn(picked.keySet())) roomByKey.put(r.getDeptKey(), r);
        var stats = rooms.stats(RoomKind.DEPARTMENT,
                roomByKey.values().stream().map(DepartmentChatRoom::getId).toList(), u.getId());
        var out = new java.util.ArrayList<DepartmentChatView>(picked.size());
        picked.forEach((key, name) -> {
            DepartmentChatRoom room = roomByKey.get(key);
            RoomConversations.RoomStat st = room == null ? null : stats.get(room.getId());
            // departmentName = ham ad: istemci `after` imlecini bundan alir (keyset anahtariyla ayni olmali)
            out.add(st == null ? new DepartmentChatView(true, name, false, false, 0, null)
                    : new DepartmentChatView(true, name, false, st.joined(), st.memberCount(),
                            st.joined() ? st.conversationId() : null));
        });
        return out;
    }

    private DepartmentChatView joinRoom(User u, String key, String name) {
        return joinRoom(u, key, name, false);
    }

    /**
     * Profilde ILK kez bolum belirlenince (profil guncelleme): bolum odasi kurulur ve kullanici eklenir. Ayri islem:
     * hata/kilit profil kaydini bozmaz; bolum adi acikca verilir (dis islem henuz commit etmedi).
     */
    @Transactional(propagation = org.springframework.transaction.annotation.Propagation.REQUIRES_NEW)
    public void joinOnFirstDepartment(Long userId, String department) {
        User u = requireUser(userId);
        String key = department == null || department.isBlank() ? null : UnitKeys.deptKey(department);
        if (key != null) joinRoom(u, key, department, true);
    }

    /** Yalniz kayitta cagirilir; ayrilan kullanicilar giriste yeniden eklenmez. */
    @Transactional
    public void joinOnSignup(Long userId) {
        User u = requireUser(userId);
        String key = keyOf(u);
        if (key != null) joinRoom(u, key, u.getDepartment(), true);
    }

    private DepartmentChatView joinRoom(User u, String key, String name, boolean signup) {
        Long userId = u.getId();
        DepartmentChatRoom room = ensureRecord(key, name);
        RoomInfo info = rooms.find(RoomKind.DEPARTMENT, room.getId()).orElse(null);
        if (info == null) {
            rooms.ensureRoom(RoomKind.DEPARTMENT, room.getId(), room.getName(), ownerOf(userId));
            info = rooms.find(RoomKind.DEPARTMENT, room.getId()).orElseThrow(DepartmentChatService::notFound);
        }
        if (info.closed()) {
            // Bolum odalari ASLA kapali kalmaz (eski kapali kayitlar V1871 ile acildi; rastlanirsa kendiliginden acilir).
            rooms.openRoom(RoomKind.DEPARTMENT, room.getId(), List.of());
            info = new RoomInfo(info.conversationId(), info.kind(), info.refId(), false);
        }
        if (signup) {
            rooms.addMemberIfSpace(RoomKind.DEPARTMENT, room.getId(), userId);
            return view(u, room, info);
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

    @Transactional
    public void leave(Long userId, Long conversationId) {
        if (conversationId == null) {
            leave(userId);
            return;
        }
        requireUser(userId);
        var room = depts.findByConversationId(conversationId).orElseThrow(DepartmentChatService::notFound);
        rooms.removeMember(RoomKind.DEPARTMENT, room.getId(), userId);
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

    /** Bolum odasi KAPATILAMAZ (409 DEPT_ROOM_CANNOT_CLOSE); acma (eski kapali kayitlar icin) serbest. */
    @Transactional
    public AdminRoomView adminSetClosed(Long id, boolean closed) {
        DepartmentChatRoom r = depts.findById(id).orElseThrow(DepartmentChatService::notFound);
        if (rooms.find(RoomKind.DEPARTMENT, id).isEmpty()) {
            throw notFound();
        }
        if (closed) {
            throw new ApiException(HttpStatus.CONFLICT, "DEPT_ROOM_CANNOT_CLOSE",
                    "Bölüm sohbet odaları kapatılamaz.");
        }
        rooms.openRoom(RoomKind.DEPARTMENT, id, List.of());
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
        boolean joined = rooms.isMember(RoomKind.DEPARTMENT, room.getId(), u.getId());
        return new DepartmentChatView(true, room.getName(), false, joined,
                rooms.memberCount(RoomKind.DEPARTMENT, room.getId()),
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
