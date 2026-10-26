package edu.bingol.backend.profile;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.analytics.ActivityRepository;
import edu.bingol.backend.appinfo.AppInfoService;
import edu.bingol.backend.common.storage.FileStorage;
import edu.bingol.backend.event.EventRsvp;
import edu.bingol.backend.event.EventRsvpRepository;
import edu.bingol.backend.event.UserEventRepository;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.security.crypto.password.PasswordEncoder;

class AnonymizeTest {

    @Test
    @SuppressWarnings("unchecked")
    void anonymizeMarksSuspendedAndReleasesGoingRsvps() {
        UserRepository users = mock(UserRepository.class);
        PasswordEncoder enc = mock(PasswordEncoder.class);
        when(enc.encode(any())).thenReturn("h");
        EventRsvpRepository rsvps = mock(EventRsvpRepository.class);
        UserEventRepository events = mock(UserEventRepository.class);
        StringRedisTemplate redis = mock(StringRedisTemplate.class);
        ValueOperations<String, String> ops = mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(ops);
        User u = new User();
        u.setId(5L);
        when(users.findById(5L)).thenReturn(Optional.of(u));
        EventRsvp going = new EventRsvp();
        going.setEventId(9L);
        going.setStatus(EventRsvp.Status.GOING);
        EventRsvp interested = new EventRsvp();
        interested.setEventId(10L);
        interested.setStatus(EventRsvp.Status.INTERESTED);
        when(rsvps.findByUserId(5L)).thenReturn(List.of(going, interested));

        ProfileService s = new ProfileService(users, mock(BlockService.class), mock(FileStorage.class), enc,
                mock(AppInfoService.class), mock(ActivityRepository.class), rsvps, events, redis);
        s.anonymizeAccount(5L);

        verify(ops).set("suspended:5", "1");
        verify(events).decrementGoing(9L);
        verify(events, never()).decrementGoing(10L);
        verify(rsvps).delete(going);
        verify(rsvps).delete(interested);
    }
}
