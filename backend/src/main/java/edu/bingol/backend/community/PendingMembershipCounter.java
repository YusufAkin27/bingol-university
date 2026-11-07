package edu.bingol.backend.community;

import edu.bingol.backend.community.permissions.ClubPermission;
import edu.bingol.backend.community.permissions.ClubPermissions;
import java.util.List;
import java.util.Map;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;

/**
 * Kullanicinin UYELIK BASVURUSUNU yonetme yetkisi (MANAGE_MEMBERS) olan kuluplerdeki bekleyen basvuru sayisi.
 * Hareketler (kalp) noktasi icin; yetkisi olmayan kulupler sayilmaz (yetki sunucuda).
 */
@Service
public class PendingMembershipCounter {

    private final CommunityMemberRepository members;
    private final ClubPermissions permissions;

    public PendingMembershipCounter(CommunityMemberRepository members, ClubPermissions permissions) {
        this.members = members;
        this.permissions = permissions;
    }

    public long countFor(Long userId) {
        List<Long> ids = members.activeCommunityIds(userId, PageRequest.of(0, 200));
        if (ids.isEmpty()) {
            return 0;
        }
        Map<Long, ClubPermissions.Standing> st = permissions.standingsOfUser(userId, ids);
        long total = 0;
        for (Map.Entry<Long, ClubPermissions.Standing> e : st.entrySet()) {
            if (e.getValue().has(ClubPermission.MANAGE_MEMBERS)) {
                total += members.countByCommunityIdAndStatus(e.getKey(), CommunityMember.Status.PENDING);
            }
        }
        return total;
    }
}
