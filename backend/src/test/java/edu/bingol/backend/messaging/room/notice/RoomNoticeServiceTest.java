package edu.bingol.backend.messaging.room.notice;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.messaging.ConversationMember;
import edu.bingol.backend.messaging.ConversationMemberRepository;
import edu.bingol.backend.messaging.room.ChatRoomLink;
import edu.bingol.backend.messaging.room.ChatRoomLinkRepository;
import edu.bingol.backend.messaging.room.RoomModeration;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.moderation.profanity.ContentGuard;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.user.UserRepository;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.Pageable;

class RoomNoticeServiceTest {

    private final RoomNoticeRepository notices = mock(RoomNoticeRepository.class);
    private final RoomModeration moderation = mock(RoomModeration.class);
    private final ChatRoomLinkRepository links = mock(ChatRoomLinkRepository.class);
    private final ConversationMemberRepository members = mock(ConversationMemberRepository.class);
    private final UserRepository users = mock(UserRepository.class);
    private final NotificationService notifications = mock(NotificationService.class);
    private final BlockService blocks = mock(BlockService.class);
    private final RoomNoticeService svc = new RoomNoticeService(notices, moderation, links, members, users,
            notifications, null, blocks);

    private RoomNotice notice(long id, long cid, long author) {
        RoomNotice n = new RoomNotice();
        n.setId(id);
        n.setConversationId(cid);
        n.setAuthorId(author);
        n.setTitle("t");
        n.setBody("b");
        return n;
    }

    private void room(long cid) {
        when(links.findByConversationId(cid)).thenReturn(Optional.of(new ChatRoomLink()));
    }

    @Test
    void nonModeratorCannotPublishEditOrDelete() {
        room(5L);
        when(moderation.canModerate(5L, 9L)).thenReturn(false);
        ApiException e1 = assertThrows(ApiException.class, () -> svc.create(5L, 9L, "Baslik", "Metin", false));
        assertEquals("NOTICE_FORBIDDEN", e1.code());
        assertThrows(ApiException.class, () -> svc.update(5L, 9L, 1L, "x", null, null));
        assertThrows(ApiException.class, () -> svc.delete(5L, 9L, 1L));
        verify(notices, never()).save(any());
    }

    @Test
    void nonMemberGetsNotFoundOnRead() {
        room(5L);
        when(moderation.canModerate(5L, 9L)).thenReturn(false);
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(5L, 9L)).thenReturn(Optional.empty());
        ApiException e = assertThrows(ApiException.class, () -> svc.pinned(5L, 9L));
        assertEquals(404, e.status().value());
    }

    @Test
    void seenCountIsUniquePerUserAndAuthorIsIgnored() {
        room(5L);
        when(moderation.canModerate(5L, 7L)).thenReturn(false);
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(5L, 7L)).thenReturn(Optional.of(new ConversationMember()));
        when(notices.findById(1L)).thenReturn(Optional.of(notice(1L, 5L, 2L)));
        when(notices.insertSeen(eq(1L), eq(7L), any())).thenReturn(1).thenReturn(0);

        svc.markSeen(5L, 7L, 1L);
        svc.markSeen(5L, 7L, 1L);
        verify(notices, times(1)).bumpSeen(1L);

        // yazar kendi duyurusunu saymaz
        when(moderation.canModerate(5L, 2L)).thenReturn(true);
        svc.markSeen(5L, 2L, 1L);
        verify(notices, never()).insertSeen(eq(1L), eq(2L), any());
    }

    @Test
    void seenCountHiddenFromNonManagers() {
        room(5L);
        when(moderation.canModerate(5L, 7L)).thenReturn(false);
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(5L, 7L)).thenReturn(Optional.of(new ConversationMember()));
        RoomNotice n = notice(1L, 5L, 2L);
        n.setSeenCount(42);
        when(notices.pinned(eq(5L), any(Pageable.class))).thenReturn(List.of(n));
        when(notices.seenAmong(eq(7L), anyCollection())).thenReturn(List.of());
        assertNull(svc.pinned(5L, 7L).items().get(0).seenCount());
    }

    @Test
    void fanoutIsChunkedAndSkipsAuthor() {
        when(blocks.hiddenFrom(1L)).thenReturn(Set.of());
        when(notices.conversationTitle(5L)).thenReturn(Optional.of("Oda"));
        List<Long> first = new ArrayList<>();
        for (long i = 1; i <= RoomNoticeService.CHUNK; i++) {
            first.add(i);
        }
        when(notices.memberIdsAfter(eq(5L), eq(0L), any(Pageable.class))).thenReturn(first);
        when(notices.memberIdsAfter(eq(5L), eq((long) RoomNoticeService.CHUNK), any(Pageable.class)))
                .thenReturn(List.of(1000L));
        svc.notifyMembers(5L, 1L, 9L, "Baslik");
        verify(notifications, times(2)).sendTemplatedBulk(anyCollection(), eq(RoomNoticeService.TEMPLATE), any(),
                any(), any(String[].class));
        verify(notifications, never()).sendTemplatedBulk(
                org.mockito.ArgumentMatchers.argThat(c -> c.contains(1L)), any(), any(), any(), any(String[].class));
    }

    @Test
    void pinningLocksTheConversationRowBeforeCountingSoConcurrentPinsCannotExceedTheLimit() {
        var convs = mock(edu.bingol.backend.messaging.ConversationRepository.class);
        svc.setConvs(convs);
        room(5L);
        when(moderation.canModerate(5L, 7L)).thenReturn(true);
        when(notices.countPinned(5L)).thenReturn((long) RoomNoticeService.MAX_PINNED);

        ApiException e = assertThrows(ApiException.class, () -> svc.create(5L, 7L, "t", "b", true));

        assertEquals("NOTICE_PIN_LIMIT", e.code());
        var order = org.mockito.Mockito.inOrder(convs, notices);
        order.verify(convs).lockById(5L);
        order.verify(notices).countPinned(5L);
        verify(notices, never()).save(any());
    }
}
