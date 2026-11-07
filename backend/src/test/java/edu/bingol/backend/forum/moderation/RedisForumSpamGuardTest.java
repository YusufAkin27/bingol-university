package edu.bingol.backend.forum.moderation;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import java.time.Duration;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

/** Spam korumasi: bellek yolu (Redis yok) ve Redis yolu (setIfAbsent). */
class RedisForumSpamGuardTest {

    private static final String LONG = "Bu cok uzun ve tekrar eden bir reklam metnidir, kampus gruplarina katilin";
    private static final String ZWSP = String.valueOf((char) 0x200B);

    private RedisForumSpamGuard memoryGuard() {
        StringRedisTemplate redis = mock(StringRedisTemplate.class); // opsForValue() null -> bellek yolu
        return new RedisForumSpamGuard(redis, 600);
    }

    @Test
    void sameUserSameBodyTwiceIsRejected() {
        RedisForumSpamGuard g = memoryGuard();
        g.assertNotDuplicate(1L, "comment", 10L, LONG);
        assertThatThrownBy(() -> g.assertNotDuplicate(1L, "comment", 11L, LONG + "!!"))
                .isInstanceOfSatisfying(ApiException.class, e -> {
                    assertThat(e.code()).isEqualTo("FORUM_DUPLICATE_CONTENT");
                    assertThat(e.status().value()).isEqualTo(429);
                });
    }

    @Test
    void otherUserOrScopeOrBodyIsAllowed() {
        RedisForumSpamGuard g = memoryGuard();
        g.assertNotDuplicate(1L, "comment", 10L, LONG);
        assertThatCode(() -> g.assertNotDuplicate(2L, "comment", 10L, LONG)).doesNotThrowAnyException();
        assertThatCode(() -> g.assertNotDuplicate(1L, "topic", null, LONG)).doesNotThrowAnyException();
        assertThatCode(() -> g.assertNotDuplicate(1L, "comment", 10L, LONG + " ve baska bir cumle")).doesNotThrowAnyException();
    }

    @Test
    void shortBodiesAreScopedToTheirContext() {
        RedisForumSpamGuard g = memoryGuard();
        g.assertNotDuplicate(1L, "comment", 10L, "Katiliyorum");
        assertThatCode(() -> g.assertNotDuplicate(1L, "comment", 11L, "katiliyorum!")).doesNotThrowAnyException();
        assertThatThrownBy(() -> g.assertNotDuplicate(1L, "comment", 10L, "KATILIYORUM"))
                .isInstanceOf(ApiException.class);
    }

    @Test
    void forgetAllowsResubmission() {
        RedisForumSpamGuard g = memoryGuard();
        g.assertNotDuplicate(1L, "topic", null, LONG);
        g.forget(1L, "topic", null, LONG);
        assertThatCode(() -> g.assertNotDuplicate(1L, "topic", null, LONG)).doesNotThrowAnyException();
    }

    @Test
    void blankBodyIsIgnored() {
        RedisForumSpamGuard g = memoryGuard();
        g.assertNotDuplicate(1L, "comment", 10L, "  " + ZWSP + " ");
        assertThatCode(() -> g.assertNotDuplicate(1L, "comment", 10L, "   ")).doesNotThrowAnyException();
    }

    @Test
    @SuppressWarnings("unchecked")
    void redisPathUsesSetIfAbsent() {
        StringRedisTemplate redis = mock(StringRedisTemplate.class);
        ValueOperations<String, String> ops = mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(ops);
        when(ops.setIfAbsent(anyString(), anyString(), any(Duration.class))).thenReturn(true, false);
        RedisForumSpamGuard g = new RedisForumSpamGuard(redis, 600);
        g.assertNotDuplicate(5L, "topic", null, LONG);
        assertThatThrownBy(() -> g.assertNotDuplicate(5L, "topic", null, LONG)).isInstanceOf(ApiException.class);
        verify(ops, times(2)).setIfAbsent(anyString(), anyString(), org.mockito.ArgumentMatchers.eq(Duration.ofSeconds(600)));
    }

    @Test
    @SuppressWarnings("unchecked")
    void redisFailureFallsBackToMemory() {
        StringRedisTemplate redis = mock(StringRedisTemplate.class);
        ValueOperations<String, String> ops = mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(ops);
        when(ops.setIfAbsent(anyString(), anyString(), any(Duration.class))).thenThrow(new IllegalStateException("redis down"));
        RedisForumSpamGuard g = new RedisForumSpamGuard(redis, 600);
        g.assertNotDuplicate(5L, "topic", null, LONG);
        assertThatThrownBy(() -> g.assertNotDuplicate(5L, "topic", null, LONG)).isInstanceOf(ApiException.class);
    }
}
