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
    private final DepartmentChatService svc = new DepartmentChatService(rooms, depts, users, new edu.bingol.backend.catalog.CatalogService());

    private User user(long id, String dept, Role role) {
        User u = new User();
        u.setId(id);
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
    void canJoinAnotherDepartmentWithoutChangingProfile() {
        User u = user(5L, "Hukuk", Role.USER);
        DepartmentChatRoom r = room(7L, edu.bingol.backend.unitnews.UnitKeys.deptKey("Bilgisayar Mühendisliği"));
        when(rooms.find(RoomKind.DEPARTMENT, 7L))
                .thenReturn(Optional.of(new RoomInfo(300L, RoomKind.DEPARTMENT, 7L, false)));
        when(rooms.addMember(RoomKind.DEPARTMENT, 7L, 5L)).thenReturn(true);
        when(rooms.isMember(RoomKind.DEPARTMENT, 7L, 5L)).thenReturn(true);

        DepartmentChatView v = svc.join(5L, "Bilgisayar Mühendisliği");

        assertTrue(v.joined());
        assertEquals(r.getName(), v.departmentName());
        assertEquals("Hukuk", u.getDepartment());
    }

    @Test
    void rejectsDepartmentOutsideCatalog() {
        user(5L, "Hukuk", Role.USER);
        assertThrows(ApiException.class, () -> svc.join(5L, "uydurma bölüm"));
        verify(rooms, never()).addMember(any(), anyLong(), anyLong());
    }

    @Test
    void canLeaveAnotherDepartmentByConversationIdWithoutProfileDepartment() {
        user(5L, null, Role.USER);
        DepartmentChatRoom r = new DepartmentChatRoom();
        r.setId(7L);
        when(depts.findByConversationId(300L)).thenReturn(Optional.of(r));
        svc.leave(5L, 300L);
        verify(rooms).removeMember(RoomKind.DEPARTMENT, 7L, 5L);
    }

    @Test
    void browseIncludesDepartmentsWithNoRoomOrMessages() {
        user(5L, null, Role.USER);
        var result = svc.browse(5L);
        assertTrue(result.stream().anyMatch(r -> "Bilgisayar Mühendisliği".equals(r.departmentName())));
        assertTrue(result.stream().allMatch(r -> !r.joined() && r.conversationId() == null));
    }

    @Test
    void signupJoinsOwnDepartment() {
        user(5L, "Hukuk", Role.USER);
        room(7L, edu.bingol.backend.unitnews.UnitKeys.deptKey("Hukuk"));
        when(rooms.find(RoomKind.DEPARTMENT, 7L))
                .thenReturn(Optional.of(new RoomInfo(300L, RoomKind.DEPARTMENT, 7L, false)));
        svc.joinOnSignup(5L);
        verify(rooms).addMemberIfSpace(RoomKind.DEPARTMENT, 7L, 5L);
    }

    @Test
    void closedDepartmentDoesNotPreventSignup() {
        user(5L, "Hukuk", Role.USER);
        room(7L, edu.bingol.backend.unitnews.UnitKeys.deptKey("Hukuk"));
        when(rooms.find(RoomKind.DEPARTMENT, 7L))
                .thenReturn(Optional.of(new RoomInfo(300L, RoomKind.DEPARTMENT, 7L, true)));
        svc.joinOnSignup(5L);
        verify(rooms, never()).addMemberIfSpace(any(), anyLong(), anyLong());
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
