package edu.bingol.backend.community.permissions;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityMember.Role;
import edu.bingol.backend.community.CommunityMemberRepository;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.community.permissions.ClubDtos.AccessRequest;
import edu.bingol.backend.community.permissions.ClubDtos.AccessView;
import edu.bingol.backend.community.permissions.ClubDtos.MyAccessView;
import edu.bingol.backend.community.permissions.ClubDtos.TemplateView;
import edu.bingol.backend.community.permissions.ClubPermissions.Standing;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import java.time.Instant;
import java.util.Arrays;
import java.util.EnumSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Yetki verme/alma ve rol atama. Yukseltme korumasi (hepsi burada):
 * <ul>
 *   <li>Islem icin MANAGE_ROLES gerekir (sahip ve sistem ADMIN'inde dogal; ADMIN'de yalnizca sahip verdiyse).</li>
 *   <li>Kimse kendi yetkisini degistiremez; sahibin yetkisi/rolu alinamaz.</li>
 *   <li>Hedefin sirasi ve YENI sirasi, islemi yapanin sirasindan kesin dusuk olmalidir (esit/ust sira dokunulmaz).</li>
 *   <li>Islemi yapan sahip degilse, verilen yetkiler kendi yetkilerinin alt kumesi olmalidir.</li>
 *   <li>MANAGE_ROLES yalnizca sahip tarafindan ve yalnizca ADMIN rolundeki uyeye verilir.</li>
 * </ul>
 */
@Service
public class ClubRoleService {

    private final CommunityRepository communities;
    private final CommunityMemberRepository members;
    private final ClubMemberGrantRepository grants;
    private final ClubPermissions permissions;
    private final ClubAuditService audit;
    private final NotificationService notifications;

    public ClubRoleService(CommunityRepository communities, CommunityMemberRepository members,
                           ClubMemberGrantRepository grants, ClubPermissions permissions, ClubAuditService audit,
                           NotificationService notifications) {
        this.communities = communities;
        this.members = members;
        this.grants = grants;
        this.permissions = permissions;
        this.audit = audit;
        this.notifications = notifications;
    }

    public List<TemplateView> templates() {
        return Arrays.stream(ClubRoleTemplate.values())
                .map(t -> new TemplateView(t.name(), t.role(), t.permissions())).toList();
    }

    @Transactional(readOnly = true)
    public MyAccessView mine(Actor a, Long communityId) {
        community(communityId);
        Standing s = permissions.standing(a, communityId).orElseThrow(ClubRoleService::notFound);
        return new MyAccessView(s.role(), s.permissions());
    }

    /** Bir uyenin yetkileri: MANAGE_ROLES veya MANAGE_MEMBERS sahibi gorur. */
    @Transactional(readOnly = true)
    public AccessView view(Actor a, Long communityId, Long userId) {
        community(communityId);
        Standing me = permissions.standing(a, communityId).orElseThrow(ClubRoleService::notFound);
        if (!me.has(ClubPermission.MANAGE_ROLES) && !me.has(ClubPermission.MANAGE_MEMBERS) && !a.id().equals(userId)) {
            throw forbidden();
        }
        CommunityMember m = activeMember(communityId, userId);
        return toView(m, grants.findByCommunityIdAndUserId(communityId, userId));
    }

    @Transactional
    public AccessView setAccess(Actor a, Long communityId, Long userId, AccessRequest r) {
        Community c = community(communityId);
        Standing me = permissions.standing(a, communityId).orElseThrow(ClubRoleService::notFound);
        if (!me.has(ClubPermission.MANAGE_ROLES)) {
            throw forbidden();
        }
        if (r.role() == null && r.template() == null && r.permissions() == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz istek.");
        }
        if (r.role() == Role.OWNER) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_ROLE", "Sahiplik yalnızca devir ile verilir.");
        }
        CommunityMember t = target(a, communityId, userId);
        Optional<ClubMemberGrant> grant = grants.findByCommunityIdAndUserId(communityId, userId);
        Standing current = permissions.standingOf(t, grant);
        // Hedef, islemi yapandan kesin asagida olmali (esit sira: ADMIN baska ADMIN'e dokunamaz).
        if (current.rank() >= me.rank()) {
            throw escalation();
        }

        ClubRoleTemplate tpl = null;
        if (r.template() != null) {
            tpl = ClubRoleTemplate.parse(r.template()).orElseThrow(() -> new ApiException(
                    HttpStatus.BAD_REQUEST, "INVALID_TEMPLATE", "Geçersiz yetki şablonu."));
        }
        Role newRole = r.role() != null ? r.role() : tpl != null ? tpl.role() : t.getRole();
        Set<ClubPermission> newPerms;
        if (r.permissions() != null) {
            newPerms = parsePermissions(r.permissions());
        } else if (tpl != null) {
            newPerms = tpl.permissions();
        } else if (r.role() != null) {
            newPerms = ClubRoleTemplate.defaultsFor(newRole);
        } else {
            newPerms = current.permissions();
        }

        if (newPerms.contains(ClubPermission.MANAGE_ROLES)) {
            if (me.role() != Role.OWNER) {
                throw escalation();
            }
            if (newRole != Role.ADMIN) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "MANAGE_ROLES_ADMIN_ONLY",
                        "Yetki verme yetkisi yalnızca yönetici (ADMIN) rolündeki üyeye verilebilir.");
            }
        }
        if (ClubPermissions.rank(newRole, newPerms) >= me.rank()) {
            throw escalation();
        }
        if (me.role() != Role.OWNER && !me.permissions().containsAll(newPerms)) {
            throw escalation();
        }

        t.setRole(newRole);
        members.save(t);
        // Sablonsuz ve rol varsayilaniyla ayni ise ozel kayit tutulmaz (veri sade kalir).
        if (tpl == null && newPerms.equals(ClubRoleTemplate.defaultsFor(newRole))) {
            grants.deleteMember(communityId, userId);
            grant = Optional.empty();
        } else {
            ClubMemberGrant g = grant.orElseGet(ClubMemberGrant::new);
            g.setCommunityId(communityId);
            g.setUserId(userId);
            g.setTemplate(tpl == null ? null : tpl.name());
            g.setPermissionSet(newPerms);
            g.setUpdatedBy(a.id());
            g.setUpdatedAt(Instant.now());
            grants.save(g);
            grant = Optional.of(g);
        }
        audit.record(communityId, a.id(), userId, ClubAuditService.PERMISSIONS_SET,
                "role=" + current.role() + "->" + newRole + " perms=" + names(current.permissions()) + "->" + names(newPerms));
        notifications.sendTemplated(userId, NotificationType.COMMUNITY, "notif.community.permsChanged",
                Map.of("communityId", communityId.toString()), c.getName());
        return toView(t, grant);
    }

    /** Ozel yetkileri siler; rol varsayilanlarina doner (rolu degistirmez). */
    @Transactional
    public AccessView reset(Actor a, Long communityId, Long userId) {
        Community c = community(communityId);
        Standing me = permissions.standing(a, communityId).orElseThrow(ClubRoleService::notFound);
        if (!me.has(ClubPermission.MANAGE_ROLES)) {
            throw forbidden();
        }
        CommunityMember t = target(a, communityId, userId);
        Optional<ClubMemberGrant> grant = grants.findByCommunityIdAndUserId(communityId, userId);
        Standing current = permissions.standingOf(t, grant);
        if (current.rank() >= me.rank()) {
            throw escalation();
        }
        grants.deleteMember(communityId, userId);
        audit.record(communityId, a.id(), userId, ClubAuditService.PERMISSIONS_RESET,
                "role=" + t.getRole() + " perms=" + names(current.permissions()) + "->"
                        + names(ClubRoleTemplate.defaultsFor(t.getRole())));
        notifications.sendTemplated(userId, NotificationType.COMMUNITY, "notif.community.permsChanged",
                Map.of("communityId", communityId.toString()), c.getName());
        return toView(t, Optional.empty());
    }

    // ---- ic yardimcilar ----

    private CommunityMember target(Actor a, Long communityId, Long userId) {
        if (userId.equals(a.id())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "SELF_PERMISSION_CHANGE",
                    "Kendi yetkilerinizi değiştiremezsiniz.");
        }
        CommunityMember t = activeMember(communityId, userId);
        if (t.getRole() == Role.OWNER) {
            throw new ApiException(HttpStatus.FORBIDDEN, "OWNER_PROTECTED", "Topluluk sahibinin yetkileri değiştirilemez.");
        }
        return t;
    }

    private CommunityMember activeMember(Long communityId, Long userId) {
        return members.findByCommunityIdAndUserId(communityId, userId).filter(CommunityMember::isActive)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "NOT_MEMBER",
                        "Kullanıcı bu topluluğun üyesi değil."));
    }

    private Community community(Long id) {
        return communities.findById(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "COMMUNITY_NOT_FOUND", "Topluluk bulunamadı."));
    }

    private AccessView toView(CommunityMember m, Optional<ClubMemberGrant> grant) {
        Standing s = permissions.standingOf(m, grant);
        return new AccessView(m.getUserId(), m.getRole(), s.permissions(), grant.map(ClubMemberGrant::getTemplate).orElse(null),
                grant.isPresent());
    }

    static Set<ClubPermission> parsePermissions(List<String> names) {
        Set<ClubPermission> out = EnumSet.noneOf(ClubPermission.class);
        for (String n : names) {
            out.add(ClubPermission.parse(n).orElseThrow(() -> new ApiException(HttpStatus.BAD_REQUEST,
                    "INVALID_PERMISSION", "Geçersiz yetki adı.")));
        }
        return out;
    }

    private static String names(Set<ClubPermission> s) {
        return s.isEmpty() ? "[]" : s.toString().replace(" ", "");
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "COMMUNITY_NOT_FOUND", "Topluluk bulunamadı.");
    }

    private static ApiException forbidden() {
        return new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", "Bu işlem için yetkiniz yok.");
    }

    private static ApiException escalation() {
        return new ApiException(HttpStatus.FORBIDDEN, "ESCALATION_DENIED",
                "Kendi yetkinizin üzerinde bir yetki veremez veya eşit/üst düzey bir üyeye müdahale edemezsiniz.");
    }
}
