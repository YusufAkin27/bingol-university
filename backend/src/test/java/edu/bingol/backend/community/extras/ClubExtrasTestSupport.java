package edu.bingol.backend.community.extras;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityMember.Role;
import edu.bingol.backend.community.CommunityMemberRepository;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.community.permissions.ClubMemberGrantRepository;
import edu.bingol.backend.community.permissions.ClubPermissions;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.function.Executable;

import static org.junit.jupiter.api.Assertions.assertThrows;

/** Kulup ekstralari testleri icin ortak kurulum (kulup id = 10, ACTIVE, PUBLIC, OPEN). Gercek ClubPermissions. */
final class ClubExtrasTestSupport {

    final Community club = new Community();
    final CommunityService communities = mock(CommunityService.class);
    final CommunityRepository communityRepo = mock(CommunityRepository.class);
    final CommunityMemberRepository members = mock(CommunityMemberRepository.class);
    final ClubMemberGrantRepository grants = mock(ClubMemberGrantRepository.class);
    final ClubPermissions permissions = new ClubPermissions(members, grants);

    ClubExtrasTestSupport() {
        club.setId(10L);
        club.setName("Kulup");
        club.setOwnerId(1L);
        club.setStatus(Community.Status.ACTIVE);
        when(communities.load(10L)).thenReturn(club);
        when(communities.loadVisible(any(), org.mockito.ArgumentMatchers.eq(10L))).thenReturn(club);
        when(communities.usersById(any())).thenReturn(Map.of());
    }

    CommunityMember member(long userId, Role role) {
        return member(userId, role, CommunityMember.Status.ACTIVE);
    }

    CommunityMember member(long userId, Role role, CommunityMember.Status st) {
        CommunityMember m = new CommunityMember(10L, userId, role, st);
        when(members.findByCommunityIdAndUserId(10L, userId)).thenReturn(Optional.of(m));
        return m;
    }

    static ApiException error(Executable e) {
        return assertThrows(ApiException.class, e);
    }

}
