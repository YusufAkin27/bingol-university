package edu.bingol.backend.community.permissions;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityMember.Role;
import edu.bingol.backend.community.extras.ClubExtrasHooks;
import edu.bingol.backend.community.permissions.ClubJoinCodeService.JoinCodeView;
import edu.bingol.backend.config.JwtProperties;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/** Kulup QR katilim kodu: imza/pencere, yetki, dogrudan uyelik, korumalar. Kulup 10. */
class ClubJoinCodeServiceTest {

    private final ClubTestSupport t = new ClubTestSupport();
    private final ClubAuditService audit = mock(ClubAuditService.class);
    private final ClubExtrasHooks hooks = mock(ClubExtrasHooks.class);
    private final ClubInviteService invites = new ClubInviteService(mock(ClubInviteRepository.class), t.communities,
            t.members, t.permissions, t.grants, audit, hooks);
    private final ClubJoinCodeService svc = new ClubJoinCodeService(
            new JwtProperties("test-secret-test-secret-test-secret-1234", 15, 30),
            t.communities, t.members, t.permissions, invites);

    // 60 sn'lik pencerenin basinda sabit bir an (1_800_000_000 / 60 tam bolunur)
    private final Instant t0 = Instant.ofEpochSecond(1_800_000_000L);
    private final Actor joiner = new Actor(7L, false);

    private static String code(Runnable r) {
        return ClubTestSupport.error(r::run).code();
    }

    @Test
    void validCodeMakesActiveMemberAndAudits() {
        String c = svc.generate(10L, t0);

        var r = svc.join(joiner, 10L, c, t0.plusSeconds(5));

        assertEquals("ACTIVE", r.status());
        ArgumentCaptor<CommunityMember> m = ArgumentCaptor.forClass(CommunityMember.class);
        verify(t.members).saveAndFlush(m.capture());
        assertEquals(7L, m.getValue().getUserId());
        assertEquals(Role.MEMBER, m.getValue().getRole());
        assertTrue(m.getValue().isActive());
        verify(hooks).onMemberActivated(10L, 7L);
        verify(audit).record(eq(10L), eq(7L), eq(7L), eq(ClubAuditService.INVITE_USED), eq("source=qr"));
    }

    @Test
    void codeWithoutPrefixAlsoWorks() {
        String c = svc.generate(10L, t0).substring(ClubJoinCodeService.PREFIX.length());
        assertEquals("ACTIVE", svc.join(joiner, 10L, c, t0).status());
    }

    @Test
    void expiresAtIsTheLastAcceptedInstant() {
        Instant now = t0.plusSeconds(17);
        String c = svc.generate(10L, now);
        Instant exp = svc.expiresAt(now);

        assertTrue(svc.verify(c, exp.minusMillis(1)) == 10L);
        assertEquals(-1L, svc.verify(c, exp));
        JoinCodeView v = svc.view(10L, now);
        assertEquals(exp, v.expiresAt());
        assertEquals(exp.getEpochSecond() - now.getEpochSecond(), v.validForSeconds());
        assertTrue(v.validForSeconds() >= 120 && v.validForSeconds() <= 180);
    }

    @Test
    void expiredCodeIsRejectedWithGenericError() {
        String c = svc.generate(10L, t0);
        assertEquals("CLUB_JOIN_CODE_INVALID", code(() -> svc.join(joiner, 10L, c, svc.expiresAt(t0))));
        verify(t.members, never()).saveAndFlush(any());
    }

    @Test
    void futureWindowCodeIsRejected() {
        String c = svc.generate(10L, t0.plusSeconds(600));
        assertEquals("CLUB_JOIN_CODE_INVALID", code(() -> svc.join(joiner, 10L, c, t0)));
    }

    @Test
    void otherClubsCodeAndTamperedSignatureAreRejected() {
        String other = svc.generate(11L, t0);
        assertEquals("CLUB_JOIN_CODE_INVALID", code(() -> svc.join(joiner, 10L, other, t0)));

        String good = svc.generate(10L, t0);
        String bad = good.substring(0, good.length() - 1) + (good.endsWith("A") ? "B" : "A");
        assertEquals("CLUB_JOIN_CODE_INVALID", code(() -> svc.join(joiner, 10L, bad, t0)));

        // kimligi degistirilmis kod (imza uymaz)
        String swapped = good.replace(":10.", ":11.");
        assertEquals(-1L, svc.verify(swapped, t0));
        assertEquals("CLUB_JOIN_CODE_INVALID", code(() -> svc.join(joiner, 10L, "bingol-clubjoin:garbage", t0)));
        assertEquals("CLUB_JOIN_CODE_INVALID", code(() -> svc.join(joiner, 10L, "x".repeat(400), t0)));
        verify(t.members, never()).saveAndFlush(any());
    }

    @Test
    void checkinStyleCodeIsNotAccepted() {
        // yoklama kodu bicimi ("id.pencere.imza") baska anahtarla imzali: kabul edilmez
        String fake = "10." + (t0.getEpochSecond() / 60) + ".AAAAAAAAAAAAAAAAAAAAAA";
        assertEquals(-1L, svc.verify(fake, t0));
    }

    @Test
    void bannedUserIsRejected() {
        t.member(7L, Role.MEMBER, CommunityMember.Status.BANNED);
        assertEquals("BANNED", code(() -> svc.join(joiner, 10L, svc.generate(10L, t0), t0)));
        verify(t.members, never()).saveAndFlush(any());
        verify(t.members, never()).save(any());
    }

    @Test
    void existingMemberGetsAlreadyWithoutSideEffects() {
        t.member(7L, Role.MEMBER);
        var r = svc.join(joiner, 10L, svc.generate(10L, t0), t0);

        assertEquals("ALREADY", r.status());
        verify(hooks, never()).onMemberActivated(anyLong(), anyLong());
        verify(audit, never()).record(anyLong(), anyLong(), anyLong(), anyString(), anyString());
    }

    @Test
    void pendingApplicationBecomesActiveMembership() {
        CommunityMember pending = t.member(7L, Role.MEMBER, CommunityMember.Status.PENDING);

        var r = svc.join(joiner, 10L, svc.generate(10L, t0), t0);

        assertEquals("ACTIVE", r.status());
        assertEquals(CommunityMember.Status.ACTIVE, pending.getStatus());
        verify(t.members).save(pending);
        verify(hooks).onMemberActivated(10L, 7L);
    }

    @Test
    void inactiveClubGivesGenericInvalid() {
        t.communities.findById(10L).get().setStatus(edu.bingol.backend.community.Community.Status.PENDING_REVIEW);
        assertEquals("CLUB_JOIN_CODE_INVALID", code(() -> svc.join(joiner, 10L, svc.generate(10L, t0), t0)));
    }

    @Test
    void concurrentDoubleJoinBecomesConflict() {
        org.mockito.Mockito.when(t.members.saveAndFlush(any()))
                .thenThrow(new org.springframework.dao.DataIntegrityViolationException("uq"));
        assertEquals("ALREADY_MEMBER", code(() -> svc.join(joiner, 10L, svc.generate(10L, t0), t0)));
    }

    // ---- kod gosterme yetkisi ----

    @Test
    void managerSeesCodeButPlainMemberAndOutsiderDoNot() {
        t.member(2L, Role.MODERATOR);
        JoinCodeView v = svc.issue(new Actor(2L, false), 10L);
        assertTrue(v.code().startsWith(ClubJoinCodeService.PREFIX));
        assertTrue(v.code().length() <= 300);
        assertTrue(v.code().matches("^[A-Za-z0-9_\\-.:]+$"));
        assertTrue(v.expiresAt().isAfter(Instant.now()));

        t.member(3L, Role.MEMBER);
        assertEquals("FORBIDDEN", code(() -> svc.issue(new Actor(3L, false), 10L)));
        assertEquals("FORBIDDEN", code(() -> svc.issue(new Actor(99L, false), 10L)));
    }

    @Test
    void memberWithManageMembersGrantSeesCode() {
        t.member(3L, Role.MEMBER);
        t.grant(3L, ClubPermission.MANAGE_MEMBERS);
        assertFalse(svc.issue(new Actor(3L, false), 10L).code().isBlank());
    }

    @Test
    void missingClubIs404AndInactiveClubIsRejected() {
        assertEquals("COMMUNITY_NOT_FOUND", code(() -> svc.issue(new Actor(1L, false), 999L)));
        t.member(1L, Role.OWNER);
        t.communities.findById(10L).get().setStatus(edu.bingol.backend.community.Community.Status.PENDING_REVIEW);
        assertEquals("COMMUNITY_NOT_ACTIVE", code(() -> svc.issue(new Actor(1L, false), 10L)));
    }
}
