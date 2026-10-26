package edu.bingol.backend.community.extras;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.messaging.room.RoomConversations;
import edu.bingol.backend.messaging.room.RoomConversations.RoomInfo;
import edu.bingol.backend.messaging.room.RoomKind;
import java.util.List;
import java.util.Optional;
import java.util.stream.LongStream;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

/** Uyelik kancalari: odaya/yanitlara dogru yansima ve exception sizdirmama sozlesmesi. */
class ClubExtrasHooksTest {

    private final RoomConversations rooms = mock(RoomConversations.class);
    private final CommunityRepository communities = mock(CommunityRepository.class);
    private final ClubMemberQueryRepository memberQuery = mock(ClubMemberQueryRepository.class);
    private final ClubJoinAnswerRepository answers = mock(ClubJoinAnswerRepository.class);
    private final org.springframework.context.ApplicationEventPublisher events =
            mock(org.springframework.context.ApplicationEventPublisher.class);
    private final ClubExtrasHooks hooks = new ClubExtrasHooks(rooms, communities, memberQuery, answers, events);

    private static Community club(Community.Status st) {
        Community c = new Community();
        c.setId(10L);
        c.setName("Kulup");
        c.setOwnerId(1L);
        c.setStatus(st);
        return c;
    }

    @Test
    void activationCreatesRoomAndAddsAllActiveMembers() {
        when(memberQuery.activeUserIdsAfter(eq(10L), eq(0L), any())).thenReturn(List.of(1L, 2L, 3L));

        hooks.onCommunityActivated(club(Community.Status.ACTIVE));

        verify(rooms).ensureRoom(RoomKind.COMMUNITY, 10L, "Kulup", 1L);
        verify(rooms).addMembers(RoomKind.COMMUNITY, 10L, List.of(1L, 2L, 3L));
    }

    @Test
    void activeMembersArePagedUntilShortPage() {
        List<Long> first = LongStream.rangeClosed(1, 500).boxed().toList();
        when(memberQuery.activeUserIdsAfter(eq(10L), eq(0L), any())).thenReturn(first);
        when(memberQuery.activeUserIdsAfter(eq(10L), eq(500L), any())).thenReturn(List.of(501L));

        assertEquals(501, hooks.activeUserIds(10L).size());
    }

    @Test
    void memberJoinedAddsToExistingRoom() {
        when(rooms.find(RoomKind.COMMUNITY, 10L)).thenReturn(Optional.of(new RoomInfo(5L, RoomKind.COMMUNITY, 10L, false)));

        hooks.onMemberActivated(10L, 7L);

        verify(rooms).addMember(RoomKind.COMMUNITY, 10L, 7L);
    }

    @Test
    void memberJoinedBuildsRoomOnlyForActiveClubs() {
        when(rooms.find(RoomKind.COMMUNITY, 10L)).thenReturn(Optional.empty());
        when(communities.findById(10L)).thenReturn(Optional.of(club(Community.Status.PENDING_REVIEW)));
        hooks.onMemberActivated(10L, 7L);
        verify(rooms, never()).ensureRoom(any(), anyLong(), anyString(), anyLong());

        when(communities.findById(10L)).thenReturn(Optional.of(club(Community.Status.ACTIVE)));
        hooks.onMemberActivated(10L, 7L);
        verify(rooms).ensureRoom(RoomKind.COMMUNITY, 10L, "Kulup", 1L);
    }

    @Test
    void memberGoneLeavesRoomAndDropsAnswers() {
        hooks.onMemberGone(10L, 7L);

        verify(rooms).removeMember(RoomKind.COMMUNITY, 10L, 7L);
        verify(answers).deleteMember(10L, 7L);
    }

    @Test
    void memberGonePublishesLeftEventAndListenerFailureIsSwallowed() {
        hooks.onMemberGone(10L, 7L);
        verify(events).publishEvent(new edu.bingol.backend.community.ClubMemberLeftEvent(10L, 7L));

        doThrow(new IllegalStateException("listener")).when(events).publishEvent(any(Object.class));
        assertDoesNotThrow(() -> hooks.onMemberGone(10L, 8L));
    }

    @Test
    void failuresNeverLeakToMembershipFlow() {
        doThrow(new ApiException(HttpStatus.CONFLICT, "ROOM_FULL", "x", "500")).when(rooms)
                .addMember(any(), anyLong(), anyLong());
        when(rooms.find(any(), anyLong())).thenReturn(Optional.of(new RoomInfo(5L, RoomKind.COMMUNITY, 10L, false)));
        doThrow(new IllegalStateException("db")).when(rooms).removeMember(any(), anyLong(), anyLong());
        doThrow(new IllegalStateException("db")).when(rooms).ensureRoom(any(), anyLong(), anyString(), anyLong());
        doThrow(new IllegalStateException("db")).when(rooms).renameRoom(any(), anyLong(), anyString());

        assertDoesNotThrow(() -> hooks.onMemberActivated(10L, 7L));
        assertDoesNotThrow(() -> hooks.onMemberGone(10L, 7L));
        assertDoesNotThrow(() -> hooks.onCommunityActivated(club(Community.Status.ACTIVE)));
        assertDoesNotThrow(() -> hooks.onRenamed(club(Community.Status.ACTIVE)));
        verify(answers).deleteMember(10L, 7L); // oda hatasi yanit temizligini engellemez
    }

    @Test
    void renameUpdatesRoomTitle() {
        hooks.onRenamed(club(Community.Status.ACTIVE));

        verify(rooms).renameRoom(RoomKind.COMMUNITY, 10L, "Kulup");
        verify(rooms, never()).addMembers(any(), anyLong(), anyCollection());
    }
}
