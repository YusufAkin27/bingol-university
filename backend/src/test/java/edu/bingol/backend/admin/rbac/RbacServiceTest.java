package edu.bingol.backend.admin.rbac;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.admin.rbac.RbacDtos.ChangeView;
import edu.bingol.backend.auth.jwt.JwtService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.AdminProperties;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

/** Profil atama kurallari (P16): kendi profili, sabitli hesap, son FULL, iki kisi onayi, sure dolumu, bayat oneri. */
class RbacServiceTest {

    private static final Instant T0 = Instant.parse("2026-10-28T10:00:00Z");

    private final UserRepository users = mock(UserRepository.class);
    private final AdminProfileChangeRepository changes = mock(AdminProfileChangeRepository.class);
    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    @SuppressWarnings("unchecked")
    private final ValueOperations<String, String> ops = mock(ValueOperations.class);
    private final JwtService jwt = mock(JwtService.class);
    private final AdminProfileResolver resolver =
            new AdminProfileResolver(users, new AdminProperties(List.of("pinli@bingol.edu.tr")));
    private Clock clock = Clock.fixed(T0, ZoneOffset.UTC);
    private final RbacService service = new RbacService(users, changes, resolver, redis, jwt, new Clock() {
        @Override public java.time.ZoneId getZone() { return ZoneOffset.UTC; }
        @Override public Clock withZone(java.time.ZoneId zone) { return this; }
        @Override public Instant instant() { return clock.instant(); }
    });

    RbacServiceTest() {
        when(redis.opsForValue()).thenReturn(ops);
        when(jwt.accessTtl()).thenReturn(Duration.ofMinutes(15));
        when(users.countFullAdmins()).thenReturn(2L);
        when(changes.save(any())).thenAnswer(i -> {
            AdminProfileChange c = i.getArgument(0);
            if (c.getId() == null) {
                c.setId(77L);
            }
            return c;
        });
    }

    private User admin(long id, String email, AdminProfile profile) {
        User u = new User();
        u.setId(id);
        u.setEmail(email);
        u.setDisplayName("Yonetici " + id);
        u.setRole(Role.ADMIN);
        u.setStatus(UserStatus.ACTIVE);
        u.setAdminProfile(profile);
        when(users.findById(id)).thenReturn(Optional.of(u));
        return u;
    }

    private static String code(Runnable r) {
        return assertThrows(ApiException.class, r::run).code();
    }

    // --- dogrudan atama ---

    @Test
    void directAssignmentBetweenNonFullProfilesWorksAndMarksOldTokens() {
        User t = admin(5, "a@bingol.edu.tr", AdminProfile.VIEWER);

        AdminProfile before = service.setProfile(1L, 5L, AdminProfile.MODERATOR);

        assertEquals(AdminProfile.VIEWER, before);
        assertEquals(AdminProfile.MODERATOR, t.getAdminProfile());
        verify(users).save(t);
        verify(ops).set(eq("rolechg:5"), anyString(), any(Duration.class));
    }

    @Test
    void selfChangeIsRejected() {
        admin(1, "ben@bingol.edu.tr", AdminProfile.FULL);
        assertEquals("RBAC_SELF_CHANGE", code(() -> service.setProfile(1L, 1L, AdminProfile.VIEWER)));
        assertEquals("RBAC_SELF_CHANGE", code(() -> service.propose(1L, 1L, AdminProfile.VIEWER, "sebep var")));
        verify(users, never()).save(any());
    }

    @Test
    void pinnedAccountCannotBeChanged() {
        admin(5, "Pinli@bingol.edu.tr", AdminProfile.FULL);
        assertEquals("ADMIN_EMAIL_PINNED", code(() -> service.setProfile(1L, 5L, AdminProfile.VIEWER)));
        assertEquals("ADMIN_EMAIL_PINNED", code(() -> service.propose(1L, 5L, AdminProfile.VIEWER, "sebep var")));
    }

    @Test
    void nonAdminAndNoopAreRejected() {
        User u = admin(5, "u@bingol.edu.tr", AdminProfile.EDITOR);
        assertEquals("RBAC_NO_CHANGE", code(() -> service.setProfile(1L, 5L, AdminProfile.EDITOR)));
        u.setRole(Role.USER);
        assertEquals("RBAC_TARGET_NOT_ADMIN", code(() -> service.setProfile(1L, 5L, AdminProfile.VIEWER)));
        when(users.findById(9L)).thenReturn(Optional.empty());
        assertEquals("USER_NOT_FOUND", code(() -> service.setProfile(1L, 9L, AdminProfile.VIEWER)));
    }

    @Test
    void legacyAdminWithoutStoredProfileCountsAsFull() {
        User t = admin(5, "eski@bingol.edu.tr", null);
        // FULL'dan dusurme dogrudan yapilamaz
        assertEquals("RBAC_APPROVAL_REQUIRED", code(() -> service.setProfile(1L, 5L, AdminProfile.VIEWER)));
        assertNull(t.getAdminProfile());
    }

    @Test
    void makingSomeoneFullOrDemotingFullNeedsTwoPersonApproval() {
        admin(5, "v@bingol.edu.tr", AdminProfile.VIEWER);
        admin(6, "f@bingol.edu.tr", AdminProfile.FULL);
        assertEquals("RBAC_APPROVAL_REQUIRED", code(() -> service.setProfile(1L, 5L, AdminProfile.FULL)));
        assertEquals("RBAC_APPROVAL_REQUIRED", code(() -> service.setProfile(1L, 6L, AdminProfile.SUPPORT)));
    }

    @Test
    void proposalOnlyForApprovalCasesAndNotWhenOnePending() {
        admin(5, "v@bingol.edu.tr", AdminProfile.VIEWER);
        assertEquals("RBAC_APPROVAL_NOT_NEEDED",
                code(() -> service.propose(1L, 5L, AdminProfile.EDITOR, "dogrudan yapilabilir")));

        when(changes.existsByTargetUserIdAndStatus(5L, AdminProfileChange.Status.PENDING)).thenReturn(true);
        assertEquals("RBAC_CHANGE_PENDING", code(() -> service.propose(1L, 5L, AdminProfile.FULL, "yeni FULL")));
    }

    @Test
    void lastFullAdminCannotBeDemoted() {
        admin(6, "f@bingol.edu.tr", AdminProfile.FULL);
        when(users.countFullAdmins()).thenReturn(1L);
        assertEquals("RBAC_LAST_FULL", code(() -> service.propose(1L, 6L, AdminProfile.SUPPORT, "son FULL dusuyor")));
        verify(users).lockAdminIds();
    }

    // --- iki kisi onayi ---

    private AdminProfileChange pendingChange(long proposer, long target, AdminProfile from, AdminProfile to) {
        AdminProfileChange c = new AdminProfileChange();
        c.setId(77L);
        c.setTargetUserId(target);
        c.setFromProfile(from);
        c.setToProfile(to);
        c.setReason("test sebebi");
        c.setProposedBy(proposer);
        c.setProposedAt(T0);
        c.setExpiresAt(T0.plus(RbacService.CHANGE_TTL));
        when(changes.findForUpdate(77L)).thenReturn(Optional.of(c));
        return c;
    }

    @Test
    void proposalIsCreatedWith24HourExpiry() {
        admin(1, "a@bingol.edu.tr", AdminProfile.FULL);
        admin(5, "v@bingol.edu.tr", AdminProfile.VIEWER);

        ChangeView v = service.propose(1L, 5L, AdminProfile.FULL, "  ikinci FULL gerekli  ");

        assertEquals("PENDING", v.status());
        assertEquals(AdminProfile.VIEWER, v.fromProfile());
        assertEquals(AdminProfile.FULL, v.toProfile());
        assertEquals("ikinci FULL gerekli", v.reason());
        assertEquals(T0.plus(Duration.ofHours(24)).toString(), v.expiresAt());
    }

    @Test
    void proposerCannotApproveButSecondFullCan() {
        User target = admin(5, "v@bingol.edu.tr", AdminProfile.VIEWER);
        admin(1, "a@bingol.edu.tr", AdminProfile.FULL);
        admin(2, "b@bingol.edu.tr", AdminProfile.FULL);
        AdminProfileChange c = pendingChange(1, 5, AdminProfile.VIEWER, AdminProfile.FULL);

        assertEquals("RBAC_SAME_APPROVER", code(() -> service.approve(1L, 77L, null)));
        assertEquals(AdminProfile.VIEWER, target.getAdminProfile());

        ChangeView v = service.approve(2L, 77L, "tamam");

        assertEquals("APPROVED", v.status());
        assertEquals(AdminProfile.FULL, target.getAdminProfile());
        assertEquals(AdminProfileChange.Status.APPROVED, c.getStatus());
        assertEquals(2L, c.getDecidedBy());
        verify(ops).set(eq("rolechg:5"), anyString(), any(Duration.class));
    }

    @Test
    void targetCannotApproveOwnChange() {
        admin(5, "f@bingol.edu.tr", AdminProfile.FULL);
        admin(1, "a@bingol.edu.tr", AdminProfile.FULL);
        pendingChange(1, 5, AdminProfile.FULL, AdminProfile.VIEWER);
        assertEquals("RBAC_SELF_CHANGE", code(() -> service.approve(5L, 77L, null)));
    }

    @Test
    void expiredProposalCannotBeApprovedAndStaysExpired() {
        admin(5, "v@bingol.edu.tr", AdminProfile.VIEWER);
        AdminProfileChange c = pendingChange(1, 5, AdminProfile.VIEWER, AdminProfile.FULL);
        clock = Clock.fixed(T0.plus(Duration.ofHours(24)).plusSeconds(1), ZoneOffset.UTC);

        assertEquals("RBAC_CHANGE_EXPIRED", code(() -> service.approve(2L, 77L, null)));

        assertEquals(AdminProfileChange.Status.EXPIRED, c.getStatus());
        verify(users, never()).save(any());
    }

    @Test
    void staleProposalIsRejected() {
        // oneri sirasinda hedef VIEWER idi; simdi EDITOR
        admin(5, "v@bingol.edu.tr", AdminProfile.EDITOR);
        pendingChange(1, 5, AdminProfile.VIEWER, AdminProfile.FULL);
        assertEquals("RBAC_CHANGE_STALE", code(() -> service.approve(2L, 77L, null)));
    }

    @Test
    void approvingDemotionOfLastFullIsBlocked() {
        admin(6, "f@bingol.edu.tr", AdminProfile.FULL);
        pendingChange(1, 6, AdminProfile.FULL, AdminProfile.SUPPORT);
        when(users.countFullAdmins()).thenReturn(1L);
        assertEquals("RBAC_LAST_FULL", code(() -> service.approve(2L, 77L, null)));
    }

    @Test
    void decidedProposalCannotBeDecidedAgain() {
        admin(5, "v@bingol.edu.tr", AdminProfile.VIEWER);
        AdminProfileChange c = pendingChange(1, 5, AdminProfile.VIEWER, AdminProfile.FULL);
        c.setStatus(AdminProfileChange.Status.REJECTED);
        assertEquals("RBAC_CHANGE_DECIDED", code(() -> service.approve(2L, 77L, null)));
        assertEquals("RBAC_CHANGE_DECIDED", code(() -> service.reject(2L, 77L, null)));
    }

    @Test
    void rejectMarksRejectedAndUnknownIdIs404() {
        admin(5, "v@bingol.edu.tr", AdminProfile.VIEWER);
        admin(1, "a@bingol.edu.tr", AdminProfile.FULL);
        AdminProfileChange c = pendingChange(1, 5, AdminProfile.VIEWER, AdminProfile.FULL);

        ChangeView v = service.reject(1L, 77L, "vazgectim"); // oneren geri cekebilir

        assertEquals("REJECTED", v.status());
        assertEquals(AdminProfileChange.Status.REJECTED, c.getStatus());
        assertEquals("RBAC_CHANGE_NOT_FOUND", code(() -> service.reject(1L, 99L, null)));
    }
}
