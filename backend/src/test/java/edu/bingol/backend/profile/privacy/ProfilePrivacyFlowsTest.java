package edu.bingol.backend.profile.privacy;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.moderation.ReportTargetType;
import edu.bingol.backend.profile.completeness.CompletenessService;
import edu.bingol.backend.profile.dto.ProfileDtos.PublicProfile;
import edu.bingol.backend.profile.privacy.PrivacyDtos.UpdatePrivacyRequest;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.ObjectProvider;

class ProfilePrivacyFlowsTest {

    private final ProfilePrivacyRepository repo = mock(ProfilePrivacyRepository.class);
    private final SharedContextRepository shared = mock(SharedContextRepository.class);
    private final PrivacyService privacy = new PrivacyService(repo);

    private static User user(long id) {
        User u = new User();
        u.setId(id);
        u.setEmail("u" + id + "@bingol.edu.tr");
        u.setDisplayName("Kullanici " + id);
        u.setBio("bio");
        u.setFaculty("Fak");
        u.setDepartment("Dep");
        u.setClassYear((short) 2);
        u.setAvatarUrl("/files/avatars/" + id + ".png");
        return u;
    }

    @Test
    void mapperAppliesPerFieldAudiences() {
        ProfilePrivacy p = ProfilePrivacy.defaults(2L);
        p.setBioAudience(Audience.ONLY_ME);
        p.setAvatarAudience(Audience.SHARED_CONTEXT);
        p.setDepartmentAudience(Audience.SHARED_CONTEXT);
        when(repo.findByUserIdIn(any())).thenReturn(List.of(p));
        when(shared.sharedWith(any(), any())).thenReturn(java.util.Set.of());
        PublicProfileMapper mapper = new PublicProfileMapper(new AvatarVisibility(repo, shared));

        PublicProfile stranger = mapper.map(1L, user(2));
        assertNull(stranger.bio());
        assertNull(stranger.avatarUrl());
        assertNull(stranger.department());
        assertEquals("Fak", stranger.faculty());
        assertEquals((short) 2, stranger.classYear());

        when(shared.sharedWith(any(), any())).thenReturn(java.util.Set.of(2L));
        PublicProfile friend = mapper.map(1L, user(2));
        assertNull(friend.bio());
        assertEquals("/files/avatars/2.png", friend.avatarUrl());
        assertEquals("Dep", friend.department());

        PublicProfile self = mapper.map(2L, user(2));
        assertEquals("bio", self.bio());
    }

    @Test
    void updateIsPartialAndPersists() {
        when(repo.findById(5L)).thenReturn(Optional.empty());
        when(repo.save(any())).thenAnswer(i -> i.getArgument(0));
        ProfilePrivacy p = privacy.update(5L, new UpdatePrivacyRequest(Audience.ONLY_ME, null, null, null, null));
        assertEquals(Audience.ONLY_ME, p.getAvatarAudience());
        assertEquals(Audience.EVERYONE, p.getBioAudience());
    }

    @Test
    void avatarReportHandlerHidesWithoutTouchingUserSettings() {
        UserRepository users = mock(UserRepository.class);
        AvatarReportHandler h = new AvatarReportHandler(users, privacy);
        assertEquals(ReportTargetType.USER_AVATAR, h.type());
        assertEquals(Optional.of(7L), h.ownerId(7L));

        User active = user(7);
        when(users.findById(7L)).thenReturn(Optional.of(active));
        assertTrue(h.exists(7L));
        active.setAvatarUrl(null);
        assertFalse(h.exists(7L));
        active.setAvatarUrl("x");
        active.setStatus(UserStatus.SUSPENDED);
        assertFalse(h.exists(7L));
        when(users.findById(8L)).thenReturn(Optional.empty());
        assertFalse(h.exists(8L));

        ProfilePrivacy existing = ProfilePrivacy.defaults(7L);
        existing.setAvatarAudience(Audience.SHARED_CONTEXT);
        when(repo.findById(7L)).thenReturn(Optional.of(existing));
        h.hide(7L);
        ArgumentCaptor<ProfilePrivacy> cap = ArgumentCaptor.forClass(ProfilePrivacy.class);
        verify(repo).save(cap.capture());
        assertTrue(cap.getValue().isAvatarHidden());
        assertEquals(Audience.SHARED_CONTEXT, cap.getValue().getAvatarAudience());
    }

    @SuppressWarnings("unchecked")
    @Test
    void cleanupHooksRunAndFailuresAreSwallowed() {
        AvatarCleanup bad = mock(AvatarCleanup.class);
        AvatarCleanup good = mock(AvatarCleanup.class);
        doThrow(new IllegalStateException("boom")).when(bad).cleanup(any(), any());
        ObjectProvider<AvatarCleanup> provider = mock(ObjectProvider.class);
        when(provider.orderedStream()).thenReturn(java.util.stream.Stream.of(bad, good));
        new AvatarCleanups(provider, privacy).run(9L, "/files/avatars/9.png", null);
        verify(good).cleanup(9L, List.of("/files/avatars/9.png"));
        verify(repo).deleteById(9L);
    }

    @Test
    void completenessPercentAndSuggestions() {
        I18n i18n = mock(I18n.class);
        when(i18n.current(any())).thenAnswer(i -> i.getArgument(0));
        CompletenessService svc = new CompletenessService(i18n);

        User empty = user(1);
        empty.setAvatarUrl(null);
        empty.setBio(null);
        empty.setFaculty(" ");
        empty.setDepartment(null);
        empty.setClassYear(null);
        CompletenessService.Completeness c = svc.of(empty);
        assertEquals(15, c.percent());
        assertEquals(List.of("displayName"), c.filled());
        assertEquals("avatar", c.missing().get(0).field());
        assertEquals("profile.complete.avatar", c.missing().get(0).suggestion());

        assertEquals(100, svc.of(user(2)).percent());
        assertTrue(svc.of(user(2)).missing().isEmpty());
    }
}
