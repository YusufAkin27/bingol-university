package edu.bingol.backend.profile.privacy;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.profile.privacy.AvatarVisibility.Field;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.Test;

class AvatarVisibilityTest {

    private static final Long VIEWER = 1L;
    private static final Long OWNER = 2L;

    private final ProfilePrivacyRepository repo = mock(ProfilePrivacyRepository.class);
    private final SharedContextRepository shared = mock(SharedContextRepository.class);
    private final AvatarVisibility vis = new AvatarVisibility(repo, shared);

    private void owner(Audience a, boolean hidden, boolean sharedCtx) {
        ProfilePrivacy p = ProfilePrivacy.defaults(OWNER);
        p.setAvatarAudience(a);
        p.setAvatarHidden(hidden);
        when(repo.findByUserIdIn(any())).thenReturn(List.of(p));
        when(shared.sharedWith(any(), any())).thenReturn(sharedCtx ? Set.of(OWNER) : Set.of());
    }

    @Test
    void pureRuleMatrix() {
        for (Audience a : Audience.values()) {
            assertTrue(AvatarVisibility.allowed(a, true, false), "owner always sees: " + a);
        }
        assertTrue(AvatarVisibility.allowed(Audience.EVERYONE, false, false));
        assertTrue(AvatarVisibility.allowed(Audience.EVERYONE, false, true));
        assertFalse(AvatarVisibility.allowed(Audience.SHARED_CONTEXT, false, false));
        assertTrue(AvatarVisibility.allowed(Audience.SHARED_CONTEXT, false, true));
        assertFalse(AvatarVisibility.allowed(Audience.ONLY_ME, false, false));
        assertFalse(AvatarVisibility.allowed(Audience.ONLY_ME, false, true));
    }

    @Test
    void viewersAmongUsesOneBatchedSharedQueryForSharedContext() {
        ProfilePrivacy p = ProfilePrivacy.defaults(OWNER);
        p.setAvatarAudience(Audience.SHARED_CONTEXT);
        when(repo.findById(OWNER)).thenReturn(java.util.Optional.of(p));
        when(shared.viewersSharingWith(OWNER, List.of(10L, 11L, 12L))).thenReturn(Set.of(11L));

        assertEquals(Set.of(11L), vis.viewersAmong(OWNER, List.of(10L, 11L, 12L), Field.AVATAR));
        verify(shared).viewersSharingWith(any(), any());
        verify(shared, never()).sharedWith(any(), any()); // bakan basina sorgu yok
    }

    @Test
    void viewersAmongHandlesEveryoneOnlyMeHiddenAndNoRow() {
        when(repo.findById(OWNER)).thenReturn(java.util.Optional.empty());
        assertEquals(Set.of(10L, 11L), vis.viewersAmong(OWNER, List.of(10L, 11L), Field.AVATAR));

        ProfilePrivacy p = ProfilePrivacy.defaults(OWNER);
        p.setAvatarAudience(Audience.ONLY_ME);
        when(repo.findById(OWNER)).thenReturn(java.util.Optional.of(p));
        assertEquals(Set.of(), vis.viewersAmong(OWNER, List.of(10L, 11L), Field.AVATAR));

        p.setAvatarAudience(Audience.EVERYONE);
        p.setAvatarHidden(true); // moderasyon gizlemesi
        assertEquals(Set.of(), vis.viewersAmong(OWNER, List.of(10L, 11L), Field.AVATAR));
        verify(shared, never()).viewersSharingWith(any(), any());
    }

    @Test
    void noRowMeansEveryone() {
        when(repo.findByUserIdIn(any())).thenReturn(List.of());
        assertEquals("u.png", vis.avatarFor(VIEWER, OWNER, "u.png"));
        verify(shared, never()).sharedWith(any(), any());
    }

    @Test
    void everyoneStranger() {
        owner(Audience.EVERYONE, false, false);
        assertEquals("u.png", vis.avatarFor(VIEWER, OWNER, "u.png"));
    }

    @Test
    void sharedContextOnlyWithTie() {
        owner(Audience.SHARED_CONTEXT, false, true);
        assertEquals("u.png", vis.avatarFor(VIEWER, OWNER, "u.png"));
        owner(Audience.SHARED_CONTEXT, false, false);
        assertNull(vis.avatarFor(VIEWER, OWNER, "u.png"));
    }

    @Test
    void onlyMeHidesFromEveryoneButOwner() {
        owner(Audience.ONLY_ME, false, true);
        assertNull(vis.avatarFor(VIEWER, OWNER, "u.png"));
        assertEquals("u.png", vis.avatarFor(OWNER, OWNER, "u.png"));
    }

    @Test
    void moderationHiddenOverridesEveryoneButNotOwner() {
        owner(Audience.EVERYONE, true, true);
        assertNull(vis.avatarFor(VIEWER, OWNER, "u.png"));
        assertEquals("u.png", vis.avatarFor(OWNER, OWNER, "u.png"));
    }

    @Test
    void nullAvatarStaysNull() {
        assertNull(vis.avatarFor(VIEWER, OWNER, null));
    }

    @Test
    void selfNeverQueriesSharedContext() {
        owner(Audience.SHARED_CONTEXT, false, false);
        assertTrue(vis.canSee(OWNER, OWNER, Field.AVATAR));
        verify(shared, never()).sharedWith(any(), any());
    }

    @Test
    void bulkFilterKeepsKeysAndNullsHidden() {
        ProfilePrivacy hidden = ProfilePrivacy.defaults(3L);
        hidden.setAvatarAudience(Audience.ONLY_ME);
        when(repo.findByUserIdIn(any())).thenReturn(List.of(hidden));
        Map<Long, String> out = vis.filterAvatars(VIEWER, Map.of(3L, "a.png", 4L, "b.png"));
        assertEquals(2, out.size());
        assertNull(out.get(3L));
        assertEquals("b.png", out.get(4L));
    }

    @Test
    void fieldsAreIndependent() {
        ProfilePrivacy p = ProfilePrivacy.defaults(OWNER);
        p.setBioAudience(Audience.ONLY_ME);
        p.setFacultyAudience(Audience.SHARED_CONTEXT);
        when(repo.findByUserIdIn(any())).thenReturn(List.of(p));
        when(shared.sharedWith(any(), any())).thenReturn(Set.of());
        Map<Field, Set<Long>> r = vis.visibleOwners(VIEWER, List.of(OWNER), List.of(Field.values()));
        assertTrue(r.get(Field.AVATAR).contains(OWNER));
        assertTrue(r.get(Field.DEPARTMENT).contains(OWNER));
        assertFalse(r.get(Field.BIO).contains(OWNER));
        assertFalse(r.get(Field.FACULTY).contains(OWNER));
    }
}
