package edu.bingol.backend.community.admin;

import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityMember.Role;
import edu.bingol.backend.community.CommunityMemberRepository;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.community.dto.CommunityDtos.UpdateCommunityRequest;
import edu.bingol.backend.community.extras.ClubExtrasHooks;
import edu.bingol.backend.community.extras.ClubMemberQueryRepository;
import edu.bingol.backend.community.admin.ClubAdminDtos.ActionResult;
import edu.bingol.backend.community.admin.ClubAdminDtos.ClubDetail;
import edu.bingol.backend.community.admin.ClubAdminDtos.MemberActionResult;
import edu.bingol.backend.community.admin.ClubAdminDtos.TransferRequest;
import edu.bingol.backend.community.admin.ClubAdminDtos.UpdateRequest;
import edu.bingol.backend.community.permissions.ClubAuditService;
import edu.bingol.backend.community.permissions.ClubMemberGrantRepository;
import edu.bingol.backend.community.permissions.ClubOwnershipTransfer;
import edu.bingol.backend.community.permissions.ClubOwnershipTransferRepository;
import edu.bingol.backend.community.permissions.ClubRoleService;
import edu.bingol.backend.community.permissions.ClubDtos.AccessRequest;
import edu.bingol.backend.media.MediaService;
import edu.bingol.backend.messaging.room.RoomConversations;
import edu.bingol.backend.messaging.room.RoomKind;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.StringJoiner;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

/**
 * Yonetici kulup yonetimi (P06): duzenleme, zorla kapat / yeniden ac, silme, uye cikarma, rol, ZORLA sahiplik devri,
 * katilim istegi karari, davet iptali. Var olan servisleri yeniden kullanir (CommunityService, ClubRoleService,
 * ClubInviteService): sistem ADMIN'i {@code ClubPermissions}'ta her yetkiye ve kulup sahibinden yuksek siraya sahiptir
 * (SYSTEM_RANK 100), bu yuzden o servislerdeki kurallar (sahip cikarilamaz, kendi rolu degistirilemez, OWNER rolu
 * yalniz devirle verilir) yonetici icin de aynen gecerlidir. Her yazma, AuditContext ile COMMUNITY/{id} hedefli
 * denetlenir; ayrica kulup icinde club_audit kaydi yazilir (kulup yetkilileri "Denetim" sekmesinde gorur).
 */
@Service
public class ClubAdminService {

    private static final Logger log = LoggerFactory.getLogger(ClubAdminService.class);

    public static final String A_CLOSED = "ADMIN_CLUB_CLOSED";
    public static final String A_REOPENED = "ADMIN_CLUB_REOPENED";
    public static final String A_DELETED = "ADMIN_CLUB_DELETED";
    public static final String A_EDITED = "ADMIN_CLUB_EDITED";
    public static final String A_TRANSFER = "ADMIN_OWNER_TRANSFER";
    public static final String A_ROLE = "ADMIN_MEMBER_ROLE";
    public static final String A_COVER = "ADMIN_COVER_CHANGED";

    static final int MAX_OWNED = 3;
    private static final int NOTIFY_MAX = 500;
    private static final List<Community.Status> LIVE = List.of(Community.Status.PENDING_REVIEW, Community.Status.ACTIVE);

    private final CommunityRepository communities;
    private final CommunityMemberRepository members;
    private final ClubMemberGrantRepository grants;
    private final ClubOwnershipTransferRepository transfers;
    private final CommunityService communityService;
    private final ClubRoleService roles;
    private final edu.bingol.backend.community.permissions.ClubInviteService invites;
    private final ClubAuditService audit;
    private final ClubExtrasHooks hooks;
    private final ClubMemberQueryRepository memberQuery;
    private final RoomConversations rooms;
    private final NotificationService notifications;
    private final UserRepository users;
    private final MediaService media;
    private final ClubAdminQueryService query;

    public ClubAdminService(CommunityRepository communities, CommunityMemberRepository members,
                            ClubMemberGrantRepository grants, ClubOwnershipTransferRepository transfers,
                            CommunityService communityService, ClubRoleService roles,
                            edu.bingol.backend.community.permissions.ClubInviteService invites, ClubAuditService audit,
                            ClubExtrasHooks hooks, ClubMemberQueryRepository memberQuery, RoomConversations rooms,
                            NotificationService notifications, UserRepository users, MediaService media,
                            ClubAdminQueryService query) {
        this.communities = communities;
        this.members = members;
        this.grants = grants;
        this.transfers = transfers;
        this.communityService = communityService;
        this.roles = roles;
        this.invites = invites;
        this.audit = audit;
        this.hooks = hooks;
        this.memberQuery = memberQuery;
        this.rooms = rooms;
        this.notifications = notifications;
        this.users = users;
        this.media = media;
        this.query = query;
    }

    // ---- kulup ----

    /** Ad/aciklama/kategori/politika/gorunurluk; kufur suzgeci atlanir, kategori kurali ve oda basligi senkronu aynen. */
    @Transactional
    public ClubDetail update(Long id, UpdateRequest r) {
        Community before = communityService.load(id);
        if (r.name() == null && r.description() == null && r.category() == null && r.joinPolicy() == null
                && r.visibility() == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Değiştirilecek bir alan verilmedi.");
        }
        String oldName = before.getName();
        StringJoiner changed = new StringJoiner(",");
        if (r.name() != null && !r.name().trim().equals(before.getName())) {
            changed.add("name");
        }
        if (r.description() != null) {
            changed.add("description");
        }
        if (r.category() != null && !r.category().trim().equals(String.valueOf(before.getCategory()))) {
            changed.add("category");
        }
        if (r.joinPolicy() != null && r.joinPolicy() != before.getJoinPolicy()) {
            changed.add("joinPolicy");
        }
        if (r.visibility() != null && r.visibility() != before.getVisibility()) {
            changed.add("visibility");
        }
        communityService.adminUpdate(actor(), id, new UpdateCommunityRequest(r.name(), r.description(), r.category(),
                r.joinPolicy(), r.visibility()));
        communities.flush(); // ayrinti JDBC ile okunur: JPA yazimi once veritabanina inmeli
        String fields = changed.length() == 0 ? "-" : changed.toString();
        audit.record(id, actorId(), null, A_EDITED, "fields=" + fields + (changed.toString().contains("name")
                ? " oldName=" + oldName : ""));
        target(id).summary("kulüp düzenlendi: " + fields);
        return query.detail(id);
    }

    /** Kapak degistirme (T1 gorsel hatti: dogrulama + yeniden kodlama + EXIF temizligi). */
    @Transactional
    public ClubDetail setCover(Long id, MultipartFile file) {
        communityService.load(id);
        communityService.setCover(actor(), id, file);
        audit.record(id, actorId(), null, A_COVER, "set");
        target(id).summary("kapak değiştirildi");
        return query.detail(id);
    }

    @Transactional
    public ClubDetail removeCover(Long id) {
        Community c = communityService.load(id);
        String old = c.getCoverUrl();
        if (old != null) {
            c.setCoverUrl(null);
            c.setUpdatedAt(Instant.now());
            communities.saveAndFlush(c);
            media.release(old);
            audit.record(id, actorId(), null, A_COVER, "removed");
        }
        target(id).summary(old == null ? "kapak zaten yok" : "kapak kaldırıldı");
        return query.detail(id);
    }

    /**
     * ACTIVE -> HIDDEN: kesfet/arama/ayrinttan kalkar (rapor kararindaki "gizle" ile ayni durum), sohbet odasi kapanir
     * (herkes cikar, gecmis saklanir). Etkinlikler iptal EDILMEZ: etkinlik sorgulari yalniz ACTIVE kulupleri listeler,
     * yeniden acilinca geri gelir. Geri alinabilir (yeniden ac).
     */
    @Transactional
    public ActionResult close(Long id, String reason) {
        Community c = communityService.load(id);
        requireStatus(c, Community.Status.ACTIVE);
        c.setStatus(Community.Status.HIDDEN);
        c.setReviewNote(clip(reason, 300));
        c.setUpdatedAt(Instant.now());
        communities.saveAndFlush(c);
        try {
            rooms.find(RoomKind.COMMUNITY, id).ifPresent(i -> rooms.closeRoom(RoomKind.COMMUNITY, id));
        } catch (RuntimeException e) {
            log.warn("Kulup odasi kapatilamadi (kulup {}): {}", id, e.toString());
        }
        audit.record(id, actorId(), null, A_CLOSED, clip(reason, 400));
        int n = notifyMembers(c, "notif.community.adminClosed");
        target(id).summary("kulüp kapatıldı (HIDDEN), bildirilen=" + n);
        return new ActionResult(id, Community.Status.HIDDEN.name(), false, n);
    }

    /** HIDDEN -> ACTIVE: oda yeniden acilir, aktif uyeler odaya geri eklenir. */
    @Transactional
    public ActionResult reopen(Long id, String reason) {
        Community c = communityService.load(id);
        requireStatus(c, Community.Status.HIDDEN);
        c.setStatus(Community.Status.ACTIVE);
        c.setReviewNote(null);
        c.setUpdatedAt(Instant.now());
        communities.saveAndFlush(c);
        try {
            RoomConversations.RoomInfo info = rooms.find(RoomKind.COMMUNITY, id).orElse(null);
            if (info == null) {
                hooks.onCommunityActivated(c);
            } else if (info.closed()) {
                rooms.openRoom(RoomKind.COMMUNITY, id, activeUserIds(id));
            }
        } catch (RuntimeException e) {
            log.warn("Kulup odasi acilamadi (kulup {}): {}", id, e.toString());
        }
        audit.record(id, actorId(), null, A_REOPENED, clip(reason, 400));
        int n = notifyMembers(c, "notif.community.adminReopened");
        target(id).summary("kulüp yeniden açıldı (ACTIVE), bildirilen=" + n);
        return new ActionResult(id, Community.Status.ACTIVE.name(), false, n);
    }

    /**
     * Yumusak silme (CommunityService.deleteByAdmin): kesfetten duser, sohbet odasi kapanir, gelecek etkinlikler iptal
     * edilir, kapak/logo ve gonderi gorselleri diskten silinir, uyelere haber gider. GERI ALINAMAZ (irreversible).
     */
    @Transactional
    public ActionResult delete(Long id, String reason) {
        communityService.load(id);
        communityService.deleteByAdmin(actor(), id, clip(reason, 200));
        long notified = members.countByCommunityIdAndStatus(id, CommunityMember.Status.ACTIVE);
        target(id).summary("kulüp silindi (geri alınamaz)");
        return new ActionResult(id, Community.Status.DELETED.name(), true, (int) Math.min(notified, NOTIFY_MAX));
    }

    // ---- uyeler ----

    /** Uyeyi cikarir (ban=true: yasaklar). Sahip cikarilamaz; kendini cikarma/yukselme kurallari CommunityService'tedir. */
    @Transactional
    public MemberActionResult removeMember(Long id, Long userId, boolean ban) {
        Community c = communityService.load(id);
        communityService.remove(actor(), id, userId, ban);
        notifications.sendTemplated(userId, NotificationType.COMMUNITY,
                ban ? "notif.community.adminBanned" : "notif.community.adminRemoved",
                Map.of("communityId", id.toString()), c.getName());
        target(id).summary((ban ? "uye yasaklandi" : "uye cikarildi") + " user=" + userId);
        return new MemberActionResult(id, userId, ban ? "BANNED" : "REMOVED");
    }

    /**
     * Rol degisimi (MEMBER/MODERATOR/ADMIN). OWNER verme yalniz devirle yapilir; mevcut sahibin rolu bu uctan
     * dusurulemez (son sahip korunur). Yetki/yukselme kurallari ClubRoleService'tedir (hedef sirasi, kendi rolu...).
     */
    @Transactional
    public MemberActionResult setRole(Long id, Long userId, Role role) {
        communityService.load(id);
        if (role == Role.OWNER) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "CLUB_ADMIN_USE_TRANSFER",
                    "Sahiplik rol değişimiyle verilemez; sahiplik devri kullanın.");
        }
        CommunityMember m = members.findByCommunityIdAndUserId(id, userId).filter(CommunityMember::isActive)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "NOT_MEMBER",
                        "Kullanıcı bu topluluğun üyesi değil."));
        if (m.getRole() == Role.OWNER) {
            throw new ApiException(HttpStatus.CONFLICT, "CLUB_LAST_OWNER",
                    "Kulübün sahibi değiştirilemez; önce sahipliği devredin.");
        }
        Role old = m.getRole();
        roles.setAccess(actor(), id, userId, new AccessRequest(role, null, null));
        audit.record(id, actorId(), userId, A_ROLE, "role=" + old + "->" + role);
        target(id).summary("üye rolü: " + old + " -> " + role + " user=" + userId);
        return new MemberActionResult(id, userId, role.name());
    }

    /**
     * ZORLA sahiplik devri (iki asamali kabul gerekmez; yonetici karari, geri alinamaz). Yeni sahip kulubun ACTIVE uyesi
     * olmali, baska kulup(ler)in sahibi olarak 3 sinirini asmamali. Eski sahip keepAsAdmin ile yonetici kalir ya da
     * kulupten cikar. Bekleyen devir teklifi iptal edilir. Kulup ACTIVE ya da HIDDEN olmali.
     */
    @Transactional
    public ActionResult transferOwnership(Long id, TransferRequest r) {
        Community c = communityService.load(id);
        if (c.getStatus() != Community.Status.ACTIVE && c.getStatus() != Community.Status.HIDDEN) {
            throw stateInvalid();
        }
        Long to = r.targetUserId();
        CommunityMember target = members.findByCommunityIdAndUserId(id, to).filter(CommunityMember::isActive).orElse(null);
        if (target == null || target.getRole() == Role.OWNER || to.equals(c.getOwnerId())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "TRANSFER_TARGET_INVALID",
                    "Devir için topluluğun başka bir aktif üyesini seçin.");
        }
        User toUser = users.findById(to).orElse(null);
        if (toUser == null || toUser.getStatus() != edu.bingol.backend.user.UserStatus.ACTIVE) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "TRANSFER_TARGET_INVALID",
                    "Devir için topluluğun başka bir aktif üyesini seçin.");
        }
        communities.lockOwner(to); // ayni kullaniciya es zamanli devirler siralansin (3 sinir yarisi)
        if (communities.countByOwnerIdAndStatusIn(to, LIVE) >= MAX_OWNED) {
            throw new ApiException(HttpStatus.CONFLICT, "COMMUNITY_LIMIT",
                    "En fazla " + MAX_OWNED + " topluluğun sahibi olabilirsiniz.", String.valueOf(MAX_OWNED));
        }
        Long oldOwnerId = c.getOwnerId();
        boolean keep = r.keepAsAdmin() == null || r.keepAsAdmin();
        CommunityMember oldOwner = members.findByCommunityIdAndUserId(id, oldOwnerId).orElse(null);
        target.setRole(Role.OWNER);
        members.save(target);
        grants.deleteMember(id, to);
        if (oldOwner != null) {
            if (keep) {
                oldOwner.setRole(Role.ADMIN);
                members.save(oldOwner);
            } else {
                members.delete(oldOwner);
                hooks.onMemberGone(id, oldOwnerId);
            }
            grants.deleteMember(id, oldOwnerId);
        }
        c.setOwnerId(to);
        c.setUpdatedAt(Instant.now());
        communities.save(c);
        cancelPendingTransfer(id);
        audit.record(id, actorId(), to, A_TRANSFER, "oldOwner=" + oldOwnerId + " newOwner=" + to + " keepAsAdmin=" + keep);
        notifications.sendTemplated(to, NotificationType.COMMUNITY, "notif.community.adminOwnerAssigned",
                Map.of("communityId", id.toString()), c.getName());
        if (oldOwner != null && !oldOwnerId.equals(to)) {
            notifications.sendTemplated(oldOwnerId, NotificationType.COMMUNITY, "notif.community.adminOwnerRemoved",
                    Map.of("communityId", id.toString()), c.getName());
        }
        target(id).summary("sahiplik devri: " + oldOwnerId + " -> " + to + " (zorla, geri alınamaz)");
        return new ActionResult(id, c.getStatus().name(), true, 2);
    }

    // ---- basvurular / davetler ----

    /** Bekleyen katilma istegini zorla onaylar / reddeder (yonetici MANAGE_MEMBERS'a sahiptir). */
    @Transactional
    public MemberActionResult decideRequest(Long id, Long userId, boolean approve) {
        communityService.load(id);
        communityService.decide(actor(), id, userId, approve);
        target(id).summary("katılma isteği " + (approve ? "onaylandı" : "reddedildi") + " user=" + userId);
        return new MemberActionResult(id, userId, approve ? "APPROVED" : "REJECTED");
    }

    @Transactional
    public void revokeInvite(Long id, Long inviteId) {
        communityService.load(id);
        invites.revoke(actor(), id, inviteId);
        target(id).summary("davet iptal edildi invite=" + inviteId);
    }

    // ---- ic yardimcilar ----

    /** Yonetici kimligi: JWT yoneticisinde kullanici id'si; Basic auth yoneticisinde null (kayit aktorsuz). */
    static Long actorId() {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        return a != null && a.getPrincipal() instanceof Long l ? l : null;
    }

    static Actor actor() {
        return new Actor(actorId(), true);
    }

    static AuditContext.Data target(Long id) {
        return AuditContext.target("COMMUNITY", id);
    }

    private void requireStatus(Community c, Community.Status want) {
        if (c.getStatus() != want) {
            throw stateInvalid();
        }
    }

    private static ApiException stateInvalid() {
        return new ApiException(HttpStatus.CONFLICT, "CLUB_ADMIN_STATE_INVALID",
                "Bu işlem kulübün mevcut durumunda yapılamaz.");
    }

    private void cancelPendingTransfer(Long communityId) {
        transfers.lockByStatus(communityId, ClubOwnershipTransfer.Status.PENDING).ifPresent(t -> {
            t.setStatus(ClubOwnershipTransfer.Status.CANCELLED);
            t.setDecidedAt(Instant.now());
            transfers.save(t);
        });
    }

    /** Aktif uyelere (en cok NOTIFY_MAX) alicinin dilinde bildirim; donen sayi gonderilen. */
    private int notifyMembers(Community c, String key) {
        int sent = 0;
        for (Long uid : members.userIdsByStatus(c.getId(), CommunityMember.Status.ACTIVE, PageRequest.of(0, NOTIFY_MAX))) {
            notifications.sendTemplated(uid, NotificationType.COMMUNITY, key,
                    Map.of("communityId", c.getId().toString()), c.getName());
            sent++;
        }
        return sent;
    }

    private List<Long> activeUserIds(Long communityId) {
        List<Long> all = new ArrayList<>();
        long after = 0;
        while (true) {
            List<Long> page = memberQuery.activeUserIdsAfter(communityId, after, PageRequest.of(0, 500));
            all.addAll(page);
            if (page.size() < 500) {
                return all;
            }
            after = page.get(page.size() - 1);
        }
    }

    private static String clip(String s, int max) {
        if (s == null || s.isBlank()) {
            return null;
        }
        String t = s.trim();
        return t.length() <= max ? t : t.substring(0, max);
    }
}
