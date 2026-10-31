package edu.bingol.backend.community.permissions;

import edu.bingol.backend.admin.rbac.PermissionMatrix;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityMember.Role;
import edu.bingol.backend.community.CommunityMemberRepository;
import edu.bingol.backend.community.SystemAdminAudit;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/**
 * Kulup yetki kararlarinin TEK yeri. Tum uclar (uye yonetimi, gonderi, bilgi/kapak, etkinlik, ban/cikarma, davet...)
 * buradan sorar. Etkin yetki = (uyenin ozel kumesi varsa o, yoksa rol varsayilani); OWNER ve sistem ADMIN'i her sey.
 */
@Component
public class ClubPermissions {

    /** Sistem yoneticisinin sirasi: kulup sahibinden de yuksek. */
    static final int SYSTEM_RANK = 100;

    /** Bir kisinin kulup icindeki konumu: rol, etkin yetkiler ve karsilastirma icin sira. */
    public record Standing(Role role, Set<ClubPermission> permissions, int rank) {
        public boolean has(ClubPermission p) {
            return permissions.contains(p);
        }
    }

    private final CommunityMemberRepository members;
    private final ClubMemberGrantRepository grants;

    public ClubPermissions(CommunityMemberRepository members, ClubMemberGrantRepository grants) {
        this.members = members;
        this.grants = grants;
    }

    /** T-040: sistem yoneticisi mudahalesi denetim kaydi (setter: birim testlerinde bean yok, kayit atlanir). */
    private SystemAdminAudit audit;

    @Autowired(required = false)
    public void setAudit(SystemAdminAudit audit) {
        this.audit = audit;
    }

    /**
     * Sira: rol (MEMBER 0, MODERATOR 2, ADMIN 4, OWNER 6) + ozel yetkisi olan MEMBER icin 1. Kimse kendinden dusuk
     * olmayan sirada birine mudahale edemez; ozel yetkili uye de duz uyeden ustundur.
     */
    public static int rank(Role role, Set<ClubPermission> perms) {
        return role.ordinal() * 2 + (role == Role.MEMBER && !perms.isEmpty() ? 1 : 0);
    }

    public static Standing standing(Role role, Set<ClubPermission> perms) {
        Set<ClubPermission> p = perms.isEmpty() ? EnumSet.noneOf(ClubPermission.class) : EnumSet.copyOf(perms);
        return new Standing(role, role == Role.OWNER ? ClubPermission.all() : p, rank(role, p));
    }

    /** Aktif uye ve (varsa) ozel kumesinden konum. */
    public Standing standingOf(CommunityMember m, Optional<ClubMemberGrant> grant) {
        Set<ClubPermission> perms = grant.map(ClubMemberGrant::permissionSet)
                .orElseGet(() -> ClubRoleTemplate.defaultsFor(m.getRole()));
        return standing(m.getRole(), perms);
    }

    /** Uye degilse (veya bekleyen/yasakliysa) bos; sistem ADMIN'i her kulupte tum yetkilere sahip. */
    public Optional<Standing> standing(Actor a, Long communityId) {
        // T-040: yalniz ROLE_ADMIN yetmez; kulup yonetme izni (content.write) olan profil mudahale eder
        if (a.systemAdmin(PermissionMatrix.CONTENT_WRITE)) {
            return Optional.of(new Standing(Role.OWNER, ClubPermission.all(), SYSTEM_RANK));
        }
        return standingOfUser(communityId, a.id());
    }

    /** Verilen uyelik kaydinin konumu (durumuna bakmaz; cagiran zaten kaydi cekmistir). */
    public Standing standingOfMember(CommunityMember m) {
        return standingOf(m, grants.findByCommunityIdAndUserId(m.getCommunityId(), m.getUserId()));
    }

    public Optional<Standing> standingOfUser(Long communityId, Long userId) {
        return members.findByCommunityIdAndUserId(communityId, userId).filter(CommunityMember::isActive)
                .map(m -> standingOf(m, grants.findByCommunityIdAndUserId(communityId, userId)));
    }

    public boolean has(Actor a, Long communityId, ClubPermission p) {
        return standing(a, communityId).map(s -> s.has(p)).orElse(false);
    }

    /** Yetkisi yoksa 403 FORBIDDEN; yetkiliyse konumunu doner (sira karsilastirmalari icin). */
    public Standing require(Actor a, Long communityId, ClubPermission p) {
        Standing s = standing(a, communityId).orElse(null);
        if (s == null || !s.has(p)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", "Bu işlem için yetkiniz yok.");
        }
        // Yetki yalniz sistem yoneticisi mudahalesinden geliyorsa (gercek uyelik/yetki yok) denetim kaydi yazilir
        if (a.systemAdmin(PermissionMatrix.CONTENT_WRITE)
                && !standingOfUser(communityId, a.id()).map(o -> o.has(p)).orElse(false)) {
            SystemAdminAudit.used(audit, a, "COMMUNITY", communityId, "kulup yetkisi " + p);
        }
        return s;
    }

    /** Herhangi bir yetkisi olan (yetkili) mi: denetim kaydi gibi yetkililere ozel gorunumler icin. */
    public Standing requireAnyPermission(Actor a, Long communityId) {
        Standing s = standing(a, communityId).orElse(null);
        if (s == null || s.permissions().isEmpty()) {
            throw new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", "Bu işlem için yetkiniz yok.");
        }
        return s;
    }

    /** Verilen yetkiye sahip aktif uyelerin id'leri (ornek: katilma istegi bildirimi). */
    public List<Long> holders(Long communityId, ClubPermission p) {
        Set<Long> candidates = new HashSet<>(
                members.moderatorIds(communityId, CommunityMember.Status.ACTIVE, Role.MEMBER));
        grants.findByCommunityId(communityId).forEach(g -> candidates.add(g.getUserId()));
        List<Long> out = new ArrayList<>();
        for (Long uid : candidates) {
            if (standingOfUser(communityId, uid).map(s -> s.has(p)).orElse(false)) {
                out.add(uid);
            }
        }
        return out;
    }

    /** Uye ayrildiginda/cikarildiginda ozel yetkileri de silinir. */
    public void clearGrants(Long communityId, Long userId) {
        grants.deleteMember(communityId, userId);
    }
}
