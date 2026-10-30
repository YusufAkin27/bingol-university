package edu.bingol.backend.profile;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.profile.dto.ProfileDtos.PublicProfile;
import edu.bingol.backend.profile.privacy.AvatarVisibility;
import edu.bingol.backend.profile.privacy.AvatarVisibility.Field;
import edu.bingol.backend.profile.privacy.PublicProfileMapper;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.util.EnumMap;
import java.util.EnumSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.Test;

/** Golge engel: engel iliskisinde profil bos (404 degil), avatar her yerde null. */
class ShadowBlockProfileTest {

    private final UserRepository users = mock(UserRepository.class);
    private final BlockService blocks = mock(BlockService.class);
    private final PublicProfileMapper mapper = mock(PublicProfileMapper.class);
    private final ProfileService service = new ProfileService(users, blocks, null, null, null, null, mapper, null,
            null, null, null, null, null);

    private static User user(long id) {
        User u = new User();
        u.setId(id);
        u.setDisplayName("U" + id);
        u.setBio("bio");
        u.setFaculty("Muhendislik");
        u.setAvatarUrl("/files/avatars/x" + id + ".jpg");
        u.setShowEmail(true);
        u.setEmail("u" + id + "@bingol.edu.tr");
        return u;
    }

    @Test
    void blockedPairGetsEmptyProfileNotNotFound() {
        when(users.findById(2L)).thenReturn(Optional.of(user(2L)));
        when(blocks.isBlocked(1L, 2L)).thenReturn(true); // iki yonden biri yeter

        PublicProfile p = service.publicProfile(1L, 2L);

        assertEquals(2L, p.id());
        assertEquals("U2", p.displayName());
        assertNull(p.avatarUrl());
        assertNull(p.faculty());
        assertNull(p.department());
        assertNull(p.classYear());
        assertNull(p.bio());
        assertNull(p.email());
    }

    @Test
    void blockedByMeReflectsOnlyMyOwnBlockAndIsAbsentOnOwnProfile() {
        User t = user(2L);
        when(users.findById(2L)).thenReturn(Optional.of(t));
        when(blocks.isBlocked(1L, 2L)).thenReturn(true);
        when(blocks.hasBlocked(1L, 2L)).thenReturn(true);
        assertEquals(Boolean.TRUE, service.publicProfile(1L, 2L).blockedByMe());

        when(blocks.hasBlocked(1L, 2L)).thenReturn(false); // karsi taraf beni engelledi: sizdirilmaz
        assertEquals(Boolean.FALSE, service.publicProfile(1L, 2L).blockedByMe());

        User other = user(5L);
        when(users.findById(5L)).thenReturn(Optional.of(other));
        when(mapper.map(1L, other)).thenReturn(PublicProfile.of(other));
        assertEquals(Boolean.FALSE, service.publicProfile(1L, 5L).blockedByMe());

        User me = user(1L);
        when(users.findById(1L)).thenReturn(Optional.of(me));
        when(mapper.map(1L, me)).thenReturn(PublicProfile.of(me));
        assertNull(service.publicProfile(1L, 1L).blockedByMe()); // kendi profilim: alan yok
    }

    @Test
    void unblockedProfileStillUsesMapperAndSuspendedIs404() {
        User u = user(3L);
        when(users.findById(3L)).thenReturn(Optional.of(u));
        PublicProfile full = PublicProfile.of(u);
        when(mapper.map(1L, u)).thenReturn(full);
        assertNotNull(service.publicProfile(1L, 3L).avatarUrl());

        User bad = user(4L);
        bad.setStatus(UserStatus.SUSPENDED);
        when(users.findById(4L)).thenReturn(Optional.of(bad));
        assertEquals("USER_NOT_FOUND", assertThrows(ApiException.class, () -> service.publicProfile(1L, 4L)).code());
    }

    @Test
    void mapperBlanksProfilesOfBlockRelatedUsersInBatch() {
        AvatarVisibility vis = mock(AvatarVisibility.class);
        Map<Field, Set<Long>> all = new EnumMap<>(Field.class);
        for (Field f : EnumSet.allOf(Field.class)) {
            all.put(f, Set.of(2L, 3L));
        }
        when(vis.visibleOwners(anyLong(), anyCollection(), org.mockito.ArgumentMatchers.<java.util.Collection<Field>>any())).thenReturn(all);
        PublicProfileMapper real = new PublicProfileMapper(vis);
        BlockService b = mock(BlockService.class);
        when(b.hiddenFrom(1L)).thenReturn(Set.of(2L));
        real.setBlocks(b);

        List<PublicProfile> out = real.mapAll(1L, List.of(user(2L), user(3L)));

        assertNull(out.get(0).avatarUrl());
        assertNull(out.get(0).bio());
        assertNull(out.get(0).email());
        assertEquals("U2", out.get(0).displayName());
        assertNotNull(out.get(1).avatarUrl()); // engelsiz kullanici etkilenmez
        assertEquals("bio", out.get(1).bio());
    }
}
