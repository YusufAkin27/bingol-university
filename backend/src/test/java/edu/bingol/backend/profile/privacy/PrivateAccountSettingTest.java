package edu.bingol.backend.profile.privacy;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.moderation.UserModerationService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.post.follow.FollowRequestService;
import edu.bingol.backend.profile.privacy.PrivacyDtos.PrivacyView;
import edu.bingol.backend.profile.privacy.PrivacyDtos.UpdatePrivacyRequest;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Duration;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

/** Gizli hesap ayari: varsayilan, hiz siniri (yalniz GERCEK degisiklik sayilir), gecis tetikleri. */
class PrivateAccountSettingTest {

    private final ProfilePrivacyRepository repo = mock(ProfilePrivacyRepository.class);
    private final PrivacyService service = new PrivacyService(repo);
    private final RateLimiter limiter = mock(RateLimiter.class);
    private final PrivacyController controller = new PrivacyController(service, limiter);
    private final FollowRequestService requests = mock(FollowRequestService.class);

    @BeforeEach
    void login() {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(7L, null, List.of()));
        when(repo.save(any(ProfilePrivacy.class))).thenAnswer(i -> i.getArgument(0));
    }

    @AfterEach
    void logout() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void accountsAreOpenByDefaultAndViewExposesTheFlag() {
        when(repo.findById(7L)).thenReturn(Optional.empty());
        PrivacyView v = controller.get();
        assertFalse(v.privateAccount(), "varsayilan: herkese acik");
    }

    @Test
    void realChangeIsCountedTenPerHourPlusBurstAndSameValueIsFree() {
        ProfilePrivacy open = ProfilePrivacy.defaults(7L);
        when(repo.findById(7L)).thenReturn(Optional.of(open));
        PrivacyView v = controller.update(new UpdatePrivacyRequest(null, null, null, null, null, null, true));
        assertTrue(v.privateAccount());
        verify(limiter).check("profile-private-flip:user:7", 10, Duration.ofHours(1));
        verify(limiter).check("profile-private-flip-burst:user:7", 3, Duration.ofMinutes(1));

        // ayni deger tekrar: flip sayaci harcanmaz
        org.mockito.Mockito.clearInvocations(limiter);
        controller.update(new UpdatePrivacyRequest(null, null, null, null, null, null, true));
        verify(limiter, never()).check(eq("profile-private-flip:user:7"), anyInt(), any());

        // privateAccount verilmeyen guncelleme de flip sayaci harcamaz
        controller.update(new UpdatePrivacyRequest(Audience.ONLY_ME, null, null, null, null));
        verify(limiter, never()).check(eq("profile-private-flip:user:7"), anyInt(), any());
        verify(limiter, org.mockito.Mockito.atLeastOnce()).check(eq("profile-privacy:user:7"), anyInt(), any());
    }

    @Test
    void privateToPublicTriggersAutoAcceptOnlyOnThatTransition() {
        service.setRequests(requests);
        ProfilePrivacy p = ProfilePrivacy.defaults(7L);
        p.setPrivateAccount(true);
        when(repo.findById(7L)).thenReturn(Optional.of(p));

        service.update(7L, new UpdatePrivacyRequest(null, null, null, null, null, null, false));
        verify(requests).onBecamePublic(7L);

        // acik -> acik ve acik -> gizli tetiklemez
        org.mockito.Mockito.clearInvocations(requests);
        service.update(7L, new UpdatePrivacyRequest(null, null, null, null, null, null, false));
        service.update(7L, new UpdatePrivacyRequest(null, null, null, null, null, null, true));
        verify(requests, never()).onBecamePublic(anyLong());
    }

    @Test
    void suspendingAnAccountClearsItsPendingFollowRequests() {
        UserRepository users = mock(UserRepository.class);
        StringRedisTemplate redis = mock(StringRedisTemplate.class);
        @SuppressWarnings("unchecked")
        ValueOperations<String, String> ops = mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(ops);
        User u = new User();
        u.setEmail("x@bingol.edu.tr");
        when(users.findById(9L)).thenReturn(Optional.of(u));
        UserModerationService mod = new UserModerationService(users, redis, mock(NotificationService.class));
        java.lang.reflect.Method setter;
        try {
            setter = UserModerationService.class.getDeclaredMethod("setFollowRequests", FollowRequestService.class);
            setter.setAccessible(true);
            setter.invoke(mod, requests);
        } catch (ReflectiveOperationException e) {
            throw new IllegalStateException(e);
        }
        mod.suspend(9L, "test");
        verify(requests).purgeUser(9L);
        assertEquals(edu.bingol.backend.user.UserStatus.SUSPENDED, u.getStatus());
        verify(ops).set(anyString(), anyString());
    }
}
