package edu.bingol.backend.community.admin;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMemberRepository;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.community.dto.CommunityDtos.UpdateCommunityRequest;
import edu.bingol.backend.community.extras.ClubExtrasHooks;
import edu.bingol.backend.community.permissions.ClubAuditService;
import edu.bingol.backend.community.permissions.ClubMemberGrantRepository;
import edu.bingol.backend.community.permissions.ClubPermissions;
import edu.bingol.backend.media.MediaService;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.moderation.profanity.ContentGuard;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.user.UserRepository;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

/** Yonetici duzenlemesinde kufur suzgeci atlanir; normal (sahip) duzenlemede uygulanir; yonetici olmayan adminUpdate yapamaz. */
class AdminUpdateGuardTest {

    private final CommunityRepository communities = mock(CommunityRepository.class);
    private final CommunityMemberRepository members = mock(CommunityMemberRepository.class);
    private final ContentGuard guard = mock(ContentGuard.class);
    private final CommunityService svc = new CommunityService(communities, members, mock(UserRepository.class),
            mock(BlockService.class), mock(NotificationService.class), mock(MediaService.class),
            new ClubPermissions(members, mock(ClubMemberGrantRepository.class)), mock(ClubAuditService.class),
            mock(ClubExtrasHooks.class));

    AdminUpdateGuardTest() {
        ReflectionTestUtils.setField(svc, "guard", guard);
        Community c = new Community();
        c.setId(10L);
        c.setName("Kulup");
        c.setOwnerId(99L);
        c.setStatus(Community.Status.ACTIVE);
        when(communities.findById(10L)).thenReturn(Optional.of(c));
    }

    @Test
    void adminUpdateSkipsProfanityGuardButAppliesFields() {
        svc.adminUpdate(new Actor(1L, true), 10L, new UpdateCommunityRequest("Yeni Kulup Adi", "yeni aciklama", null, null, null));

        verify(guard, never()).assertChanged(any(), anyString(), anyLong(), any(), any());
        verify(guard, never()).assertClean(any(), anyString(), anyLong(), any());
        verify(communities).save(any(Community.class));
        assertEquals("Yeni Kulup Adi", communities.findById(10L).orElseThrow().getName());
    }

    @Test
    void ownerUpdateStillGoesThroughTheGuard() {
        when(members.findByCommunityIdAndUserId(10L, 99L)).thenReturn(Optional.of(
                new edu.bingol.backend.community.CommunityMember(10L, 99L, edu.bingol.backend.community.CommunityMember.Role.OWNER,
                        edu.bingol.backend.community.CommunityMember.Status.ACTIVE)));

        svc.update(new Actor(99L, false), 10L, new UpdateCommunityRequest("Baska Ad", null, null, null, null));

        verify(guard).assertChanged(eq(ContentGuard.Entity.CLUB), eq("name"), eq(99L), eq("Kulup"), eq("Baska Ad"));
    }

    @Test
    void adminUpdateRefusesNonAdminActor() {
        ApiException e = assertThrows(ApiException.class,
                () -> svc.adminUpdate(new Actor(99L, false), 10L, new UpdateCommunityRequest("Ad Degisti", null, null, null, null)));
        assertEquals("FORBIDDEN", e.code());
    }
}
