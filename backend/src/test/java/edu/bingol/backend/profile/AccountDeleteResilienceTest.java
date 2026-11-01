package edu.bingol.backend.profile;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.analytics.ActivityRepository;
import edu.bingol.backend.appinfo.AppInfoService;
import edu.bingol.backend.auth.token.SessionService;
import edu.bingol.backend.event.EventRsvpRepository;
import edu.bingol.backend.event.UserEventRepository;
import edu.bingol.backend.media.MediaService;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.profile.privacy.AvatarCleanups;
import edu.bingol.backend.profile.privacy.PublicProfileMapper;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.security.crypto.password.PasswordEncoder;

/**
 * FIX-P08 / A01#11: hesap silme akisi. (1) islem icinde pahali bcrypt encode() yok, parola alani kullanilamaz ozet;
 * (2) commit sonrasi adimlar birbirini engellemez, bir kez yeniden denenir.
 */
class AccountDeleteResilienceTest {

    private final UserRepository users = mock(UserRepository.class);
    private final PasswordEncoder enc = mock(PasswordEncoder.class);
    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    @SuppressWarnings("unchecked")
    private final ValueOperations<String, String> ops = mock(ValueOperations.class);
    private final SessionService sessions = mock(SessionService.class);
    private final EventRsvpRepository rsvps = mock(EventRsvpRepository.class);

    private ProfileService service() {
        when(redis.opsForValue()).thenReturn(ops);
        when(enc.matches(any(), any())).thenReturn(true);
        when(rsvps.findByUserId(any())).thenReturn(List.of());
        ProfileService s = new ProfileService(users, mock(BlockService.class), mock(MediaService.class), enc,
                mock(AppInfoService.class), mock(ActivityRepository.class), mock(PublicProfileMapper.class),
                mock(AvatarCleanups.class), rsvps, mock(UserEventRepository.class), redis, mock(AccountDataPurger.class), null);
        s.setSessions(sessions);
        return s;
    }

    private User user(long id) {
        User u = new User();
        u.setId(id);
        u.setEmail("kisi" + id + "@bingol.edu.tr");
        u.setRole(Role.USER);
        u.setPasswordHash("hash");
        u.setStatus(UserStatus.ACTIVE);
        when(users.findById(id)).thenReturn(Optional.of(u));
        return u;
    }

    @Test
    void anonymizedPasswordIsUnusableAndNotBcryptEncodedInsideTheTransaction() {
        User u = user(5L);
        service().deleteAccount(5L, "pw");

        assertTrue(u.getPasswordHash().startsWith(ProfileService.UNUSABLE_PASSWORD_PREFIX));
        assertFalse(u.getPasswordHash().startsWith("$2"));
        verify(enc, never()).encode(any());
        verify(enc, times(1)).matches(any(), any()); // dogrulama bir kez, islem disinda
    }

    @Test
    void revokeStillRunsWhenSuspendMarkFailsTwice() {
        user(6L);
        doThrow(new RuntimeException("redis down")).when(ops).set(anyString(), anyString());

        service().anonymizeAccount(6L);

        verify(ops, times(2)).set("suspended:6", "1"); // bir kez yeniden denendi
        verify(sessions).revokeAll(6L); // ilk adim dusse de oturum iptali calisti
    }

    @Test
    void suspendMarkRetriedOnceOnTransientFailure() {
        user(7L);
        doThrow(new RuntimeException("blip")).doNothing().when(ops).set(anyString(), anyString());

        service().anonymizeAccount(7L);

        verify(ops, times(2)).set("suspended:7", "1");
        verify(sessions).revokeAll(7L);
    }
}
