package edu.bingol.backend.messaging;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.messaging.ws.ChatEventBus;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.user.UserRepository;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;

/** QA-CHAT-03: okuma / sessize alma / arsivleme `me/summary` rozet onbellegini atar (hayalet rozet olmasin). */
class UnreadBadgeCacheEvictionTest {

    private static final Long ME = 1L;
    private static final Long CONV = 10L;

    @Test
    void readEvictsBadgeCache() {
        UnreadBadgeCache cache = mock(UnreadBadgeCache.class);
        ConversationRepository convs = mock(ConversationRepository.class);
        when(convs.findById(CONV)).thenReturn(Optional.empty());
        ReceiptService svc = new ReceiptService(mock(ConversationMemberRepository.class), convs,
                mock(MessageRepository.class), mock(UserRepository.class), mock(BlockService.class),
                mock(ChatEventBus.class));
        svc.setBadgeCache(cache);

        svc.onRead(ME, CONV, 0, 0, 5L);

        verify(cache).evict(ME);
    }

    @Test
    void muteUnmuteArchiveUnarchiveEvictBadgeCache() {
        ConversationMemberRepository members = mock(ConversationMemberRepository.class);
        ConversationService conversations = mock(ConversationService.class);
        ConversationPrefsService svc = new ConversationPrefsService(members, mock(MessageRepository.class),
                conversations, mock(BlockService.class), mock(ConversationRepository.class));
        UnreadBadgeCache cache = mock(UnreadBadgeCache.class);
        svc.setBadgeCache(cache);
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CONV, ME))
                .thenReturn(Optional.of(ConversationMember.of(CONV, ME, ConversationMember.Role.MEMBER)));

        svc.mute(ME, CONV, 60, null);
        svc.unmute(ME, CONV);
        svc.archive(ME, CONV, true);
        svc.unarchive(ME, CONV);

        verify(cache, org.mockito.Mockito.times(4)).evict(ME);
    }

    @Test
    void evictSwallowsRedisFailures() {
        StringRedisTemplate redis = mock(StringRedisTemplate.class);
        when(redis.delete("me:unread:" + ME)).thenThrow(new IllegalStateException("redis down"));

        new UnreadBadgeCache(redis).evict(ME); // atmamali
        new UnreadBadgeCache(redis).evict(null);
    }
}
