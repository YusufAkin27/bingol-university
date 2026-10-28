package edu.bingol.backend.messaging.ws;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.messaging.ConversationMemberRepository;
import edu.bingol.backend.moderation.BlockService;
import java.time.Duration;
import java.util.Arrays;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.messaging.simp.user.SimpUserRegistry;

/** viewing:<uid> ve fg:<uid> anahtarlari: TTL'li yazma, kosullu silme, toplu okuma. */
@SuppressWarnings("unchecked")
class PresenceViewingTest {

    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    private final ValueOperations<String, String> ops = mock(ValueOperations.class);
    private final PresenceService presence = new PresenceService(redis, mock(SimpUserRegistry.class),
            mock(ConversationMemberRepository.class), mock(BlockService.class));

    PresenceViewingTest() {
        when(redis.opsForValue()).thenReturn(ops);
    }

    @Test
    void setViewingWritesTtlKeysForViewingAndForeground() {
        presence.setViewing(7L, 42L);

        verify(ops).set("viewing:7", "42", Duration.ofSeconds(45));
        verify(ops).set("fg:7", "1", Duration.ofSeconds(90));
    }

    @Test
    void clearViewingOnlyDeletesWhenSameConversation() {
        when(ops.get("viewing:7")).thenReturn("43");
        presence.clearViewing(7L, 42L); // baska sohbete gecilmis: silinmez
        verify(redis, never()).delete("viewing:7");

        when(ops.get("viewing:7")).thenReturn("42");
        presence.clearViewing(7L, 42L);
        verify(redis).delete("viewing:7");
    }

    @Test
    void viewingAmongReturnsOnlyThoseViewingThatConversation() {
        when(ops.multiGet(any())).thenReturn(Arrays.asList("42", "99", null));

        Set<Long> r = presence.viewingAmong(List.of(1L, 2L, 3L), 42L);

        assertEquals(Set.of(1L), r);
    }

    @Test
    void foregroundAmongAndBackgroundClears() {
        when(ops.multiGet(any())).thenReturn(Arrays.asList("1", null));
        assertEquals(Set.of(1L), presence.foregroundAmong(List.of(1L, 2L)));

        presence.setForeground(1L, false);
        verify(redis).delete(anyCollection()); // fg + viewing birlikte silinir
        presence.setForeground(1L, true);
        verify(ops).set(eq("fg:1"), eq("1"), eq(Duration.ofSeconds(90)));
    }

    @Test
    void redisFailureMeansNobodyIsViewingSoPushStillGoes() {
        when(ops.multiGet(any())).thenThrow(new IllegalStateException("redis down"));

        assertTrue(presence.viewingAmong(List.of(1L), 42L).isEmpty());
        assertTrue(presence.foregroundAmong(List.of(1L)).isEmpty());
    }
}
