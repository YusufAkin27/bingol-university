package edu.bingol.backend.messaging.ws;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.messaging.ConversationMemberRepository;
import edu.bingol.backend.moderation.BlockService;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.redis.connection.StringRedisConnection;
import org.springframework.data.redis.core.RedisCallback;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.messaging.simp.user.SimpUser;
import org.springframework.messaging.simp.user.SimpUserRegistry;

/** T-075 (A2-16): presence yenilemesi tek boru hatti; lastseen her heartbeat'te degil 60 sn'de bir yazilir. */
class PresenceRefreshPipelineTest {

    private static SimpUser user(String name) {
        SimpUser u = mock(SimpUser.class);
        when(u.getName()).thenReturn(name);
        return u;
    }

    @SuppressWarnings("unchecked")
    @Test
    void oneBatchedPipelinePerRefreshAndLastSeenOnlyEverySixthTick() {
        StringRedisTemplate redis = mock(StringRedisTemplate.class);
        SimpUserRegistry registry = mock(SimpUserRegistry.class);
        SimpUser u1 = user("1");
        SimpUser u2 = user("2");
        SimpUser bad = user("abc");
        when(registry.getUsers()).thenReturn(Set.of(u1, u2, bad));
        PresenceService p = new PresenceService(redis, registry, mock(ConversationMemberRepository.class),
                mock(BlockService.class));
        StringRedisConnection conn = mock(StringRedisConnection.class);
        when(redis.executePipelined(any(RedisCallback.class))).thenAnswer(inv -> {
            inv.<RedisCallback<Object>>getArgument(0).doInRedis(conn);
            return List.of();
        });

        p.refreshLocal(); // 1. vurus: presence + lastseen (2 kullanici x 2)
        verify(redis, times(1)).executePipelined(any(RedisCallback.class));
        verify(conn, times(2)).setEx(startsWith("presence:"), anyLong(), eq("1"));
        verify(conn, times(2)).setEx(startsWith("lastseen:"), anyLong(), anyString());

        for (int i = 0; i < 5; i++) {
            p.refreshLocal(); // 2..6. vurus: yalniz presence
        }
        verify(conn, times(12)).setEx(startsWith("presence:"), anyLong(), eq("1"));
        verify(conn, times(2)).setEx(startsWith("lastseen:"), anyLong(), anyString());

        p.refreshLocal(); // 7. vurus: lastseen yeniden
        verify(conn, times(4)).setEx(startsWith("lastseen:"), anyLong(), anyString());
        verify(redis, never()).opsForValue(); // kullanici basina sirali SET yok
    }

    private static String startsWith(String prefix) {
        return org.mockito.ArgumentMatchers.startsWith(prefix);
    }
}
