package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.profile.MeSummaryService;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.jdbc.core.JdbcTemplate;

/** /api/me/summary rozeti: sessizler sayilmaz, sayim 100'de ("99+") kesilir, sonuc kisa sure onbellege alinir. */
class UnreadBadgeTest {

    private final ConversationMemberRepository members = mock(ConversationMemberRepository.class);
    private final MessageRepository messages = mock(MessageRepository.class);
    private final BlockService blocks = mock(BlockService.class);
    private final ConversationPrefsService prefs =
            new ConversationPrefsService(members, messages, mock(ConversationService.class), blocks);

    private static ConversationMember member(long conv, boolean muted) {
        ConversationMember m = ConversationMember.of(conv, 1L, ConversationMember.Role.MEMBER);
        if (muted) {
            m.setMutedUntil(Instant.now().plus(Duration.ofDays(30)));
        }
        return m;
    }

    @Test
    @SuppressWarnings("unchecked")
    void mutedConversationsNeverReachTheCountQuery() {
        when(members.findByUserIdAndLeftAtIsNull(1L)).thenReturn(List.of(member(10, false), member(11, true), member(12, false)));
        when(blocks.hiddenFrom(1L)).thenReturn(Set.of());
        when(messages.unreadCounts(eq(1L), anyCollection(), anyCollection()))
                .thenReturn(List.of(new Object[] {10L, 3L}, new Object[] {12L, 4L}));

        assertEquals(7, prefs.unreadBadge(1L));

        ArgumentCaptor<java.util.Collection<Long>> ids = ArgumentCaptor.forClass(java.util.Collection.class);
        verify(messages).unreadCounts(eq(1L), ids.capture(), anyCollection());
        assertEquals(List.of(10L, 12L), new ArrayList<>(ids.getValue()));
    }

    @Test
    void totalIsCappedAtOneHundred() {
        when(members.findByUserIdAndLeftAtIsNull(1L)).thenReturn(List.of(member(10, false), member(12, false)));
        when(blocks.hiddenFrom(1L)).thenReturn(Set.of());
        when(messages.unreadCounts(eq(1L), anyCollection(), anyCollection()))
                .thenReturn(List.of(new Object[] {10L, 250_000L}, new Object[] {12L, 9L}));

        assertEquals(ConversationPrefsService.BADGE_CAP, prefs.unreadBadge(1L));
        assertEquals(100, ConversationPrefsService.BADGE_CAP);
    }

    @Test
    void onlyMutedConversationsMeansZeroWithoutAnyCountQuery() {
        when(members.findByUserIdAndLeftAtIsNull(1L)).thenReturn(List.of(member(11, true)));

        assertEquals(0, prefs.unreadBadge(1L));
        verify(messages, never()).unreadCounts(any(), anyCollection(), anyCollection());
    }

    @Test
    @SuppressWarnings("unchecked")
    void summaryCachesTheBadgeForAShortWhile() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.queryForObject(any(String.class), any(org.springframework.jdbc.core.RowMapper.class), any(), any(),
                any(), any())).thenReturn(new long[] {1, 2, 3, 4});
        ConversationPrefsService p = mock(ConversationPrefsService.class);
        when(p.unreadBadge(1L)).thenReturn(42L);
        StringRedisTemplate redis = mock(StringRedisTemplate.class);
        ValueOperations<String, String> ops = mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(ops);
        // 1. istek: onbellek bos -> sayar ve yazar; 2. istek: onbellekten
        when(ops.get("me:unread:1")).thenReturn(null, "42");
        MeSummaryService svc = new MeSummaryService(jdbc, p);
        org.springframework.test.util.ReflectionTestUtils.invokeMethod(svc, "setRedis", redis);

        assertEquals(42, svc.summary(1L).unreadMessages());
        assertEquals(42, svc.summary(1L).unreadMessages());

        verify(p, times(1)).unreadBadge(1L);
        verify(ops).set(eq("me:unread:1"), eq("42"), any(Duration.class));
    }
}
