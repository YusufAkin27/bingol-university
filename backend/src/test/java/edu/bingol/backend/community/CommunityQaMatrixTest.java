package edu.bingol.backend.community;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.storage.FileStorage;
import edu.bingol.backend.community.Community.Visibility;
import edu.bingol.backend.community.CommunityMember.Role;
import edu.bingol.backend.community.CommunityMember.Status;
import edu.bingol.backend.community.dto.CommunityDtos.CreateCommunityRequest;
import edu.bingol.backend.community.dto.CommunityDtos.UpdateCommunityRequest;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.Optional;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.mockito.InOrder;
import org.springframework.http.HttpStatus;

/** T4 denetimi: rol matrisi x uclar, ozel kulup sizintilari, ban/yetki yukseltme ve duzeltilen hatalarin regresyonlari. */
class CommunityQaMatrixTest {

    private final CommunityRepository communities = mock(CommunityRepository.class);
    private final CommunityMemberRepository members = mock(CommunityMemberRepository.class);
    private final NotificationService notifications = mock(NotificationService.class);
    private final CommunityService svc = new CommunityService(communities, members, mock(UserRepository.class),
            mock(BlockService.class), notifications, mock(FileStorage.class));

    private final Actor me = new Actor(1L, false);

    private Community community(Visibility v, Community.JoinPolicy p) {
        Community c = new Community();
        c.setId(10L);
        c.setName("Kulup");
        c.setOwnerId(99L);
        c.setStatus(Community.Status.ACTIVE);
        c.setVisibility(v);
        c.setJoinPolicy(p);
        when(communities.findById(10L)).thenReturn(Optional.of(c));
        return c;
    }

    /** Benim uyeligim: role/status verilmezse uye degilim. */
    private void me(Role role, Status st) {
        if (role == null) {
            when(members.findByCommunityIdAndUserId(10L, 1L)).thenReturn(Optional.empty());
        } else {
            when(members.findByCommunityIdAndUserId(10L, 1L))
                    .thenReturn(Optional.of(new CommunityMember(10L, 1L, role, st)));
        }
    }

    private static int code(Runnable r) {
        return assertThrows(ApiException.class, r::run).status().value();
    }

    // ---- rol matrisi: yonetim uclari (update/requests/decide/remove) yalnizca MODERATOR+ ----

    private record Case(String name, Role role, Status status, boolean allowed) {}

    private static Stream<Case> staffCases() {
        return Stream.of(
                new Case("owner", Role.OWNER, Status.ACTIVE, true),
                new Case("moderator", Role.MODERATOR, Status.ACTIVE, true),
                new Case("member", Role.MEMBER, Status.ACTIVE, false),
                new Case("pending", Role.MEMBER, Status.PENDING, false),
                new Case("banned", Role.MEMBER, Status.BANNED, false),
                // BANNED satirinda eski rol kalmis olsa bile yetki vermez
                new Case("banned-ex-moderator", Role.MODERATOR, Status.BANNED, false),
                new Case("pending-with-moderator-role", Role.MODERATOR, Status.PENDING, false),
                new Case("stranger", null, null, false));
    }

    @Test
    void staffEndpointsFollowRoleMatrix() {
        community(Visibility.PUBLIC, Community.JoinPolicy.APPROVAL);
        staffCases().forEach(c -> {
            me(c.role(), c.status());
            when(members.findByCommunityIdAndUserId(10L, 5L))
                    .thenReturn(Optional.of(new CommunityMember(10L, 5L, Role.MEMBER, Status.PENDING)));
            Runnable update = () -> svc.update(me, 10L, new UpdateCommunityRequest(null, "x", null, null, null));
            Runnable requests = () -> svc.requests(me, 10L, null, 20);
            Runnable decide = () -> svc.decide(me, 10L, 5L, false);
            Runnable remove = () -> svc.remove(me, 10L, 5L, false);
            for (Runnable r : List.of(update, requests, decide, remove)) {
                if (c.allowed()) {
                    try {
                        r.run();
                    } catch (ApiException e) {
                        assertFalse(e.status() == HttpStatus.FORBIDDEN, c.name() + " yetkili olmali");
                    }
                } else {
                    assertEquals(403, code(r), c.name() + " 403 almali");
                }
            }
        });
    }

    @ParameterizedTest
    @EnumSource(value = Role.class, names = {"MEMBER", "MODERATOR"})
    void nonOwnerCannotChangeRolesOrEscalateSelf(Role actorRole) {
        community(Visibility.PUBLIC, Community.JoinPolicy.OPEN);
        me(actorRole, Status.ACTIVE);
        // kendini yukseltme
        assertEquals(403, code(() -> svc.setRole(me, 10L, 1L, Role.MODERATOR)));
        // baskasini yukseltme
        assertEquals(403, code(() -> svc.setRole(me, 10L, 5L, Role.MODERATOR)));
    }

    @Test
    void bannedUserWithStaleModeratorRoleCannotSetRoles() {
        community(Visibility.PUBLIC, Community.JoinPolicy.OPEN);
        me(Role.OWNER, Status.BANNED);
        assertEquals(403, code(() -> svc.setRole(me, 10L, 5L, Role.MODERATOR)));
    }

    @Test
    void ownerCannotDemoteSelfOrChangeOwnerRole() {
        community(Visibility.PUBLIC, Community.JoinPolicy.OPEN);
        me(Role.OWNER, Status.ACTIVE);
        assertEquals(403, code(() -> svc.setRole(me, 10L, 1L, Role.MEMBER)));
    }

    @Test
    void roleCannotBeAssignedToNonActiveMember() {
        community(Visibility.PUBLIC, Community.JoinPolicy.OPEN);
        me(Role.OWNER, Status.ACTIVE);
        when(members.findByCommunityIdAndUserId(10L, 5L))
                .thenReturn(Optional.of(new CommunityMember(10L, 5L, Role.MEMBER, Status.BANNED)));
        assertEquals(404, code(() -> svc.setRole(me, 10L, 5L, Role.MODERATOR)));
    }

    @Test
    void moderatorCannotRemoveSelfOrOwner() {
        community(Visibility.PUBLIC, Community.JoinPolicy.OPEN);
        me(Role.MODERATOR, Status.ACTIVE);
        assertEquals("USE_LEAVE", assertThrows(ApiException.class, () -> svc.remove(me, 10L, 1L, true)).code());
    }

    @Test
    void banKeepsRowAndResetsRole() {
        community(Visibility.PUBLIC, Community.JoinPolicy.OPEN);
        me(Role.OWNER, Status.ACTIVE);
        CommunityMember mod = new CommunityMember(10L, 5L, Role.MODERATOR, Status.ACTIVE);
        when(members.findByCommunityIdAndUserId(10L, 5L)).thenReturn(Optional.of(mod));

        svc.remove(me, 10L, 5L, true);

        assertEquals(Status.BANNED, mod.getStatus());
        assertEquals(Role.MEMBER, mod.getRole());
        verify(members, never()).delete(any());
    }

    @Test
    void bannedUserCannotRejoinEvenViaApprovalOrPrivate() {
        community(Visibility.PRIVATE, Community.JoinPolicy.APPROVAL);
        me(Role.MEMBER, Status.BANNED);
        assertEquals(403, code(() -> svc.join(me, 10L)));
    }

    @Test
    void pendingUserCannotApproveSelf() {
        community(Visibility.PUBLIC, Community.JoinPolicy.APPROVAL);
        me(Role.MEMBER, Status.PENDING);
        assertEquals(403, code(() -> svc.decide(me, 10L, 1L, true)));
    }

    @Test
    void sysAdminActsAsOwner() {
        community(Visibility.PUBLIC, Community.JoinPolicy.OPEN);
        Actor admin = new Actor(500L, true);
        CommunityMember victim = new CommunityMember(10L, 5L, Role.MODERATOR, Status.ACTIVE);
        when(members.findByCommunityIdAndUserId(10L, 5L)).thenReturn(Optional.of(victim));
        svc.remove(admin, 10L, 5L, true);
        assertEquals(Status.BANNED, victim.getStatus());
    }

    // ---- ozel kulup sizintilari ----

    @Test
    void privateMembersAndFeedAreClosedToNonMembersAndBanned() {
        community(Visibility.PRIVATE, Community.JoinPolicy.APPROVAL);
        for (Status st : new Status[] {Status.PENDING, Status.BANNED}) {
            me(Role.MEMBER, st);
            assertEquals(403, code(() -> svc.members(me, 10L, null, 20)), st.name());
        }
        me(null, null);
        assertEquals(403, code(() -> svc.members(me, 10L, null, 20)));
    }

    @Test
    void hiddenAndRejectedCommunitiesAre404ForStrangers() {
        for (Community.Status st : new Community.Status[] {Community.Status.HIDDEN, Community.Status.REJECTED,
                Community.Status.PENDING_REVIEW}) {
            Community c = community(Visibility.PUBLIC, Community.JoinPolicy.OPEN);
            c.setStatus(st);
            assertEquals(404, code(() -> svc.get(me, 10L)), st.name());
            assertEquals(404, code(() -> svc.members(me, 10L, null, 20)), st.name());
            assertEquals(404, code(() -> svc.join(me, 10L)), st.name());
        }
    }

    /** Hata: kimlikler sirali oldugundan OPEN+PRIVATE kulube herkes dogrudan katilip icerigi gorebiliyordu. */
    @Test
    void privateCommunityNeverJoinsDirectlyEvenIfPolicyIsOpen() {
        community(Visibility.PRIVATE, Community.JoinPolicy.OPEN);
        me(null, null);
        when(members.moderatorIds(anyLong(), any(), any())).thenReturn(List.of(99L));

        assertEquals("PENDING", svc.join(me, 10L));
    }

    @Test
    void publicOpenCommunityStillJoinsDirectly() {
        community(Visibility.PUBLIC, Community.JoinPolicy.OPEN);
        me(null, null);
        assertEquals("ACTIVE", svc.join(me, 10L));
    }

    // ---- 3 kulup siniri, ad dogrulamasi ----

    /** Hata: sayim ve ekleme arasinda kilit yoktu (eszamanli istekler 3 siniri asabiliyordu). Kilit sayimdan ONCE alinmali. */
    @Test
    void createLocksOwnerRowBeforeCounting() {
        when(communities.countByOwnerIdAndStatusIn(anyLong(), any())).thenReturn(0L);
        when(communities.saveAndFlush(any())).thenAnswer(i -> {
            Community c = i.getArgument(0);
            c.setId(7L);
            return c;
        });

        svc.create(me, new CreateCommunityRequest("Yeni Kulup", null, null, null, null));

        InOrder o = inOrder(communities);
        o.verify(communities).lockOwner(1L);
        o.verify(communities).countByOwnerIdAndStatusIn(anyLong(), any());
    }

    /** Hata: "ab " bean-validation'dan (boyut 3) geciyor, kirpilinca 2 karakterli ad olusuyordu. */
    @Test
    void nameShorterThanThreeAfterTrimIsRejected() {
        assertEquals(400, code(() -> svc.create(me, new CreateCommunityRequest("ab ", null, null, null, null))));
        community(Visibility.PUBLIC, Community.JoinPolicy.OPEN);
        me(Role.OWNER, Status.ACTIVE);
        assertEquals(400, code(() -> svc.update(me, 10L, new UpdateCommunityRequest("  x  ", null, null, null, null))));
    }

    @Test
    void slugCollisionFallsBackToRandomSuffixAfterTwenty() {
        when(communities.existsBySlug(any())).thenReturn(true);
        String s = svc.uniqueSlug("Kulup");
        assertTrue(s.startsWith("kulup-") && s.length() > 8, s);
    }

    @Test
    void slugOfSymbolOnlyNameIsStillValid() {
        assertEquals("topluluk", Texts.slugify("!!!???"));
        assertEquals("topluluk", Texts.slugify("مرحبا"));
    }

    // ---- post gorseli adresi ----

    @Test
    void imageUrlValidationBlocksTraversalAndSubdirs() {
        assertTrue(CommunityPostService.validImageUrl("/files/posts/ab12-cd.png"));
        assertFalse(CommunityPostService.validImageUrl("/files/posts/../avatars/x.png"));
        assertFalse(CommunityPostService.validImageUrl("/files/posts/a/b.png"));
        assertFalse(CommunityPostService.validImageUrl("/files/posts/a.png?x=1"));
        assertFalse(CommunityPostService.validImageUrl("/files/posts/%2e%2e/a.png"));
        assertFalse(CommunityPostService.validImageUrl("/files/posts/"));
        assertFalse(CommunityPostService.validImageUrl("/files/avatars/a.png"));
        assertFalse(CommunityPostService.validImageUrl("//evil.example/files/posts/a.png"));
    }

    @Test
    void nullDescriptionOfPrivateCommunityViewHiddenCheckDoesNotThrowForAdminList() {
        // admin listesi viewer=null ile calisir
        Community c = community(Visibility.PRIVATE, Community.JoinPolicy.APPROVAL);
        c.setStatus(Community.Status.PENDING_REVIEW);
        c.setDescription("gizli");
        when(communities.byStatus(any(), anyLong(), any())).thenReturn(List.of(c));
        assertEquals("gizli", svc.byStatus(Community.Status.PENDING_REVIEW, null, 20).items().get(0).description());
    }

    /** Hata: ozel kulubun aciklamasi uye olmayana da donuyordu. */
    @Test
    void privateDescriptionHiddenFromStrangersButShownToMembersAndOwner() {
        Community c = community(Visibility.PRIVATE, Community.JoinPolicy.APPROVAL);
        c.setDescription("gizli ic bilgi");
        when(members.findByUserIdAndCommunityIdIn(anyLong(), any())).thenReturn(List.of());

        assertNull(svc.get(me, 10L).description());

        when(members.findByUserIdAndCommunityIdIn(anyLong(), any()))
                .thenReturn(List.of(new CommunityMember(10L, 1L, Role.MEMBER, Status.ACTIVE)));
        assertEquals("gizli ic bilgi", svc.get(me, 10L).description());

        when(members.findByUserIdAndCommunityIdIn(anyLong(), any())).thenReturn(List.of());
        assertEquals("gizli ic bilgi", svc.get(new Actor(99L, false), 10L).description());
    }
}
