package edu.bingol.backend.community.permissions;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityMember.Role;
import edu.bingol.backend.community.permissions.ClubDtos.TransferRequest;
import edu.bingol.backend.community.permissions.ClubOwnershipTransfer.Status;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.UserRepository;
import java.time.Instant;
import java.util.Optional;
import org.junit.jupiter.api.Test;

/** Iki asamali sahiplik devri. Kulup 10; sahip = 1, hedef = 5. */
class ClubOwnershipServiceTest {

    private final ClubTestSupport t = new ClubTestSupport();
    private final ClubOwnershipTransferRepository transfers = mock(ClubOwnershipTransferRepository.class);
    private final ClubAuditService audit = mock(ClubAuditService.class);
    private final NotificationService notifications = mock(NotificationService.class);
    private final ClubOwnershipService svc = new ClubOwnershipService(t.communities, t.members, t.grants, transfers,
            audit, notifications, mock(UserRepository.class));

    private final Actor owner = new Actor(1L, false);
    private final Actor target = new Actor(5L, false);

    private static String code(Runnable r) {
        return ClubTestSupport.error(r::run).code();
    }

    private ClubOwnershipTransfer pending(boolean keepAsAdmin) {
        ClubOwnershipTransfer p = new ClubOwnershipTransfer();
        p.setId(1L);
        p.setCommunityId(10L);
        p.setFromUserId(1L);
        p.setToUserId(5L);
        p.setKeepAsAdmin(keepAsAdmin);
        p.setExpiresAt(Instant.now().plusSeconds(3600));
        when(transfers.lockByStatus(10L, Status.PENDING)).thenReturn(Optional.of(p));
        return p;
    }

    // ---- teklif ----

    @Test
    void ownerOffersTransferAndTargetIsNotified() {
        t.member(1L, Role.OWNER);
        t.member(5L, Role.MEMBER);

        svc.request(owner, 10L, new TransferRequest(5L, true, true));

        verify(transfers).save(any(ClubOwnershipTransfer.class));
        verify(audit).record(eq(10L), eq(1L), eq(5L), eq(ClubAuditService.TRANSFER_REQUESTED), anyString());
        verify(notifications).sendTemplated(eq(5L), eq(NotificationType.COMMUNITY), eq("notif.community.transferRequest"),
                any(), any(String[].class));
    }

    @Test
    void offerNeedsExplicitIrreversibleConfirmation() {
        t.member(1L, Role.OWNER);
        t.member(5L, Role.MEMBER);

        assertEquals("TRANSFER_CONFIRM_REQUIRED", code(() -> svc.request(owner, 10L, new TransferRequest(5L, true, false))));
        verify(transfers, never()).save(any());
    }

    @Test
    void onlyTheRealOwnerCanOfferNotAdminsOrSystemAdmin() {
        t.member(2L, Role.ADMIN);
        t.member(5L, Role.MEMBER);

        assertEquals("FORBIDDEN", code(() -> svc.request(new Actor(2L, false), 10L, new TransferRequest(5L, true, true))));
        assertEquals("FORBIDDEN", code(() -> svc.request(new Actor(500L, true), 10L, new TransferRequest(5L, true, true))));
    }

    @Test
    void invalidTargetsAreRejected() {
        t.member(1L, Role.OWNER);
        t.member(6L, Role.MEMBER, CommunityMember.Status.PENDING);
        t.member(7L, Role.MEMBER, CommunityMember.Status.BANNED);

        assertEquals("TRANSFER_TARGET_INVALID", code(() -> svc.request(owner, 10L, new TransferRequest(1L, true, true))));
        assertEquals("TRANSFER_TARGET_INVALID", code(() -> svc.request(owner, 10L, new TransferRequest(99L, true, true))));
        assertEquals("TRANSFER_TARGET_INVALID", code(() -> svc.request(owner, 10L, new TransferRequest(6L, true, true))));
        assertEquals("TRANSFER_TARGET_INVALID", code(() -> svc.request(owner, 10L, new TransferRequest(7L, true, true))));
    }

    @Test
    void secondPendingOfferIsRejected() {
        t.member(1L, Role.OWNER);
        t.member(5L, Role.MEMBER);
        pending(true);

        assertEquals("TRANSFER_PENDING", code(() -> svc.request(owner, 10L, new TransferRequest(5L, true, true))));
    }

    // ---- kabul ----

    @Test
    void acceptMakesTargetOwnerAndKeepsOldOwnerAsAdmin() {
        CommunityMember oldOwner = t.member(1L, Role.OWNER);
        CommunityMember newOwner = t.member(5L, Role.MODERATOR);
        pending(true);

        svc.accept(target, 10L, true);

        assertEquals(Role.OWNER, newOwner.getRole());
        assertEquals(Role.ADMIN, oldOwner.getRole());
        assertEquals(5L, t.communities.findById(10L).get().getOwnerId());
        verify(t.grants).deleteMember(10L, 5L);
        verify(t.grants).deleteMember(10L, 1L);
        verify(audit).record(eq(10L), eq(5L), eq(1L), eq(ClubAuditService.TRANSFER_ACCEPTED), anyString());
        verify(notifications).sendTemplated(eq(1L), eq(NotificationType.COMMUNITY), eq("notif.community.transferAccepted"),
                any(), any(String[].class));
    }

    @Test
    void acceptCanMakeOldOwnerLeave() {
        CommunityMember oldOwner = t.member(1L, Role.OWNER);
        t.member(5L, Role.MEMBER);
        pending(false);

        svc.accept(target, 10L, true);

        verify(t.members).delete(oldOwner);
    }

    @Test
    void acceptRequiresConfirmationAndTheTargetUser() {
        t.member(1L, Role.OWNER);
        t.member(5L, Role.MEMBER);
        t.member(6L, Role.MEMBER);
        ClubOwnershipTransfer p = pending(true);

        assertEquals("TRANSFER_CONFIRM_REQUIRED", code(() -> svc.accept(target, 10L, false)));
        assertEquals("TRANSFER_NOT_FOUND", code(() -> svc.accept(new Actor(6L, false), 10L, true)));
        assertEquals("TRANSFER_NOT_FOUND", code(() -> svc.accept(owner, 10L, true)));
        assertEquals(Status.PENDING, p.getStatus());
    }

    @Test
    void expiredOfferCannotBeAccepted() {
        t.member(1L, Role.OWNER);
        t.member(5L, Role.MEMBER);
        ClubOwnershipTransfer p = pending(true);
        p.setExpiresAt(Instant.now().minusSeconds(5));

        assertEquals("TRANSFER_NOT_FOUND", code(() -> svc.accept(target, 10L, true)));
        assertEquals(Status.EXPIRED, p.getStatus());
    }

    @Test
    void staleOfferWhenOwnerChangedIsRefused() {
        t.member(1L, Role.MODERATOR); // teklif veren artik sahip degil
        t.member(5L, Role.MEMBER);
        pending(true);

        assertEquals("TRANSFER_NOT_FOUND", code(() -> svc.accept(target, 10L, true)));
    }

    @Test
    void acceptRespectsOwnedCommunityLimit() {
        t.member(1L, Role.OWNER);
        t.member(5L, Role.MEMBER);
        pending(true);
        when(t.communities.countByOwnerIdAndStatusIn(eq(5L), any())).thenReturn(3L);

        assertEquals("COMMUNITY_LIMIT", code(() -> svc.accept(target, 10L, true)));
    }

    // ---- red / geri cekme ----

    @Test
    void targetDeclinesAndOwnerIsNotified() {
        t.member(1L, Role.OWNER);
        t.member(5L, Role.MEMBER);
        ClubOwnershipTransfer p = pending(true);

        svc.decline(target, 10L);

        assertEquals(Status.DECLINED, p.getStatus());
        verify(notifications).sendTemplated(eq(1L), eq(NotificationType.COMMUNITY), eq("notif.community.transferDeclined"),
                any(), any(String[].class));
    }

    @Test
    void onlyOwnerCancelsAndOnlyTargetDeclines() {
        t.member(1L, Role.OWNER);
        t.member(5L, Role.MEMBER);
        ClubOwnershipTransfer p = pending(true);

        assertEquals("TRANSFER_NOT_FOUND", code(() -> svc.cancel(target, 10L)));
        assertEquals("TRANSFER_NOT_FOUND", code(() -> svc.decline(owner, 10L)));
        svc.cancel(owner, 10L);
        assertEquals(Status.CANCELLED, p.getStatus());
    }

    @Test
    void pendingOfferIsVisibleOnlyToBothParties() {
        pending(true);

        assertEquals(5L, svc.pending(target, 10L).toUserId());
        assertEquals(1L, svc.pending(owner, 10L).fromUserId());
        assertEquals("TRANSFER_NOT_FOUND", code(() -> svc.pending(new Actor(9L, false), 10L)));
    }

    @Test
    void unknownCommunityIs404() {
        Community none = null;
        when(t.communities.findById(77L)).thenReturn(Optional.ofNullable(none));
        assertEquals("COMMUNITY_NOT_FOUND", code(() -> svc.pending(owner, 77L)));
    }
}
