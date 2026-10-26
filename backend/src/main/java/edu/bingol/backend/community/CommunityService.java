package edu.bingol.backend.community;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.storage.FileStorage;
import edu.bingol.backend.community.Community.JoinPolicy;
import edu.bingol.backend.community.CommunityMember.Role;
import edu.bingol.backend.community.dto.CommunityDtos.CommunityView;
import edu.bingol.backend.community.dto.CommunityDtos.CreateCommunityRequest;
import edu.bingol.backend.community.dto.CommunityDtos.MemberView;
import edu.bingol.backend.community.dto.CommunityDtos.UpdateCommunityRequest;
import edu.bingol.backend.community.permissions.ClubAuditService;
import edu.bingol.backend.community.permissions.ClubPermission;
import edu.bingol.backend.community.permissions.ClubPermissions;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

/** Topluluk yasam dongusu ve uyelik. Yetki kararlari ClubPermissions'ta; sistem ADMIN'i hepsini asar. */
@Service
public class CommunityService {

    static final int MAX_OWNED = 3;
    private static final Set<String> IMAGE_TYPES = Set.of("image/jpeg", "image/png", "image/webp");
    private static final long COVER_MAX_BYTES = 3L * 1024 * 1024;
    private static final List<Community.Status> LIVE = List.of(Community.Status.PENDING_REVIEW, Community.Status.ACTIVE);

    private final CommunityRepository communities;
    private final CommunityMemberRepository members;
    private final UserRepository users;
    private final BlockService blocks;
    private final NotificationService notifications;
    private final FileStorage storage;
    private final ClubPermissions permissions;
    private final ClubAuditService audit;

    public CommunityService(CommunityRepository communities, CommunityMemberRepository members, UserRepository users,
                            BlockService blocks, NotificationService notifications, FileStorage storage,
                            ClubPermissions permissions, ClubAuditService audit) {
        this.communities = communities;
        this.members = members;
        this.users = users;
        this.blocks = blocks;
        this.notifications = notifications;
        this.storage = storage;
        this.permissions = permissions;
        this.audit = audit;
    }

    // ---- olusturma / okuma ----

    @Transactional
    public Community create(Actor a, CreateCommunityRequest r) {
        if (communities.countByOwnerIdAndStatusIn(a.id(), LIVE) >= MAX_OWNED) {
            throw new ApiException(HttpStatus.CONFLICT, "COMMUNITY_LIMIT",
                    "En fazla " + MAX_OWNED + " topluluğun sahibi olabilirsiniz.", String.valueOf(MAX_OWNED));
        }
        Community c = new Community();
        c.setName(r.name().trim());
        c.setSlug(uniqueSlug(c.getName()));
        c.setDescription(Texts.blankToNull(r.description()));
        c.setCategory(Texts.blankToNull(r.category()));
        if (r.joinPolicy() != null) {
            c.setJoinPolicy(r.joinPolicy());
        }
        if (r.visibility() != null) {
            c.setVisibility(r.visibility());
        }
        c.setOwnerId(a.id());
        c.setStatus(Community.Status.PENDING_REVIEW);
        try {
            communities.saveAndFlush(c);
        } catch (DataIntegrityViolationException e) {
            throw new ApiException(HttpStatus.CONFLICT, "SLUG_CONFLICT", "Topluluk adı çakıştı, tekrar deneyin.");
        }
        members.save(new CommunityMember(c.getId(), a.id(), Role.OWNER, CommunityMember.Status.ACTIVE));
        return c;
    }

    /** Ad'dan benzersiz slug: cakisirsa -2, -3 ... eklenir; cok cakisirsa rastgele ek. */
    String uniqueSlug(String name) {
        String base = Texts.slugify(name);
        if (!communities.existsBySlug(base)) {
            return base;
        }
        for (int i = 2; i <= 20; i++) {
            String s = base + "-" + i;
            if (!communities.existsBySlug(s)) {
                return s;
            }
        }
        return base + "-" + UUID.randomUUID().toString().substring(0, 8);
    }

    /** Kesfet: yalnizca ACTIVE + PUBLIC. */
    @Transactional(readOnly = true)
    public CursorPage<CommunityView> discover(Actor a, String category, String q, Long cursor, int size) {
        int s = CursorPage.clampSize(size);
        List<Community> rows = communities.discover(Community.Status.ACTIVE, Community.Visibility.PUBLIC,
                category == null ? "" : category.trim(), Texts.likePattern(q), Paging.descStart(cursor),
                PageRequest.of(0, s + 1));
        return Paging.map(rows, s, Community::getId, items -> views(items, a.id()));
    }

    @Transactional(readOnly = true)
    public CommunityView get(Actor a, Long id) {
        return views(List.of(loadVisible(a, id)), a.id()).get(0);
    }

    /** Benim topluluklarim: aktif uyeliklerim (bekleyen/reddedilen toplulugu olmayanlar). */
    @Transactional(readOnly = true)
    public CursorPage<CommunityView> mine(Actor a, Long cursor, int size) {
        int s = CursorPage.clampSize(size);
        List<CommunityMember> rows = members.mine(a.id(), CommunityMember.Status.ACTIVE, Paging.descStart(cursor),
                PageRequest.of(0, s + 1));
        return Paging.map(rows, s, CommunityMember::getId, items -> {
            Map<Long, Community> byId = new HashMap<>();
            communities.findAllById(items.stream().map(CommunityMember::getCommunityId).toList())
                    .forEach(c -> byId.put(c.getId(), c));
            List<Community> ordered = items.stream().map(m -> byId.get(m.getCommunityId()))
                    .filter(c -> c != null && (c.getStatus() == Community.Status.ACTIVE
                            || c.getStatus() == Community.Status.PENDING_REVIEW))
                    .toList();
            return views(ordered, a.id());
        });
    }

    @Transactional
    public CommunityView update(Actor a, Long id, UpdateCommunityRequest r) {
        Community c = load(id);
        permissions.require(a, id, ClubPermission.EDIT_INFO);
        if (r.name() != null && !r.name().isBlank()) {
            c.setName(r.name().trim());
        }
        if (r.description() != null) {
            c.setDescription(Texts.blankToNull(r.description()));
        }
        if (r.category() != null) {
            c.setCategory(Texts.blankToNull(r.category()));
        }
        if (r.joinPolicy() != null) {
            c.setJoinPolicy(r.joinPolicy());
        }
        if (r.visibility() != null) {
            c.setVisibility(r.visibility());
        }
        c.setUpdatedAt(Instant.now());
        communities.save(c);
        return views(List.of(c), a.id()).get(0);
    }

    @Transactional
    public CommunityView setCover(Actor a, Long id, MultipartFile file) {
        Community c = load(id);
        permissions.require(a, id, ClubPermission.EDIT_INFO);
        String url = storage.save("covers", file, IMAGE_TYPES, COVER_MAX_BYTES);
        String old = c.getCoverUrl();
        c.setCoverUrl(url);
        c.setUpdatedAt(Instant.now());
        communities.save(c);
        storage.delete(old);
        return views(List.of(c), a.id()).get(0);
    }

    // ---- uyelik ----

    /** @return ACTIVE (OPEN topluluk) veya PENDING (APPROVAL topluluk) */
    @Transactional
    public String join(Actor a, Long id) {
        Community c = load(id);
        if (c.getStatus() != Community.Status.ACTIVE) {
            throw new ApiException(HttpStatus.NOT_FOUND, "COMMUNITY_NOT_FOUND", "Topluluk bulunamadı.");
        }
        Optional<CommunityMember> existing = members.findByCommunityIdAndUserId(id, a.id());
        if (existing.isPresent()) {
            switch (existing.get().getStatus()) {
                case ACTIVE -> throw new ApiException(HttpStatus.CONFLICT, "ALREADY_MEMBER", "Zaten üyesiniz.");
                case PENDING -> throw new ApiException(HttpStatus.CONFLICT, "REQUEST_PENDING",
                        "Katılma isteğiniz zaten bekliyor.");
                case BANNED -> throw new ApiException(HttpStatus.FORBIDDEN, "BANNED",
                        "Bu topluluktan uzaklaştırıldınız.");
            }
        }
        boolean open = c.getJoinPolicy() == JoinPolicy.OPEN;
        CommunityMember.Status st = open ? CommunityMember.Status.ACTIVE : CommunityMember.Status.PENDING;
        try {
            members.saveAndFlush(new CommunityMember(id, a.id(), Role.MEMBER, st));
        } catch (DataIntegrityViolationException e) {
            throw new ApiException(HttpStatus.CONFLICT, "ALREADY_MEMBER", "Zaten üyesiniz veya isteğiniz bekliyor.");
        }
        if (!open) {
            String who = displayName(a.id());
            for (Long mod : permissions.holders(id, ClubPermission.MANAGE_MEMBERS)) {
                notifications.sendTemplated(mod, NotificationType.COMMUNITY, "notif.community.joinRequest", data(id), who, c.getName());
            }
        }
        return st.name();
    }

    /** Sahip ayrilamaz; yasakli kullanici ayrilarak yasagi kaldiramaz; bekleyen istek iptal edilir. */
    @Transactional
    public void leave(Actor a, Long id) {
        CommunityMember m = members.findByCommunityIdAndUserId(id, a.id())
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "NOT_MEMBER", "Bu topluluğun üyesi değilsiniz."));
        if (m.getRole() == Role.OWNER) {
            throw new ApiException(HttpStatus.CONFLICT, "OWNER_CANNOT_LEAVE", "Topluluk sahibi ayrılamaz.");
        }
        if (m.getStatus() == CommunityMember.Status.BANNED) {
            throw new ApiException(HttpStatus.FORBIDDEN, "BANNED", "Bu topluluktan uzaklaştırıldınız.");
        }
        members.delete(m);
        permissions.clearGrants(id, a.id());
    }

    /** Uye listesi: PRIVATE toplulukta yalnizca uyeler gorur; engel iliskisi olanlar listelenmez. */
    @Transactional(readOnly = true)
    public CursorPage<MemberView> members(Actor a, Long id, Long cursor, int size) {
        Community c = loadVisible(a, id);
        requireReadable(a, c);
        return memberPage(id, CommunityMember.Status.ACTIVE, blockedFor(a), cursor, size);
    }

    @Transactional(readOnly = true)
    public CursorPage<MemberView> requests(Actor a, Long id, Long cursor, int size) {
        load(id);
        permissions.require(a, id, ClubPermission.MANAGE_MEMBERS);
        return memberPage(id, CommunityMember.Status.PENDING, Set.of(-1L), cursor, size);
    }

    @Transactional
    public void decide(Actor a, Long id, Long userId, boolean approve) {
        Community c = load(id);
        permissions.require(a, id, ClubPermission.MANAGE_MEMBERS);
        CommunityMember m = members.findByCommunityIdAndUserId(id, userId)
                .filter(x -> x.getStatus() == CommunityMember.Status.PENDING)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "REQUEST_NOT_FOUND", "Bekleyen istek bulunamadı."));
        if (approve) {
            m.setStatus(CommunityMember.Status.ACTIVE);
            m.setJoinedAt(Instant.now());
            members.save(m);
        } else {
            members.delete(m);
        }
        audit.record(id, a.id(), userId, approve ? ClubAuditService.MEMBER_APPROVED : ClubAuditService.MEMBER_REJECTED, null);
        notifications.sendTemplated(userId, NotificationType.COMMUNITY,
                approve ? "notif.community.joinApproved" : "notif.community.joinRejected", data(id), c.getName());
    }

    /**
     * MANAGE_MEMBERS: uyeyi cikarir; ban=true ise BANNED olarak tutar (yeniden katilamaz). Hedef, islemi yapandan
     * kesin dusuk sirada olmali (moderator moderatoru, yonetici yoneticiyi cikaramaz; sahip hic cikarilamaz).
     */
    @Transactional
    public void remove(Actor a, Long id, Long userId, boolean ban) {
        load(id);
        ClubPermissions.Standing me = permissions.require(a, id, ClubPermission.MANAGE_MEMBERS);
        if (userId.equals(a.id())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "USE_LEAVE", "Kendinizi çıkaramazsınız; ayrılmayı kullanın.");
        }
        CommunityMember m = members.findByCommunityIdAndUserId(id, userId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "NOT_MEMBER", "Kullanıcı bu topluluğun üyesi değil."));
        if (m.getRole() == Role.OWNER) {
            throw new ApiException(HttpStatus.FORBIDDEN, "OWNER_PROTECTED", "Topluluk sahibi çıkarılamaz.");
        }
        if (permissions.standingOfMember(m).rank() >= me.rank()) {
            throw new ApiException(HttpStatus.FORBIDDEN, "ESCALATION_DENIED",
                    "Eşit veya üst düzey bir üyeye müdahale edemezsiniz.");
        }
        if (ban) {
            m.setStatus(CommunityMember.Status.BANNED);
            m.setRole(Role.MEMBER);
            members.save(m);
        } else {
            members.delete(m);
        }
        permissions.clearGrants(id, userId);
        audit.record(id, a.id(), userId, ban ? ClubAuditService.MEMBER_BANNED : ClubAuditService.MEMBER_REMOVED, null);
    }

    // ---- yonetici (ADMIN) ----

    @Transactional(readOnly = true)
    public CursorPage<CommunityView> byStatus(Community.Status status, Long cursor, int size) {
        int s = CursorPage.clampSize(size);
        List<Community> rows = communities.byStatus(status, Paging.descStart(cursor), PageRequest.of(0, s + 1));
        return Paging.map(rows, s, Community::getId, items -> views(items, null));
    }

    @Transactional
    public void review(Long id, boolean approve, String reason) {
        Community c = load(id);
        if (c.getStatus() != Community.Status.PENDING_REVIEW) {
            throw new ApiException(HttpStatus.CONFLICT, "NOT_PENDING", "Topluluk onay beklemiyor.");
        }
        c.setStatus(approve ? Community.Status.ACTIVE : Community.Status.REJECTED);
        c.setReviewNote(approve ? null : Texts.blankToNull(reason));
        c.setUpdatedAt(Instant.now());
        communities.save(c);
        String note = c.getReviewNote();
        notifications.sendTemplated(c.getOwnerId(), NotificationType.COMMUNITY,
                approve ? "notif.community.approved" : note == null ? "notif.community.rejected" : "notif.community.rejectedNote",
                data(id), approve || note == null ? new String[] {c.getName()} : new String[] {c.getName(), note});
    }

    // ---- diger modullerin kullandigi yardimcilar ----

    public Community load(Long id) {
        return communities.findById(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "COMMUNITY_NOT_FOUND", "Topluluk bulunamadı."));
    }

    /** ACTIVE ise herkes; degilse yalnizca sahip ve ADMIN gorur (digerlerine 404). */
    public Community loadVisible(Actor a, Long id) {
        Community c = load(id);
        if (c.getStatus() != Community.Status.ACTIVE && !a.admin() && !c.getOwnerId().equals(a.id())) {
            throw new ApiException(HttpStatus.NOT_FOUND, "COMMUNITY_NOT_FOUND", "Topluluk bulunamadı.");
        }
        return c;
    }

    /** Aktif uyenin rolu; uye degilse (veya bekleyen/yasakli) bos. */
    public Optional<Role> roleOf(Long communityId, Long userId) {
        return members.findByCommunityIdAndUserId(communityId, userId).filter(CommunityMember::isActive)
                .map(CommunityMember::getRole);
    }

    /** ADMIN her toplulukta OWNER sayilir. */
    public Role effectiveRole(Actor a, Community c) {
        return a.admin() ? Role.OWNER : roleOf(c.getId(), a.id()).orElse(null);
    }

    /** Kulup yetkisi sorgusu (gonderi/etkinlik gibi diger servisler icin); sistem ADMIN'i her yetkiye sahip. */
    public boolean can(Actor a, Long communityId, ClubPermission p) {
        return permissions.has(a, communityId, p);
    }

    /** Yetki yoksa 403. */
    public void require(Actor a, Long communityId, ClubPermission p) {
        permissions.require(a, communityId, p);
    }

    /** Topluluk icerigini (uye listesi, akis) okuyabilir mi: PUBLIC ise herkes, PRIVATE ise yalnizca uye/ADMIN. */
    public void requireReadable(Actor a, Community c) {
        if (c.getVisibility() == Community.Visibility.PRIVATE && effectiveRole(a, c) == null) {
            throw new ApiException(HttpStatus.FORBIDDEN, "NOT_MEMBER", "Bu özel topluluğun içeriğini yalnızca üyeler görebilir.");
        }
    }

    /** Engel iliskisi olan kullanicilar (NOT IN bos kalmasin diye -1 eklenir). */
    public Set<Long> blockedFor(Actor a) {
        Set<Long> s = new HashSet<>(blocks.hiddenFrom(a.id()));
        s.add(-1L);
        return s;
    }

    /** Topluluk id -> ad (etkinlik listelerinde gostermek icin). */
    public Map<Long, String> namesById(Collection<Long> ids) {
        Map<Long, String> m = new HashMap<>();
        if (!ids.isEmpty()) {
            communities.findAllById(ids).forEach(c -> m.put(c.getId(), c.getName()));
        }
        return m;
    }

    public Map<Long, User> usersById(Collection<Long> ids) {
        Map<Long, User> m = new HashMap<>();
        users.findAllById(ids).forEach(u -> m.put(u.getId(), u));
        return m;
    }

    // ---- ic yardimcilar ----

    private CursorPage<MemberView> memberPage(Long cid, CommunityMember.Status status, Set<Long> excluded,
                                              Long cursor, int size) {
        int s = CursorPage.clampSize(size);
        List<CommunityMember> rows = members.page(cid, status, Paging.ascStart(cursor), excluded, PageRequest.of(0, s + 1));
        return Paging.map(rows, s, CommunityMember::getId, items -> {
            Map<Long, User> u = usersById(items.stream().map(CommunityMember::getUserId).toList());
            return items.stream().map(m -> {
                User x = u.get(m.getUserId());
                return new MemberView(m.getUserId(), x == null ? "Kullanıcı" : x.getDisplayName(),
                        x == null ? null : x.getAvatarUrl(), m.getRole(), m.getJoinedAt());
            }).toList();
        });
    }

    /** Toplu gorunum: uye sayilari ve benim uyeligim tek sorguyla. viewerId null ise uyelik "NONE". */
    private List<CommunityView> views(List<Community> list, Long viewerId) {
        if (list.isEmpty()) {
            return List.of();
        }
        List<Long> ids = list.stream().map(Community::getId).toList();
        Map<Long, Long> counts = new HashMap<>();
        for (Object[] row : members.countByCommunity(ids, CommunityMember.Status.ACTIVE)) {
            counts.put((Long) row[0], (Long) row[1]);
        }
        Map<Long, CommunityMember> mine = new HashMap<>();
        if (viewerId != null) {
            members.findByUserIdAndCommunityIdIn(viewerId, ids).forEach(m -> mine.put(m.getCommunityId(), m));
        }
        List<CommunityView> out = new ArrayList<>();
        for (Community c : list) {
            CommunityMember m = mine.get(c.getId());
            out.add(new CommunityView(c.getId(), c.getName(), c.getSlug(), c.getDescription(), c.getCategory(),
                    c.getCoverUrl(), c.getJoinPolicy(), c.getVisibility(), c.getStatus(), c.getOwnerId(),
                    counts.getOrDefault(c.getId(), 0L), m == null ? "NONE" : m.getStatus().name(),
                    m != null && m.isActive() ? m.getRole() : null, c.getCreatedAt()));
        }
        return out;
    }

    private String displayName(Long userId) {
        return users.findById(userId).map(User::getDisplayName).orElse("Bir kullanıcı");
    }

    static Map<String, String> data(Long communityId) {
        return Map.of("communityId", communityId.toString());
    }
}
