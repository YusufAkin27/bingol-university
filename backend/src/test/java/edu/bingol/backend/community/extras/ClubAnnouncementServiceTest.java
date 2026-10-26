package edu.bingol.backend.community.extras;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember.Role;
import edu.bingol.backend.community.CommunityPost;
import edu.bingol.backend.community.extras.ClubExtrasDtos.AnnouncementView;
import edu.bingol.backend.community.permissions.ClubAuditService;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpStatus;

/** Duyuru: yetki, gunluk sinir, hedef kitle (aktif uyeler, engel haric), denetim kaydi. */
class ClubAnnouncementServiceTest {

    private final ClubExtrasTestSupport t = new ClubExtrasTestSupport();
    private final ClubAnnouncementRepository repo = mock(ClubAnnouncementRepository.class);
    private final ClubMemberQueryRepository memberQuery = mock(ClubMemberQueryRepository.class);
    private final ClubAuditService audit = mock(ClubAuditService.class);
    private final BlockService blocks = mock(BlockService.class);
    private final NotificationService notifications = mock(NotificationService.class);
    private final ClubAnnouncementService svc = new ClubAnnouncementService(t.communities, t.communityRepo, repo,
            memberQuery, t.permissions, audit, blocks, notifications);

    private final Actor mod = new Actor(2L, false);
    private final Actor plain = new Actor(3L, false);

    private void stubSave() {
        when(repo.save(any())).thenAnswer(i -> {
            CommunityPost p = i.getArgument(0);
            p.setId(55L);
            return p;
        });
    }

    @Test
    void plainMemberCannotAnnounce() {
        t.member(3L, Role.MEMBER);

        assertEquals(HttpStatus.FORBIDDEN, ClubExtrasTestSupport.error(() -> svc.create(plain, 10L, "merhaba")).status());
        verify(repo, never()).save(any());
        verify(notifications, never()).sendTemplated(anyLong(), any(), anyString(), any(), any(String[].class));
    }

    @Test
    void nonMemberCannotAnnounceEvenWhenKnowingTheClub() {
        assertEquals(HttpStatus.FORBIDDEN, ClubExtrasTestSupport.error(() -> svc.create(plain, 10L, "merhaba")).status());
    }

    @Test
    void notYetPublishedClubRejects() {
        t.member(2L, Role.MODERATOR);
        t.club.setStatus(Community.Status.PENDING_REVIEW);

        assertEquals("COMMUNITY_NOT_ACTIVE", ClubExtrasTestSupport.error(() -> svc.create(mod, 10L, "x")).code());
    }

    @Test
    void blankTextRejected() {
        t.member(2L, Role.MODERATOR);

        assertEquals("VALIDATION_ERROR", ClubExtrasTestSupport.error(() -> svc.create(mod, 10L, "   ")).code());
    }

    @Test
    void fourthAnnouncementInADayIsRejected() {
        t.member(2L, Role.MODERATOR);
        when(repo.countSince(eq(10L), any())).thenReturn(3L);

        var e = ClubExtrasTestSupport.error(() -> svc.create(mod, 10L, "duyuru"));

        assertEquals("ANNOUNCEMENT_LIMIT", e.code());
        assertEquals(HttpStatus.TOO_MANY_REQUESTS, e.status());
        assertEquals("3", e.args()[0]);
        verify(repo, never()).save(any());
        verify(notifications, never()).sendTemplated(anyLong(), any(), anyString(), any(), any(String[].class));
    }

    @Test
    void thirdAnnouncementStillPassesAndRowIsLocked() {
        t.member(2L, Role.MODERATOR);
        when(repo.countSince(eq(10L), any())).thenReturn(2L);
        stubSave();

        svc.create(mod, 10L, "duyuru");

        verify(t.communityRepo).lockById(10L);
        verify(repo).save(any());
    }

    @Test
    void notifiesActiveMembersExceptAuthorAndBlockRelated() {
        t.member(2L, Role.MODERATOR);
        stubSave();
        when(repo.countSince(eq(10L), any())).thenReturn(0L);
        when(memberQuery.activeUserIdsAfter(eq(10L), eq(0L), any())).thenReturn(List.of(1L, 2L, 3L, 4L, 5L));
        when(blocks.hiddenFrom(2L)).thenReturn(Set.of(4L));

        AnnouncementView v = svc.create(mod, 10L, "  Toplanti yarin  ");

        assertEquals("Toplanti yarin", v.text());
        assertEquals(55L, v.id());
        ArgumentCaptor<Long> to = ArgumentCaptor.forClass(Long.class);
        verify(notifications, org.mockito.Mockito.times(3)).sendTemplated(to.capture(), eq(NotificationType.COMMUNITY),
                eq("notif.community.announcement"), any(), eq("Kulup"), eq("Toplanti yarin"));
        assertEquals(List.of(1L, 3L, 5L), to.getAllValues());
        verify(audit).record(10L, 2L, null, ClubAuditService.ANNOUNCEMENT_POSTED, "post=55");
    }

    @Test
    void savedPostIsMarkedAsAnnouncement() {
        t.member(2L, Role.MODERATOR);
        stubSave();

        svc.create(mod, 10L, "x");

        ArgumentCaptor<CommunityPost> cc = ArgumentCaptor.forClass(CommunityPost.class);
        verify(repo).save(cc.capture());
        assertTrue(cc.getValue().isAnnouncement());
        assertEquals(2L, cc.getValue().getAuthorId());
    }

    @Test
    void longTextPreviewIsCut() {
        assertEquals(120, ClubAnnouncementService.preview("a".repeat(500)).length());
        assertEquals("kisa", ClubAnnouncementService.preview("kisa"));
    }
}
