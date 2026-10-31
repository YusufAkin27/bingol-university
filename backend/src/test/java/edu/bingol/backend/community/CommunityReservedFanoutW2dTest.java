package edu.bingol.backend.community;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.dto.CommunityDtos.CreateCommunityRequest;
import edu.bingol.backend.community.extras.ClubExtrasHooks;
import edu.bingol.backend.community.permissions.ClubAuditService;
import edu.bingol.backend.community.permissions.ClubMemberGrantRepository;
import edu.bingol.backend.community.permissions.ClubPermissions;
import edu.bingol.backend.media.MediaService;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.UserRepository;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;

/** T-052 (kurum taklidi kulup adi PENDING_REVIEW) ve T-051 (kulup silme bildirimi 500'de kesilmez). */
class CommunityReservedFanoutW2dTest {

    private final CommunityRepository communities = mock(CommunityRepository.class);
    private final CommunityMemberRepository members = mock(CommunityMemberRepository.class);
    private final NotificationService notifications = mock(NotificationService.class);
    private final ClubExtrasHooks hooks = mock(ClubExtrasHooks.class);
    private final CommunityService svc = new CommunityService(communities, members, mock(UserRepository.class),
            mock(BlockService.class), notifications, mock(MediaService.class),
            new ClubPermissions(members, mock(ClubMemberGrantRepository.class)), mock(ClubAuditService.class), hooks);

    private final Actor user = new Actor(1L, false);

    private Community create(String name) {
        svc.setAutoApprove(true); // varsayilan uretim davranisi: temiz ad aninda yayinda
        when(communities.countByOwnerIdAndStatusIn(eq(1L), any())).thenReturn(0L);
        org.mockito.Mockito.doAnswer(i -> {
            Community c = i.getArgument(0);
            c.setId(10L);
            return c;
        }).when(communities).saveAndFlush(any());
        return svc.create(user, new CreateCommunityRequest(name, "aciklama", null, null, null));
    }

    @Test
    void impersonatingClubNamesAreHeldForReviewCleanNamesGoLive() {
        assertEquals(Community.Status.PENDING_REVIEW, create("Bingöl Üniversitesi Rektörlüğü").getStatus());
        assertEquals(Community.Status.PENDING_REVIEW, create("BU Kampus Resmi Duyuru").getStatus());
        assertEquals(Community.Status.ACTIVE, create("Yazılım Kulübü").getStatus());
        verify(hooks, times(1)).onCommunityActivated(any()); // yalniz temiz ad odayi kurar
    }

    @Test
    void invisibleOrBidiCharactersInClubNameAreRejected() {
        svc.setAutoApprove(true);
        ApiException e = assertThrows(ApiException.class,
                () -> svc.create(user, new CreateCommunityRequest("Yaz​ilim Kulubu", null, null, null, null)));
        assertEquals("INVALID_DISPLAY_NAME", e.code());
        verify(communities, never()).saveAndFlush(any());
    }

    @Test
    void renamingLiveClubToInstitutionNameIsRejected() {
        Community c = new Community();
        c.setId(10L);
        c.setName("Satranc Kulubu");
        c.setOwnerId(1L);
        c.setStatus(Community.Status.ACTIVE);
        when(communities.findById(10L)).thenReturn(Optional.of(c));
        when(members.findByCommunityIdAndUserId(10L, 1L))
                .thenReturn(Optional.of(new CommunityMember(10L, 1L, CommunityMember.Role.OWNER, CommunityMember.Status.ACTIVE)));

        ApiException e = assertThrows(ApiException.class, () -> svc.update(user, 10L,
                new edu.bingol.backend.community.dto.CommunityDtos.UpdateCommunityRequest("Rektörlük Duyuru", null, null, null, null)));

        assertEquals("RESERVED_DISPLAY_NAME", e.code());
        assertEquals("Satranc Kulubu", c.getName());
    }

    @Test
    void deletingBigClubNotifiesAllMembersBeyond500() {
        Community c = new Community();
        c.setId(10L);
        c.setName("Buyuk Kulup");
        c.setOwnerId(1L);
        c.setStatus(Community.Status.ACTIVE);
        when(communities.findById(10L)).thenReturn(Optional.of(c));
        when(communities.saveAndFlush(any())).thenAnswer(i -> i.getArgument(0));
        List<Long> first = new ArrayList<>();
        for (long i = 1001; i < 1501; i++) {
            first.add(i);
        }
        List<Long> second = new ArrayList<>();
        for (long i = 1501; i < 1701; i++) {
            second.add(i);
        }
        when(members.userIdsByStatusAfter(eq(10L), eq(CommunityMember.Status.ACTIVE), eq(0L), any())).thenReturn(first);
        when(members.userIdsByStatusAfter(eq(10L), eq(CommunityMember.Status.ACTIVE), eq(1500L), any())).thenReturn(second);

        svc.delete(user, 10L);

        verify(notifications, times(700)).sendTemplated(anyLong(), eq(NotificationType.COMMUNITY),
                eq("notif.community.deleted"), anyMap(), eq("Buyuk Kulup"));
    }

    @Test
    void forEachChunkWalksAllPagesAndReportsTruncation() {
        List<Long> seen = new ArrayList<>();
        boolean truncated = Paging.forEachChunk((after, n) -> {
            List<Long> out = new ArrayList<>();
            for (long i = after + 1; i <= after + n && i <= 1200; i++) {
                out.add(i);
            }
            return out;
        }, seen::addAll);
        assertFalse(truncated);
        assertEquals(1200, seen.size());

        seen.clear();
        boolean cut = Paging.forEachChunk((after, n) -> {
            List<Long> out = new ArrayList<>();
            for (long i = after + 1; i <= after + n; i++) { // sonsuz kaynak
                out.add(i);
            }
            return out;
        }, seen::addAll);
        assertTrue(cut);
        assertEquals(Paging.FANOUT_CAP, seen.size());
    }
}
