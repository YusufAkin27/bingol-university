package edu.bingol.backend.community.permissions;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityMember.Role;
import edu.bingol.backend.community.CommunityMemberRepository;
import edu.bingol.backend.community.CommunityRepository;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.function.Executable;

import static org.junit.jupiter.api.Assertions.assertThrows;

/** Kulup yetki testleri icin ortak sahte depo kurulumu (kulup id = 10). */
final class ClubTestSupport {

    final CommunityRepository communities = mock(CommunityRepository.class);
    final CommunityMemberRepository members = mock(CommunityMemberRepository.class);
    final ClubMemberGrantRepository grants = mock(ClubMemberGrantRepository.class);
    final ClubPermissions permissions = new ClubPermissions(members, grants);

    ClubTestSupport() {
        Community c = new Community();
        c.setId(10L);
        c.setName("Kulup");
        c.setOwnerId(1L);
        c.setStatus(Community.Status.ACTIVE);
        when(communities.findById(10L)).thenReturn(Optional.of(c));
    }

    CommunityMember member(long userId, Role role) {
        return member(userId, role, CommunityMember.Status.ACTIVE);
    }

    /** Uyeyi depoya koyar ve nesneyi doner (rol degisimi nesne uzerinden gozlenir). */
    CommunityMember member(long userId, Role role, CommunityMember.Status st) {
        CommunityMember m = new CommunityMember(10L, userId, role, st);
        when(members.findByCommunityIdAndUserId(10L, userId)).thenReturn(Optional.of(m));
        return m;
    }

    /** Uyeye ozel yetki kumesi tanimlar (rol varsayilaninin yerine gecer). */
    ClubMemberGrant grant(long userId, ClubPermission... perms) {
        ClubMemberGrant g = new ClubMemberGrant();
        g.setCommunityId(10L);
        g.setUserId(userId);
        g.setPermissionSet(perms.length == 0 ? Set.of() : Set.of(perms));
        when(grants.findByCommunityIdAndUserId(10L, userId)).thenReturn(Optional.of(g));
        return g;
    }

    static ApiException error(Executable e) {
        return assertThrows(ApiException.class, e);
    }
}
