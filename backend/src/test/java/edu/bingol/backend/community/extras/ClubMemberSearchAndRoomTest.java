package edu.bingol.backend.community.extras;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityMember.Role;
import edu.bingol.backend.community.extras.ClubExtrasDtos.ChatRoomView;
import edu.bingol.backend.community.permissions.ClubAuditService;
import edu.bingol.backend.messaging.room.RoomConversations;
import edu.bingol.backend.messaging.room.RoomConversations.RoomInfo;
import edu.bingol.backend.messaging.room.RoomKind;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpStatus;

/** Uye arama/filtre ve kulup sohbet odasi uclarinin yetki + IDOR kurallari. */
class ClubMemberSearchAndRoomTest {

    private final ClubExtrasTestSupport t = new ClubExtrasTestSupport();
    private final ClubMemberQueryRepository query = mock(ClubMemberQueryRepository.class);
    private final ClubMemberSearchService search = new ClubMemberSearchService(t.communities, query, t.permissions);
    private final RoomConversations rooms = mock(RoomConversations.class);
    private final ClubExtrasHooks hooks = mock(ClubExtrasHooks.class);
    private final ClubAuditService audit = mock(ClubAuditService.class);
    private final ClubChatRoomService chat = new ClubChatRoomService(t.communities, rooms, hooks, t.permissions, audit);

    private final Actor mod = new Actor(2L, false);
    private final Actor plain = new Actor(3L, false);
    private final Actor outsider = new Actor(8L, false);

    // ---- uye arama ----

    @Test
    void defaultSearchListsActiveWithoutRoleFilterAndEscapesLike() {
        t.member(3L, Role.MEMBER);
        when(t.communities.blockedFor(plain)).thenReturn(Set.of(-1L));

        search.search(plain, 10L, "50%_a!", null, null, null, 20);

        ArgumentCaptor<String> pattern = ArgumentCaptor.forClass(String.class);
        verify(query).filtered(eq(10L), eq(CommunityMember.Status.ACTIVE), eq(true), eq(Role.MEMBER), pattern.capture(),
                eq(0L), eq(Set.of(-1L)), any());
        assertEquals("%50!%!_a!!%", pattern.getValue()); // LIKE ozel karakterleri kacirildi
    }

    @Test
    void roleFilterIsPassedAndCaseInsensitive() {
        t.member(3L, Role.MEMBER);
        when(t.communities.blockedFor(plain)).thenReturn(Set.of(-1L));

        search.search(plain, 10L, null, "moderator", "active", 5L, 10);

        verify(query).filtered(eq(10L), eq(CommunityMember.Status.ACTIVE), eq(false), eq(Role.MODERATOR), eq(""),
                eq(5L), any(), any());
    }

    @Test
    void invalidFilterValuesAre400() {
        t.member(3L, Role.MEMBER);

        assertEquals("VALIDATION_ERROR",
                ClubExtrasTestSupport.error(() -> search.search(plain, 10L, null, "KING", null, null, 20)).code());
        assertEquals("VALIDATION_ERROR",
                ClubExtrasTestSupport.error(() -> search.search(plain, 10L, null, null, "WHATEVER", null, 20)).code());
        verify(query, never()).filtered(anyLong(), any(), anyBoolean(), any(), any(), anyLong(), any(), any());
    }

    @Test
    void pendingAndBannedListsNeedMemberManagement() {
        t.member(3L, Role.MEMBER);
        t.member(2L, Role.MODERATOR);

        assertEquals(HttpStatus.FORBIDDEN,
                ClubExtrasTestSupport.error(() -> search.search(plain, 10L, null, null, "PENDING", null, 20)).status());
        assertEquals(HttpStatus.FORBIDDEN,
                ClubExtrasTestSupport.error(() -> search.search(plain, 10L, null, null, "BANNED", null, 20)).status());
        search.search(mod, 10L, null, null, "PENDING", null, 20);
        verify(query).filtered(eq(10L), eq(CommunityMember.Status.PENDING), eq(true), any(), eq(""), eq(0L),
                eq(Set.of(-1L)), any());
    }

    @Test
    void privateClubMemberListIsHiddenFromOutsiders() {
        t.club.setVisibility(Community.Visibility.PRIVATE);
        org.mockito.Mockito.doThrow(new ApiException(HttpStatus.FORBIDDEN, "NOT_MEMBER", "x"))
                .when(t.communities).requireReadable(eq(outsider), any());

        assertEquals("NOT_MEMBER",
                ClubExtrasTestSupport.error(() -> search.search(outsider, 10L, "a", null, null, null, 20)).code());
        verify(query, never()).filtered(anyLong(), any(), anyBoolean(), any(), any(), anyLong(), any(), any());
    }

    // ---- sohbet odasi ----

    private void roomExists(boolean closed) {
        when(rooms.find(RoomKind.COMMUNITY, 10L)).thenReturn(Optional.of(new RoomInfo(500L, RoomKind.COMMUNITY, 10L, closed)));
    }

    @Test
    void outsiderGets404NotForbiddenAndNothingIsCreated() {
        ApiException e = ClubExtrasTestSupport.error(() -> chat.get(outsider, 10L));

        assertEquals(HttpStatus.NOT_FOUND, e.status());
        assertEquals("CHAT_ROOM_NOT_FOUND", e.code());
        verify(hooks, never()).onCommunityActivated(any());
    }

    @Test
    void pendingApplicantAndBannedGet404() {
        t.member(8L, Role.MEMBER, CommunityMember.Status.PENDING);
        t.member(9L, Role.MEMBER, CommunityMember.Status.BANNED);

        assertEquals(HttpStatus.NOT_FOUND, ClubExtrasTestSupport.error(() -> chat.get(outsider, 10L)).status());
        assertEquals(HttpStatus.NOT_FOUND, ClubExtrasTestSupport.error(() -> chat.get(new Actor(9L, false), 10L)).status());
    }

    @Test
    void memberGetsRoomAndMissingRoomIsLazilyCreated() {
        t.member(3L, Role.MEMBER);
        when(rooms.find(RoomKind.COMMUNITY, 10L)).thenReturn(Optional.empty())
                .thenReturn(Optional.of(new RoomInfo(500L, RoomKind.COMMUNITY, 10L, false)));
        when(rooms.isMember(RoomKind.COMMUNITY, 10L, 3L)).thenReturn(true);
        when(rooms.memberCount(RoomKind.COMMUNITY, 10L)).thenReturn(12L);

        ChatRoomView v = chat.get(plain, 10L);

        verify(hooks).onCommunityActivated(t.club);
        assertEquals(500L, v.conversationId());
        assertTrue(v.joined());
        assertEquals(12L, v.memberCount());
    }

    @Test
    void closedRoomHidesConversationId() {
        t.member(3L, Role.MEMBER);
        roomExists(true);

        ChatRoomView v = chat.get(plain, 10L);

        assertNull(v.conversationId());
        assertTrue(v.closed());
        assertFalse(v.joined());
    }

    @Test
    void notYetPublishedClubHasNoRoom() {
        t.member(1L, Role.OWNER);
        t.club.setStatus(Community.Status.PENDING_REVIEW);

        assertEquals(HttpStatus.NOT_FOUND, ClubExtrasTestSupport.error(() -> chat.get(new Actor(1L, false), 10L)).status());
    }

    @Test
    void joinRoomFailsWhenClosedAndAddsWhenOpen() {
        t.member(3L, Role.MEMBER);
        roomExists(true);
        assertEquals("CHAT_ROOM_CLOSED", ClubExtrasTestSupport.error(() -> chat.join(plain, 10L)).code());

        roomExists(false);
        when(rooms.addMember(RoomKind.COMMUNITY, 10L, 3L)).thenReturn(true);
        chat.join(plain, 10L);
        verify(rooms).addMember(RoomKind.COMMUNITY, 10L, 3L);
    }

    @Test
    void onlyMemberManagersCloseOrOpenTheRoom() {
        t.member(3L, Role.MEMBER);
        t.member(2L, Role.MODERATOR);
        roomExists(false);

        assertEquals(HttpStatus.FORBIDDEN, ClubExtrasTestSupport.error(() -> chat.setClosed(plain, 10L, true)).status());
        assertEquals(HttpStatus.FORBIDDEN, ClubExtrasTestSupport.error(() -> chat.setClosed(outsider, 10L, true)).status());
        verify(rooms, never()).closeRoom(any(), anyLong());

        chat.setClosed(mod, 10L, true);
        verify(rooms).closeRoom(RoomKind.COMMUNITY, 10L);
        verify(audit).record(10L, 2L, null, ClubAuditService.CHAT_ROOM_CLOSED, null);
    }

    @Test
    void reopeningReAddsActiveMembersAndAudits() {
        t.member(2L, Role.MODERATOR);
        roomExists(true);
        when(hooks.activeUserIds(10L)).thenReturn(List.of(1L, 2L));

        chat.setClosed(mod, 10L, false);

        verify(rooms).openRoom(RoomKind.COMMUNITY, 10L, List.of(1L, 2L));
        verify(audit).record(10L, 2L, null, ClubAuditService.CHAT_ROOM_OPENED, null);
    }

    @Test
    void systemAdminCanCloseAnyClubRoom() {
        roomExists(false);

        chat.setClosed(new Actor(99L, true), 10L, true);

        verify(rooms).closeRoom(RoomKind.COMMUNITY, 10L);
    }
}
