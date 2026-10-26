package edu.bingol.backend.community.permissions;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.Hashing;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityMember.Role;
import edu.bingol.backend.community.permissions.ClubDtos.InviteCreated;
import edu.bingol.backend.community.permissions.ClubDtos.InviteRequest;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/** Davet kodlari: yetki, limit, tek seferlik/sureli kullanim, iptal. Kulup 10. */
class ClubInviteServiceTest {

    private final ClubTestSupport t = new ClubTestSupport();
    private final ClubInviteRepository invites = mock(ClubInviteRepository.class);
    private final ClubAuditService audit = mock(ClubAuditService.class);
    private final ClubInviteService svc = new ClubInviteService(invites, t.communities, t.members, t.permissions,
            t.grants, audit, mock(edu.bingol.backend.community.extras.ClubExtrasHooks.class));

    private final Actor mod = new Actor(2L, false);
    private final Actor joiner = new Actor(7L, false);

    private static String code(Runnable r) {
        return ClubTestSupport.error(r::run).code();
    }

    private ClubInvite invite(String plain) {
        ClubInvite i = new ClubInvite();
        i.setId(3L);
        i.setCommunityId(10L);
        i.setCodeHash(Hashing.sha256(plain));
        i.setCodeHint(plain.substring(plain.length() - 3));
        i.setCreatedBy(2L);
        i.setExpiresAt(Instant.now().plusSeconds(3600));
        when(invites.findByCodeHash(Hashing.sha256(plain))).thenReturn(Optional.of(i));
        return i;
    }

    // ---- uretme / listeleme / iptal ----

    @Test
    void moderatorCreatesInviteAndOnlyHashIsStored() {
        t.member(2L, Role.MODERATOR);

        InviteCreated c = svc.create(mod, 10L, new InviteRequest(5, 24));

        assertEquals(10, c.code().length());
        ArgumentCaptor<ClubInvite> saved = ArgumentCaptor.forClass(ClubInvite.class);
        verify(invites).save(saved.capture());
        assertEquals(Hashing.sha256(c.code()), saved.getValue().getCodeHash());
        assertNotEquals(c.code(), saved.getValue().getCodeHash());
        assertEquals(Integer.valueOf(5), saved.getValue().getMaxUses());
        assertTrue(saved.getValue().getExpiresAt().isAfter(Instant.now().plusSeconds(23 * 3600)));
        verify(audit).record(eq(10L), eq(2L), isNull(), eq(ClubAuditService.INVITE_CREATED), anyString());
    }

    @Test
    void plainMemberCannotCreateListOrRevoke() {
        t.member(3L, Role.MEMBER);
        Actor member = new Actor(3L, false);

        assertEquals("FORBIDDEN", code(() -> svc.create(member, 10L, new InviteRequest(null, null))));
        assertEquals("FORBIDDEN", code(() -> svc.list(member, 10L)));
        assertEquals("FORBIDDEN", code(() -> svc.revoke(member, 10L, 3L)));
        verify(invites, never()).save(any());
    }

    @Test
    void memberWithInviteGrantCanCreate() {
        t.member(3L, Role.MEMBER);
        t.grant(3L, ClubPermission.INVITE);

        svc.create(new Actor(3L, false), 10L, new InviteRequest(null, null));

        verify(invites).save(any(ClubInvite.class));
    }

    @Test
    void activeInviteLimitIsEnforced() {
        t.member(2L, Role.MODERATOR);
        when(invites.countActive(eq(10L), any())).thenReturn((long) ClubInviteService.MAX_ACTIVE);

        assertEquals("INVITE_LIMIT", code(() -> svc.create(mod, 10L, new InviteRequest(null, null))));
    }

    @Test
    void listShowsStatesWithoutRevealingCodes() {
        t.member(2L, Role.MODERATOR);
        ClubInvite active = invite("AAAAAAAAAA");
        ClubInvite revoked = invite("BBBBBBBBBB");
        revoked.setRevoked(true);
        ClubInvite used = invite("CCCCCCCCCC");
        used.setMaxUses(1);
        used.setUsedCount(1);
        ClubInvite expired = invite("DDDDDDDDDD");
        expired.setExpiresAt(Instant.now().minusSeconds(1));
        when(invites.findByCommunityIdOrderByIdDesc(10L)).thenReturn(List.of(active, revoked, used, expired));

        var states = svc.list(mod, 10L).stream().map(v -> v.state()).toList();

        assertEquals(List.of("ACTIVE", "REVOKED", "USED_UP", "EXPIRED"), states);
        assertTrue(svc.list(mod, 10L).get(0).codeHint().startsWith("..."));
    }

    @Test
    void revokeMarksInviteAndUnknownIs404() {
        t.member(2L, Role.MODERATOR);
        ClubInvite i = invite("AAAAAAAAAA");
        when(invites.findByIdAndCommunityId(3L, 10L)).thenReturn(Optional.of(i));

        svc.revoke(mod, 10L, 3L);

        assertTrue(i.isRevoked());
        assertEquals("INVITE_NOT_FOUND", code(() -> svc.revoke(mod, 10L, 99L)));
    }

    // ---- kodla katilim ----

    @Test
    void validCodeJoinsEvenApprovalCommunityAsActiveMember() {
        invite("ABCDEFGHJK");
        when(invites.consume(eq(3L), any())).thenReturn(1);

        var r = svc.join(joiner, "abcde-fghjk");

        assertEquals("ACTIVE", r.status());
        ArgumentCaptor<CommunityMember> m = ArgumentCaptor.forClass(CommunityMember.class);
        verify(t.members).save(m.capture());
        assertEquals(7L, m.getValue().getUserId());
        assertEquals(Role.MEMBER, m.getValue().getRole());
        assertTrue(m.getValue().isActive());
        verify(audit).record(eq(10L), eq(7L), eq(7L), eq(ClubAuditService.INVITE_USED), anyString());
    }

    @Test
    void unknownExhaustedExpiredOrRevokedCodesAllGiveSameError() {
        // bilinmeyen
        assertEquals("INVITE_INVALID", code(() -> svc.join(joiner, "ZZZZZZZZZZ")));
        // tuketilmis/sureli/iptal: atomik UPDATE 0 satir etkiler
        invite("ABCDEFGHJK");
        when(invites.consume(anyLong(), any())).thenReturn(0);
        assertEquals("INVITE_INVALID", code(() -> svc.join(joiner, "ABCDEFGHJK")));
        verify(t.members, never()).save(any());
    }

    @Test
    void bannedUserCannotUseInviteAndCodeIsNotConsumed() {
        invite("ABCDEFGHJK");
        t.member(7L, Role.MEMBER, CommunityMember.Status.BANNED);

        assertEquals("BANNED", code(() -> svc.join(joiner, "ABCDEFGHJK")));
        verify(invites, never()).consume(anyLong(), any());
    }

    @Test
    void existingMemberKeepsCodeUnconsumed() {
        invite("ABCDEFGHJK");
        t.member(7L, Role.MEMBER);

        assertEquals("ALREADY_MEMBER", code(() -> svc.join(joiner, "ABCDEFGHJK")));
        verify(invites, never()).consume(anyLong(), any());
    }

    @Test
    void pendingRequestIsUpgradedToActive() {
        invite("ABCDEFGHJK");
        CommunityMember pending = t.member(7L, Role.MEMBER, CommunityMember.Status.PENDING);
        when(invites.consume(eq(3L), any())).thenReturn(1);

        svc.join(joiner, "ABCDEFGHJK");

        assertEquals(CommunityMember.Status.ACTIVE, pending.getStatus());
    }

    @Test
    void inactiveCommunityHidesInvite() {
        invite("ABCDEFGHJK");
        t.communities.findById(10L).get().setStatus(edu.bingol.backend.community.Community.Status.HIDDEN);

        assertEquals("INVITE_INVALID", code(() -> svc.join(joiner, "ABCDEFGHJK")));
    }

    @Test
    void generatedCodesAreUniqueLookingAndUnambiguous() {
        String a = ClubInviteService.newCode();
        String b = ClubInviteService.newCode();
        assertNotEquals(a, b);
        assertFalse(a.matches(".*[01OIl].*"));
    }
}
