package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.messaging.dto.MessagingDtos.ConversationView;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/**
 * FIX-P03 (A02#3): konusma listesi buyuk grup / odalarin tum uyelerini yuklemez (500 uyeli 50 oda = 25.000 satir/istek
 * idi); uye sayisi tek GROUP BY ile, kendi satirim ayri sorguyla gelir. Birebir ve kucuk gruplar eskisi gibi.
 */
class ConversationViewsQueryCountTest {

    private static final Long ME = 2L;

    private final ConversationRepository convs = mock(ConversationRepository.class);
    private final ConversationMemberRepository members = mock(ConversationMemberRepository.class);
    private final MessageRepository messages = mock(MessageRepository.class);
    private final UserRepository users = mock(UserRepository.class);
    private final BlockService blocks = mock(BlockService.class);
    private final MessageCodec codec = mock(MessageCodec.class);
    private final ConversationService service = new ConversationService(convs, members, messages, users, blocks, codec);

    private static Conversation conv(long id, Conversation.Type type) {
        Conversation c = new Conversation();
        c.setId(id);
        c.setType(type);
        return c;
    }

    private static ConversationMember m(long cid, long uid) {
        return ConversationMember.of(cid, uid, ConversationMember.Role.MEMBER);
    }

    @Test
    void bigGroupsLoadOnlyMyRowAndTheMemberCount() {
        Conversation direct = conv(1L, Conversation.Type.DIRECT);
        Conversation small = conv(2L, Conversation.Type.GROUP);
        Conversation bigA = conv(3L, Conversation.Type.GROUP);
        Conversation bigB = conv(4L, Conversation.Type.GROUP);
        when(convs.page(eq(ME), any(), anyBoolean(), any())).thenReturn(List.of(direct, small, bigA, bigB));
        when(members.activeCounts(any())).thenReturn(List.<Object[]>of(
                new Object[] {1L, 2L}, new Object[] {2L, 5L}, new Object[] {3L, 500L}, new Object[] {4L, 21L}));
        when(members.findByConversationIdInAndLeftAtIsNull(any())).thenReturn(List.of(
                m(1L, ME), m(1L, 9L), m(2L, ME), m(2L, 9L)));
        when(members.findMine(eq(ME), any())).thenReturn(List.of(m(3L, ME), m(4L, ME)));
        when(messages.unreadCounts(anyLong(), any(), any())).thenReturn(List.of());
        when(blocks.hiddenFrom(anyLong())).thenReturn(Set.of());
        User peer = new User();
        peer.setId(9L);
        peer.setDisplayName("U9");
        when(users.findAllById(any())).thenReturn(List.of(peer));

        List<ConversationView> items = service.list(ME, null, 20).items();

        assertEquals(4, items.size());
        // tum uyeler yalniz birebir + kucuk grup icin yuklenir
        @SuppressWarnings("unchecked")
        ArgumentCaptor<java.util.Collection<Long>> full = ArgumentCaptor.forClass(java.util.Collection.class);
        verify(members, times(1)).findByConversationIdInAndLeftAtIsNull(full.capture());
        assertEquals(Set.of(1L, 2L), Set.copyOf(full.getValue()));
        @SuppressWarnings("unchecked")
        ArgumentCaptor<java.util.Collection<Long>> mine = ArgumentCaptor.forClass(java.util.Collection.class);
        verify(members).findMine(eq(ME), mine.capture());
        assertEquals(Set.of(3L, 4L), Set.copyOf(mine.getValue()));
        // uye sayisi kayit sayisindan degil sayim sorgusundan gelir
        List<Integer> counts = new ArrayList<>();
        items.forEach(v -> counts.add(v.memberCount()));
        assertEquals(List.of(2, 5, 500, 21), counts);
    }
}
