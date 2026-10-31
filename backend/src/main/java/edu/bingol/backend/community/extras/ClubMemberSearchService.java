package edu.bingol.backend.community.extras;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.community.Paging;
import edu.bingol.backend.community.Texts;
import edu.bingol.backend.community.dto.CommunityDtos.MemberView;
import edu.bingol.backend.community.permissions.ClubPermission;
import edu.bingol.backend.community.permissions.ClubPermissions;
import edu.bingol.backend.user.User;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Uye listesi filtresi/aramasi: rol, durum ve ad. ACTIVE listesini okunabilir her kulupte uyeler (ve ADMIN) gorur;
 * PENDING/BANNED listeleri yalnizca MANAGE_MEMBERS yetkililerine aciktir.
 */
@Service
public class ClubMemberSearchService {

    private final CommunityService communities;
    private final ClubMemberQueryRepository query;
    private final ClubPermissions permissions;

    public ClubMemberSearchService(CommunityService communities, ClubMemberQueryRepository query,
                                   ClubPermissions permissions) {
        this.communities = communities;
        this.query = query;
        this.permissions = permissions;
    }

    @Transactional(readOnly = true)
    public CursorPage<MemberView> search(Actor a, Long cid, String q, String role, String status, Long cursor, int size) {
        Community c = communities.loadVisible(a, cid);
        CommunityMember.Status st = parse(CommunityMember.Status.class, status, CommunityMember.Status.ACTIVE);
        CommunityMember.Role rl = parse(CommunityMember.Role.class, role, null);
        if (st == CommunityMember.Status.ACTIVE) {
            communities.requireReadable(a, c);
        } else {
            permissions.require(a, cid, ClubPermission.MANAGE_MEMBERS);
        }
        String pattern = Texts.likePattern(q != null && q.length() > 100 ? q.substring(0, 100) : q);
        Set<Long> excluded = st == CommunityMember.Status.ACTIVE ? communities.blockedFor(a) : Set.of(-1L);
        int s = CursorPage.clampSize(size);
        List<CommunityMember> rows = query.filtered(cid, st, rl == null, rl == null ? CommunityMember.Role.MEMBER : rl,
                pattern, Paging.ascStart(cursor), excluded, PageRequest.of(0, s + 1));
        Set<Long> hideAvatar = communities.blockedFor(a);
        return Paging.map(rows, s, CommunityMember::getId, items -> {
            Map<Long, User> users = communities.usersById(items.stream().map(CommunityMember::getUserId).toList());
            Map<Long, CommunityService.ProfileExtra> extras = communities.profileExtras(a.id(), users.values(), hideAvatar);
            Map<Long, String> avatars = communities.avatarsFor(a.id(), users.values(), hideAvatar); // T-027
            return items.stream().map(m -> {
                User u = users.get(m.getUserId());
                CommunityService.ProfileExtra pe = extras.getOrDefault(m.getUserId(), CommunityService.ProfileExtra.NONE);
                return new MemberView(m.getUserId(), u == null ? "Kullanıcı" : u.getDisplayName(),
                        avatars.get(m.getUserId()), m.getRole(), m.getJoinedAt(),
                        pe.department(), pe.classYear());
            }).toList();
        });
    }

    static <E extends Enum<E>> E parse(Class<E> type, String raw, E dflt) {
        if (raw == null || raw.isBlank()) {
            return dflt;
        }
        try {
            return Enum.valueOf(type, raw.trim().toUpperCase(java.util.Locale.ROOT));
        } catch (IllegalArgumentException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz filtre değeri.");
        }
    }
}
