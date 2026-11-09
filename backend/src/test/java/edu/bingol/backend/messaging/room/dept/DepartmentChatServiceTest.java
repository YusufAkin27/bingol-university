package edu.bingol.backend.messaging.room.dept;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.admin.rbac.AdminProfile;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.messaging.room.RoomConversations;
import edu.bingol.backend.messaging.room.RoomConversations.RoomInfo;
import edu.bingol.backend.messaging.room.RoomKind;
import edu.bingol.backend.messaging.room.dept.DepartmentChatService.DepartmentChatView;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

class DepartmentChatServiceTest {

    private final RoomConversations rooms = mock(RoomConversations.class);
    private final DepartmentChatRoomRepository depts = mock(DepartmentChatRoomRepository.class);
    private final UserRepository users = mock(UserRepository.class);
    private final edu.bingol.backend.messaging.ConversationService convs =
            mock(edu.bingol.backend.messaging.ConversationService.class);
    private final DepartmentChatService svc = new DepartmentChatService(rooms, depts, users,
            new edu.bingol.backend.catalog.CatalogService(), convs,
            mock(DepartmentChatOptoutRepository.class));

    private User user(long id, String dept, Role role) {
        User u = new User();
        u.setId(id);
        u.setEmailVerified(true);
        u.setDepartment(dept);
        u.setRole(role);
        when(users.findById(id)).thenReturn(Optional.of(u));
        return u;
    }

    private DepartmentChatRoom room(long id, String key) {
        DepartmentChatRoom r = new DepartmentChatRoom();
        r.setId(id);
        r.setDeptKey(key);
        r.setName("Bilgisayar Mühendisliği");
        when(depts.findByDeptKey(key)).thenReturn(Optional.of(r));
        return r;
    }

    @Test
    void getWithoutDepartmentIsUnavailable() {
        user(1L, null, Role.USER);
        DepartmentChatView v = svc.get(1L);
        assertFalse(v.available());
        assertNull(v.conversationId());
    }

    @Test
    void getBeforeRoomExistsIsAvailableButNotJoined() {
        user(1L, "Bilgisayar Mühendisliği", Role.USER);
        when(depts.findByDeptKey(any())).thenReturn(Optional.empty());
        DepartmentChatView v = svc.get(1L);
        assertTrue(v.available());
        assertFalse(v.joined());
        assertEquals(0, v.memberCount());
    }

    @Test
    void joinRequiresDepartment() {
        user(1L, "  ", Role.USER);
        ApiException e = assertThrows(ApiException.class, () -> svc.join(1L));
        assertEquals("DEPARTMENT_REQUIRED", e.code());
        assertEquals(HttpStatus.CONFLICT, e.status());
    }

    @Test
    void joinCreatesRoomWithAdminOwnerAndAddsMember() {
        user(5L, "Bilgisayar Mühendisliği", Role.USER);
        User admin = new User();
        admin.setId(99L);
        admin.setRole(Role.ADMIN);
        when(users.findAllAdmins()).thenReturn(List.of(admin));
        DepartmentChatRoom r = new DepartmentChatRoom();
        r.setId(7L);
        r.setName("Bilgisayar Mühendisliği");
        when(depts.findByDeptKey(any())).thenReturn(Optional.of(r));
        RoomInfo info = new RoomInfo(300L, RoomKind.DEPARTMENT, 7L, false);
        when(rooms.find(RoomKind.DEPARTMENT, 7L)).thenReturn(Optional.empty(), Optional.of(info));
        when(rooms.addMember(RoomKind.DEPARTMENT, 7L, 5L)).thenReturn(true);
        when(rooms.isMember(RoomKind.DEPARTMENT, 7L, 5L)).thenReturn(true);
        when(rooms.memberCount(RoomKind.DEPARTMENT, 7L)).thenReturn(2L);

        DepartmentChatView v = svc.join(5L);

        verify(rooms).ensureRoom(eq(RoomKind.DEPARTMENT), eq(7L), any(), eq(99L));
        assertTrue(v.joined());
        assertEquals(300L, v.conversationId());
        assertEquals(2L, v.memberCount());
    }

    @Test
    void joinClosedRoomIsRejected() {
        user(5L, "Bilgisayar Mühendisliği", Role.USER);
        DepartmentChatRoom r = new DepartmentChatRoom();
        r.setId(7L);
        r.setName("x");
        when(depts.findByDeptKey(any())).thenReturn(Optional.of(r));
        when(rooms.find(RoomKind.DEPARTMENT, 7L))
                .thenReturn(Optional.of(new RoomInfo(300L, RoomKind.DEPARTMENT, 7L, true)));
        ApiException e = assertThrows(ApiException.class, () -> svc.join(5L));
        assertEquals("CHAT_ROOM_CLOSED", e.code());
        verify(rooms, never()).addMember(any(), anyLong(), anyLong());
    }

    @Test
    void leaveRemovesMembership() {
        user(5L, "Bilgisayar Mühendisliği", Role.USER);
        DepartmentChatRoom r = new DepartmentChatRoom();
        r.setId(7L);
        when(depts.findByDeptKey(any())).thenReturn(Optional.of(r));
        svc.leave(5L);
        verify(rooms).removeMember(RoomKind.DEPARTMENT, 7L, 5L);
    }

    @Test
    void sameDepartmentSpellingVariantsShareOneKey() {
        user(1L, "Bilgisayar Mühendisliği Bölümü", Role.USER);
        user(2L, "bilgisayar muhendisligi (İkinci Öğretim)", Role.USER);
        when(depts.findByDeptKey(any())).thenReturn(Optional.empty());
        svc.get(1L);
        svc.get(2L);
        org.mockito.ArgumentCaptor<String> k = org.mockito.ArgumentCaptor.forClass(String.class);
        verify(depts, org.mockito.Mockito.times(2)).findByDeptKey(k.capture());
        assertEquals(k.getAllValues().get(0), k.getAllValues().get(1));
    }

    // ---- v2: herhangi bir bolum kanali ----

    private DepartmentChatStats stat(String key, long roomId, Long conv, boolean closed, long count, boolean joined) {
        DepartmentChatStats s = mock(DepartmentChatStats.class);
        when(s.getDeptKey()).thenReturn(key);
        when(s.getRoomId()).thenReturn(roomId);
        when(s.getConversationId()).thenReturn(conv);
        when(s.getClosed()).thenReturn(closed);
        when(s.getMemberCount()).thenReturn(count);
        when(s.getJoined()).thenReturn(joined);
        return s;
    }

    @Test
    void joinChannelWorksForAnotherDepartmentAndIsIdempotent() {
        user(5L, "Matematik", Role.USER);
        DepartmentChatRoom r = new DepartmentChatRoom();
        r.setId(8L);
        r.setName("Bilgisayar Mühendisliği");
        when(depts.findByDeptKey(any())).thenReturn(Optional.of(r));
        RoomInfo info = new RoomInfo(310L, RoomKind.DEPARTMENT, 8L, false);
        when(rooms.find(RoomKind.DEPARTMENT, 8L)).thenReturn(Optional.of(info));
        when(rooms.addMember(RoomKind.DEPARTMENT, 8L, 5L)).thenReturn(true);
        when(rooms.memberCount(RoomKind.DEPARTMENT, 8L)).thenReturn(4L);

        var a = svc.joinChannel(5L, "bilgisayar-muhendisligi");
        var b = svc.joinChannel(5L, "bilgisayar-muhendisligi");

        assertTrue(a.joined());
        assertFalse(a.own());
        assertEquals(310L, a.conversationId());
        assertEquals(4L, b.memberCount());
        verify(rooms, org.mockito.Mockito.times(2)).addMember(RoomKind.DEPARTMENT, 8L, 5L);
    }

    @Test
    void joinChannelMarksOwnDepartment() {
        user(5L, "Bilgisayar Mühendisliği", Role.USER);
        DepartmentChatRoom r = new DepartmentChatRoom();
        r.setId(8L);
        r.setName("x");
        when(depts.findByDeptKey(any())).thenReturn(Optional.of(r));
        when(rooms.find(RoomKind.DEPARTMENT, 8L))
                .thenReturn(Optional.of(new RoomInfo(310L, RoomKind.DEPARTMENT, 8L, false)));
        when(rooms.addMember(RoomKind.DEPARTMENT, 8L, 5L)).thenReturn(true);
        assertTrue(svc.joinChannel(5L, "bilgisayar-muhendisligi").own());
    }

    @Test
    void joinChannelUnknownDepartmentIs404() {
        user(5L, null, Role.USER);
        ApiException e = assertThrows(ApiException.class, () -> svc.joinChannel(5L, "yok-boyle-bolum"));
        assertEquals("DEPARTMENT_NOT_FOUND", e.code());
        assertEquals(HttpStatus.NOT_FOUND, e.status());
    }

    @Test
    void joinChannelSuspendedUserIsRejected() {
        User u = user(5L, null, Role.USER);
        u.setStatus(edu.bingol.backend.user.UserStatus.SUSPENDED);
        ApiException e = assertThrows(ApiException.class, () -> svc.joinChannel(5L, "matematik"));
        assertEquals("DEPARTMENT_JOIN_FORBIDDEN", e.code());
        verify(rooms, never()).addMember(any(), anyLong(), anyLong());
    }

    @Test
    void joinChannelRefusedByRoomIsForbidden() {
        user(5L, null, Role.USER);
        DepartmentChatRoom r = new DepartmentChatRoom();
        r.setId(9L);
        r.setName("Matematik");
        when(depts.findByDeptKey(any())).thenReturn(Optional.of(r));
        when(rooms.find(RoomKind.DEPARTMENT, 9L))
                .thenReturn(Optional.of(new RoomInfo(311L, RoomKind.DEPARTMENT, 9L, false)));
        when(rooms.addMember(RoomKind.DEPARTMENT, 9L, 5L)).thenReturn(false);
        ApiException e = assertThrows(ApiException.class, () -> svc.joinChannel(5L, "matematik"));
        assertEquals("DEPARTMENT_JOIN_FORBIDDEN", e.code());
    }

    @Test
    void leaveChannelRemovesMembershipAndIsNoopWithoutRoom() {
        DepartmentChatRoom r = new DepartmentChatRoom();
        r.setId(8L);
        when(depts.findByDeptKey("matematik")).thenReturn(Optional.of(r));
        svc.leaveChannel(5L, "matematik");
        verify(rooms).removeMember(RoomKind.DEPARTMENT, 8L, 5L);
        when(depts.findByDeptKey(any())).thenReturn(Optional.empty());
        svc.leaveChannel(5L, "fizik"); // oda yok: hata yok
        assertThrows(ApiException.class, () -> svc.leaveChannel(5L, "yok-boyle"));
    }

    @Test
    void leaveByConversationOnlyAffectsDepartmentRooms() {
        when(rooms.findByConversation(300L))
                .thenReturn(Optional.of(new RoomInfo(300L, RoomKind.DEPARTMENT, 8L, false)));
        when(rooms.findByConversation(301L))
                .thenReturn(Optional.of(new RoomInfo(301L, RoomKind.COMMUNITY, 2L, false)));
        svc.leaveByConversation(5L, 300L);
        svc.leaveByConversation(5L, 301L);
        verify(rooms).removeMember(RoomKind.DEPARTMENT, 8L, 5L);
        verify(rooms, never()).removeMember(eq(RoomKind.COMMUNITY), anyLong(), anyLong());
    }

    @Test
    void listChannelsShowsMembershipOwnFlagAndSearch() {
        user(5L, "Bilgisayar Mühendisliği", Role.USER);
        String key = edu.bingol.backend.unitnews.UnitKeys.deptKey("Matematik");
        when(depts.statsFor(5L)).thenReturn(List.of(stat(key, 9L, 311L, false, 12, true)));

        var all = svc.listChannels(5L, "", 0, 200);
        assertEquals("bilgisayar-muhendisligi", all.ownKey());
        var mat = all.items().stream().filter(c -> c.key().equals("matematik")).findFirst().orElseThrow();
        assertTrue(mat.joined());
        assertEquals(12, mat.memberCount());
        assertEquals(311L, mat.conversationId());
        var own = all.items().stream().filter(c -> c.key().equals("bilgisayar-muhendisligi")).findFirst().orElseThrow();
        assertTrue(own.own());
        assertFalse(own.joined());
        assertNull(own.conversationId());

        var found = svc.listChannels(5L, "BİLGİSAYAR", 0, 10);
        assertTrue(found.total() >= 1);
        assertTrue(found.items().stream().allMatch(c -> c.name().toLowerCase().contains("bilgisayar")
                || c.nameEn().toLowerCase().contains("bilgisayar") || c.faculty().toLowerCase().contains("bilgisayar")));
        var paged = svc.listChannels(5L, "", 1, 5);
        assertEquals(5, paged.items().size());
        assertEquals(5, paged.size());
        assertEquals(200, svc.listChannels(5L, "", 0, 9999).items().size());
    }

    @Test
    void listChannelsClosedRoomShowsNoMembership() {
        user(5L, null, Role.USER);
        String key = edu.bingol.backend.unitnews.UnitKeys.deptKey("Matematik");
        when(depts.statsFor(5L)).thenReturn(List.of(stat(key, 9L, 311L, true, 12, true)));
        var mat = svc.listChannels(5L, "matematik", 0, 5).items().stream()
                .filter(c -> c.key().equals("matematik")).findFirst().orElseThrow();
        assertTrue(mat.closed());
        assertFalse(mat.joined());
        assertEquals(0, mat.memberCount());
    }

    @Test
    void myChannelsReturnsOnlyJoinedOpenRooms() {
        user(5L, "Matematik", Role.USER);
        String mat = edu.bingol.backend.unitnews.UnitKeys.deptKey("Matematik");
        String fiz = edu.bingol.backend.unitnews.UnitKeys.deptKey("Fizik");
        String kim = edu.bingol.backend.unitnews.UnitKeys.deptKey("Kimya");
        when(depts.statsFor(5L)).thenReturn(List.of(stat(mat, 9L, 311L, false, 3, true),
                stat(fiz, 10L, 312L, true, 3, true), stat(kim, 11L, 313L, false, 3, false)));
        var cv = mock(edu.bingol.backend.messaging.dto.MessagingDtos.ConversationView.class);
        when(convs.view(5L, 311L)).thenReturn(cv);

        var res = svc.myChannels(5L);
        var mine = res.items();

        assertEquals(1, mine.size());
        assertEquals("matematik", mine.get(0).key());
        assertTrue(mine.get(0).own());
        assertEquals(cv, mine.get(0).conversation());
        assertEquals("matematik", res.own().key());
        assertTrue(res.own().joined());
    }

    @Test
    void onlyFullOrModeratorAdminsModerate() {
        UserRepository repo = mock(UserRepository.class);
        DepartmentRoomModerators m = new DepartmentRoomModerators(repo);
        User admin = new User();
        admin.setId(1L);
        admin.setRole(Role.ADMIN);
        User viewer = new User();
        viewer.setId(2L);
        viewer.setRole(Role.ADMIN);
        viewer.setAdminProfile(AdminProfile.VIEWER);
        User plain = new User();
        plain.setId(3L);
        plain.setRole(Role.USER);
        when(repo.findById(1L)).thenReturn(Optional.of(admin));
        when(repo.findById(2L)).thenReturn(Optional.of(viewer));
        when(repo.findById(3L)).thenReturn(Optional.of(plain));
        assertTrue(m.canModerate(7L, 1L));
        assertFalse(m.canModerate(7L, 2L));
        assertFalse(m.canModerate(7L, 3L));
        assertEquals(RoomKind.DEPARTMENT, m.kind());
    }
}
